import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radii.dart';

/// Diseño propio de la sección Finanzas.
/// Para cambiar cómo se ve esta sección, edita SOLO este archivo.
class FinanzasTheme extends ThemeExtension<FinanzasTheme> {
  final Color colorIngreso;
  final Color colorGasto;
  final Gradient gradienteBotonIngreso;
  final Gradient gradienteBotonGasto;
  final Color chipIngresoBg;
  final Color chipIngresoBorder;
  final Color chipGastoBg;
  final Color chipGastoBorder;
  final double radioTarjeta;
  final double radioChip;

  const FinanzasTheme({
    required this.colorIngreso,
    required this.colorGasto,
    required this.gradienteBotonIngreso,
    required this.gradienteBotonGasto,
    required this.chipIngresoBg,
    required this.chipIngresoBorder,
    required this.chipGastoBg,
    required this.chipGastoBorder,
    required this.radioTarjeta,
    required this.radioChip,
  });

  static const estandar = FinanzasTheme(
    colorIngreso: AppColors.green,
    colorGasto: AppColors.red,
    gradienteBotonIngreso: AppColors.greenGradient,
    gradienteBotonGasto: AppColors.redGradient,
    chipIngresoBg: AppColors.greenChipBg,
    chipIngresoBorder: AppColors.greenChipBorder,
    chipGastoBg: AppColors.redChipBg,
    chipGastoBorder: AppColors.redChipBorder,
    radioTarjeta: AppRadii.xl2,
    radioChip: AppRadii.xl,
  );

  @override
  FinanzasTheme copyWith({
    Color? colorIngreso,
    Color? colorGasto,
    Gradient? gradienteBotonIngreso,
    Gradient? gradienteBotonGasto,
    Color? chipIngresoBg,
    Color? chipIngresoBorder,
    Color? chipGastoBg,
    Color? chipGastoBorder,
    double? radioTarjeta,
    double? radioChip,
  }) {
    return FinanzasTheme(
      colorIngreso: colorIngreso ?? this.colorIngreso,
      colorGasto: colorGasto ?? this.colorGasto,
      gradienteBotonIngreso: gradienteBotonIngreso ?? this.gradienteBotonIngreso,
      gradienteBotonGasto: gradienteBotonGasto ?? this.gradienteBotonGasto,
      chipIngresoBg: chipIngresoBg ?? this.chipIngresoBg,
      chipIngresoBorder: chipIngresoBorder ?? this.chipIngresoBorder,
      chipGastoBg: chipGastoBg ?? this.chipGastoBg,
      chipGastoBorder: chipGastoBorder ?? this.chipGastoBorder,
      radioTarjeta: radioTarjeta ?? this.radioTarjeta,
      radioChip: radioChip ?? this.radioChip,
    );
  }

  @override
  FinanzasTheme lerp(ThemeExtension<FinanzasTheme>? other, double t) => this;
}
