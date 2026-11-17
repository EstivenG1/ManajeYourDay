import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../services/notification_service.dart';
import '../services/profile_bootstrap_service.dart';
import '../../features/auth/password_recovery_screen.dart';
import '../../features/auth/mfa_verification_screen.dart';
import '../../features/splash/welcome_screen.dart';
import '../../features/splash/new_user_welcome_screen.dart';
import '../../features/home/home_shell.dart';

final GlobalKey<NavigatorState> mydNavigatorKey = GlobalKey<NavigatorState>();

/// Escucha el estado de sesión de Supabase y cambia automáticamente
/// entre la pantalla de bienvenida y el inicio de la app.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session;
  bool _passwordRecoveryPending = false;
  bool _showNewUserWelcome = false;
  bool _profileReady = false;
  String? _profileError;
  String? _profileLoadingUserId;
  bool _recoveryRouteOpen = false;
  String? _mfaFactorId;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _session = supabase.auth.currentSession;
    _profileReady = _session == null;
    _showNewUserWelcome =
        _session?.user.userMetadata?['myd_welcome_pending'] == true;
    _passwordRecoveryPending =
        _session != null && SupabaseConfig.consumePasswordRecoveryRedirect();
    final authRedirectError = SupabaseConfig.consumeAuthRedirectError();
    if (authRedirectError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(
              'No se pudo confirmar el correo ($authRedirectError). '
              'Solicita un enlace nuevo e inténtalo otra vez.',
            ),
          ),
        );
      });
    }
    final sessionAtStartup = _session;
    if (sessionAtStartup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _session?.user.id == sessionAtStartup.user.id) {
          _prepararPerfil(sessionAtStartup);
        }
      });
    }
    _authSubscription = supabase.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;
      final previousUserId = _session?.user.id;
      final session = authState.session;
      final needsProfile =
          session != null &&
          (session.user.id != previousUserId ||
              authState.event == AuthChangeEvent.signedIn ||
              authState.event == AuthChangeEvent.userUpdated);
      setState(() {
        _session = session;
        if (session == null) {
          _profileReady = true;
          _profileError = null;
          _mfaFactorId = null;
        } else if (needsProfile) {
          _profileReady = false;
          _profileError = null;
        }
        _showNewUserWelcome =
            session?.user.userMetadata?['myd_welcome_pending'] == true;
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryPending = true;
          _mfaFactorId = null;
          SupabaseConfig.consumePasswordRecoveryRedirect();
        } else if (authState.event == AuthChangeEvent.signedOut ||
            authState.event == AuthChangeEvent.signedIn) {
          _passwordRecoveryPending = false;
          SupabaseConfig.consumePasswordRecoveryRedirect();
        } else if (_session != null &&
            SupabaseConfig.consumePasswordRecoveryRedirect()) {
          _passwordRecoveryPending = true;
        }
      });
      if (needsProfile) unawaited(_prepararPerfil(session));
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        _openRecoveryRoute();
      }
      if (authState.event == AuthChangeEvent.signedOut ||
          authState.event == AuthChangeEvent.signedIn) {
        unawaited(
          _sincronizarNotificacionesDeLaCuenta(
            restaurar: authState.event == AuthChangeEvent.signedIn,
          ),
        );
      }
    });
  }

  Future<void> _prepararPerfil(Session session) async {
    final userId = session.user.id;
    if (_profileLoadingUserId == userId) return;
    _profileLoadingUserId = userId;
    try {
      final verifiedUser = (await supabase.auth.getUser()).user;
      if (verifiedUser == null || verifiedUser.id != userId) {
        await _descartarSesionInvalida();
        return;
      }
      await ProfileBootstrapService.ensureExists(verifiedUser);
      final factors = await supabase.auth.mfa.listFactors();
      final verifiedFactor = factors.totp
          .where((factor) => factor.status == FactorStatus.verified)
          .firstOrNull;
      final requiresMfa =
          !_passwordRecoveryPending &&
          verifiedFactor != null &&
          supabase.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel !=
              AuthenticatorAssuranceLevels.aal2;
      if (!mounted || _session?.user.id != userId) return;
      setState(() {
        _profileReady = true;
        _profileError = null;
        _mfaFactorId = requiresMfa ? verifiedFactor.id : null;
      });
    } on AuthException catch (error) {
      if (_esSesionInvalida(error)) {
        await _descartarSesionInvalida();
        return;
      }
      if (!mounted || _session?.user.id != userId) return;
      setState(() => _profileError = 'No se pudo preparar tu perfil: $error');
    } catch (error) {
      if (!mounted || _session?.user.id != userId) return;
      setState(() => _profileError = 'No se pudo preparar tu perfil: $error');
    } finally {
      if (_profileLoadingUserId == userId) _profileLoadingUserId = null;
    }
  }

  bool _esSesionInvalida(AuthException error) {
    return error.statusCode == '401' ||
        error.statusCode == '403' ||
        error.statusCode == '404' ||
        error.code == 'user_not_found' ||
        error.code == 'session_not_found';
  }

  Future<void> _descartarSesionInvalida() async {
    try {
      await supabase.auth.signOut(scope: SignOutScope.local);
    } catch (error) {
      debugPrint('Unable to clear invalid local session: $error');
    }
    if (!mounted) return;
    setState(() {
      _session = null;
      _profileReady = true;
      _profileError = null;
      _mfaFactorId = null;
      _showNewUserWelcome = false;
      _passwordRecoveryPending = false;
    });
  }

  Future<void> _reintentarPrepararPerfil() async {
    final session = _session;
    if (session == null) return;
    setState(() => _profileError = null);
    await _prepararPerfil(session);
  }

  Future<void> _sincronizarNotificacionesDeLaCuenta({
    required bool restaurar,
  }) async {
    try {
      await NotificationService.cancelarTodas();
      if (restaurar) await NotificationService.restaurarRecordatorios();
    } catch (_) {
      // Account navigation must not depend on local notification permissions.
    }
  }

  void _openRecoveryRoute() {
    final navigator = mydNavigatorKey.currentState;
    if (_recoveryRouteOpen || navigator == null) return;
    _recoveryRouteOpen = true;
    navigator
        .push<void>(
          MaterialPageRoute<void>(
            builder: (_) =>
                PasswordRecoveryScreen(onCompleted: _completePasswordRecovery),
          ),
        )
        .whenComplete(() {
          _recoveryRouteOpen = false;
        });
  }

  void _completePasswordRecovery() {
    unawaited(_finishPasswordRecovery());
  }

  Future<void> _finishPasswordRecovery() async {
    if (!mounted) return;
    setState(() => _passwordRecoveryPending = false);
    try {
      await supabase.auth.signOut();
      final navigator = mydNavigatorKey.currentState;
      if (_recoveryRouteOpen && navigator?.canPop() == true) {
        navigator!.pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _passwordRecoveryPending = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar la sesión de recuperación: $error'),
        ),
      );
    }
  }

  void _completeMfa() {
    if (!mounted) return;
    setState(() => _mfaFactorId = null);
  }

  Future<void> _completeNewUserWelcome() async {
    try {
      await supabase.auth.updateUser(
        UserAttributes(data: {'myd_welcome_pending': false}),
      );
      if (mounted) setState(() => _showNewUserWelcome = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar el inicio. Revisa tu conexión e inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session != null && _profileError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_profileError!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: _reintentarPrepararPerfil,
                      child: const Text('Reintentar'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _descartarSesionInvalida,
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_session != null && !_profileReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_passwordRecoveryPending && _session != null) {
      return PasswordRecoveryScreen(onCompleted: _completePasswordRecovery);
    }
    if (_session != null && _mfaFactorId != null) {
      return MfaVerificationScreen(
        factorId: _mfaFactorId!,
        onVerified: _completeMfa,
      );
    }

    if (_session != null && _showNewUserWelcome) {
      return NewUserWelcomeScreen(onContinue: _completeNewUserWelcome);
    }
    if (_session != null) return const HomeShell();
    return const WelcomeScreen();
  }
}
