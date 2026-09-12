import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_config.dart';
import '../../features/splash/welcome_screen.dart';
import '../../features/home/home_shell.dart';

/// Escucha el estado de sesión de Supabase y cambia automáticamente
/// entre la pantalla de bienvenida y el inicio de la app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? supabase.auth.currentSession;

        if (session != null) {
          return const HomeShell();
        }

        return const WelcomeScreen();
      },
    );
  }
}