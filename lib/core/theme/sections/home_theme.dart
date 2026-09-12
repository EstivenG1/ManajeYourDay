import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radii.dart';

/// Diseño propio de la sección Inicio / Dashboard.
/// Para cambiar cómo se ve esta sección, edita SOLO este archivo.
class HomeTheme extends ThemeExtension<HomeTheme> {
  final Color acento;
  final Gradient gradienteBalance;
  final double radioTarjetaBalance;
  final double radioModulo;

  const HomeTheme({
    required this.acento,
    required this.gradienteBalance,
    required this.radioTarjetaBalance,
    required this.radioModulo,
  });

  static const estandar = HomeTheme(
    acento: AppColors.gold,
    gradienteBalance: AppColors.goldGradient,
    radioTarjetaBalance: AppRadii.xl3,
    radioModulo: AppRadii.xl2,
  );

  @override
  HomeTheme copyWith({
    Color? acento,
    Gradient? gradienteBalance,
    double? radioTarjetaBalance,
    double? radioModulo,
  }) {
    return HomeTheme(
      acento: acento ?? this.acento,
      gradienteBalance: gradienteBalance ?? this.gradienteBalance,
      radioTarjetaBalance: radioTarjetaBalance ?? this.radioTarjetaBalance,
      radioModulo: radioModulo ?? this.radioModulo,
    );
  }

  @override
  HomeTheme lerp(ThemeExtension<HomeTheme>? other, double t) => this;
}
