import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radii.dart';

/// Diseño propio de la sección Reportes.
/// Para cambiar cómo se ve esta sección, edita SOLO este archivo.
class ReportesTheme extends ThemeExtension<ReportesTheme> {
  final Color kpiIngresoBg;
  final Color kpiIngresoBorder;
  final Color kpiGastoBg;
  final Color kpiGastoBorder;
  final Color barraCategoria; // color de barra "otras categorías" en gráficas
  final double radioTarjetaKpi;

  const ReportesTheme({
    required this.kpiIngresoBg,
    required this.kpiIngresoBorder,
    required this.kpiGastoBg,
    required this.kpiGastoBorder,
    required this.barraCategoria,
    required this.radioTarjetaKpi,
  });

  static const estandar = ReportesTheme(
    kpiIngresoBg: AppColors.greenChipBg,
    kpiIngresoBorder: AppColors.greenChipBorder,
    kpiGastoBg: AppColors.redChipBg,
    kpiGastoBorder: AppColors.redChipBorder,
    barraCategoria: AppColors.amber,
    radioTarjetaKpi: AppRadii.xl2,
  );

  @override
  ReportesTheme copyWith({
    Color? kpiIngresoBg,
    Color? kpiIngresoBorder,
    Color? kpiGastoBg,
    Color? kpiGastoBorder,
    Color? barraCategoria,
    double? radioTarjetaKpi,
  }) {
    return ReportesTheme(
      kpiIngresoBg: kpiIngresoBg ?? this.kpiIngresoBg,
      kpiIngresoBorder: kpiIngresoBorder ?? this.kpiIngresoBorder,
      kpiGastoBg: kpiGastoBg ?? this.kpiGastoBg,
      kpiGastoBorder: kpiGastoBorder ?? this.kpiGastoBorder,
      barraCategoria: barraCategoria ?? this.barraCategoria,
      radioTarjetaKpi: radioTarjetaKpi ?? this.radioTarjetaKpi,
    );
  }

  @override
  ReportesTheme lerp(ThemeExtension<ReportesTheme>? other, double t) => this;
}
