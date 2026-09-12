import 'package:flutter/material.dart';
import 'auth_screen.dart';

/// Wrapper delgado: /register abre la misma AuthScreen, pero en la
/// pestaña "Registrarse".
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthScreen(initialTab: AuthTab.register);
  }
}
