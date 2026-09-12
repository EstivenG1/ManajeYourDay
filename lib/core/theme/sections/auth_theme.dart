import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radii.dart';

/// Diseño propio de las pantallas de Bienvenida / Login / Registro.
/// Para cambiar cómo se ve esta sección, edita SOLO este archivo.
class AuthTheme extends ThemeExtension<AuthTheme> {
  final List<Color> gradienteFondoSplash;
  final Gradient gradienteLogo;
  final double radioCampos;
  final double radioBotones;

  const AuthTheme({
    required this.gradienteFondoSplash,
    required this.gradienteLogo,
    required this.radioCampos,
    required this.radioBotones,
  });

  static const estandar = AuthTheme(
    gradienteFondoSplash: AppColors.bgSplashGradient,
    gradienteLogo: AppColors.goldGradient,
    radioCampos: AppRadii.xl2,
    radioBotones: AppRadii.xl2,
  );

  @override
  AuthTheme copyWith({
    List<Color>? gradienteFondoSplash,
    Gradient? gradienteLogo,
    double? radioCampos,
    double? radioBotones,
  }) {
    return AuthTheme(
      gradienteFondoSplash: gradienteFondoSplash ?? this.gradienteFondoSplash,
      gradienteLogo: gradienteLogo ?? this.gradienteLogo,
      radioCampos: radioCampos ?? this.radioCampos,
      radioBotones: radioBotones ?? this.radioBotones,
    );
  }

  @override
  AuthTheme lerp(ThemeExtension<AuthTheme>? other, double t) => this;
}
