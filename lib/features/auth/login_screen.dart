import 'package:flutter/material.dart';
import 'auth_screen.dart';

/// Wrapper delgado para no tener que tocar las rutas de main.dart:
/// /login sigue existiendo, pero ahora abre la pantalla unificada
/// AuthScreen en la pestaña "Iniciar sesión".
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialTab: AuthTab.login);
  }
}
