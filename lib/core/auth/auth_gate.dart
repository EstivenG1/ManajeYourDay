import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../../features/auth/password_recovery_screen.dart';
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
  bool _recoveryRouteOpen = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _session = supabase.auth.currentSession;
    _showNewUserWelcome =
        _session?.user.userMetadata?['myd_welcome_pending'] == true;
    _passwordRecoveryPending =
        _session != null && SupabaseConfig.consumePasswordRecoveryRedirect();
    _authSubscription = supabase.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;
      setState(() {
        _session = authState.session;
        _showNewUserWelcome =
            authState.session?.user.userMetadata?['myd_welcome_pending'] ==
            true;
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryPending = true;
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
      if (authState.event == AuthChangeEvent.passwordRecovery) {
        _openRecoveryRoute();
      }
    });
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
    if (!mounted) return;
    setState(() => _passwordRecoveryPending = false);
    final navigator = mydNavigatorKey.currentState;
    if (_recoveryRouteOpen && navigator?.canPop() == true) {
      navigator!.pop();
    }
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
    if (_passwordRecoveryPending && _session != null) {
      return PasswordRecoveryScreen(onCompleted: _completePasswordRecovery);
    }

    if (_session != null && _showNewUserWelcome) {
      return NewUserWelcomeScreen(onContinue: _completeNewUserWelcome);
    }
    if (_session != null) return const HomeShell();
    return const WelcomeScreen();
  }
}
