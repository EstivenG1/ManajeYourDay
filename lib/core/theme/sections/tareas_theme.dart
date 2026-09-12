import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radii.dart';

/// Diseño propio de la sección Tareas.
/// Para cambiar cómo se ve esta sección, edita SOLO este archivo.
class TareasTheme extends ThemeExtension<TareasTheme> {
  final Color prioridadAlta;
  final Color prioridadMedia;
  final Color prioridadBaja;
  final double radioTarjeta;
  final double radioCheckbox;

  const TareasTheme({
    required this.prioridadAlta,
    required this.prioridadMedia,
    required this.prioridadBaja,
    required this.radioTarjeta,
    required this.radioCheckbox,
  });

  static const estandar = TareasTheme(
    prioridadAlta: AppColors.red,
    prioridadMedia: AppColors.amber,
    prioridadBaja: AppColors.textTertiary,
    radioTarjeta: AppRadii.xl2,
    radioCheckbox: AppRadii.full,
  );

  @override
  TareasTheme copyWith({
    Color? prioridadAlta,
    Color? prioridadMedia,
    Color? prioridadBaja,
    double? radioTarjeta,
    double? radioCheckbox,
  }) {
    return TareasTheme(
      prioridadAlta: prioridadAlta ?? this.prioridadAlta,
      prioridadMedia: prioridadMedia ?? this.prioridadMedia,
      prioridadBaja: prioridadBaja ?? this.prioridadBaja,
      radioTarjeta: radioTarjeta ?? this.radioTarjeta,
      radioCheckbox: radioCheckbox ?? this.radioCheckbox,
    );
  }

  @override
  TareasTheme lerp(ThemeExtension<TareasTheme>? other, double t) => this;
}
