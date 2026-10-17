import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../../features/auth/password_recovery_screen.dart';
import '../../features/splash/welcome_screen.dart';
import '../../features/home/home_shell.dart';

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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _session = supabase.auth.currentSession;
    _authSubscription = supabase.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;
      setState(() {
        _session = authState.session;
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryPending = true;
        } else if (authState.event == AuthChangeEvent.signedOut) {
          _passwordRecoveryPending = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_passwordRecoveryPending && _session != null) {
      return PasswordRecoveryScreen(
        onCompleted: () => setState(() => _passwordRecoveryPending = false),
      );
    }

    if (_session != null) return const HomeShell();
    return const WelcomeScreen();
  }
}