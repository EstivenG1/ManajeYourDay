import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radii.dart';
import 'sections/home_theme.dart';
import 'sections/finanzas_theme.dart';
import 'sections/tareas_theme.dart';
import 'sections/reportes_theme.dart';
import 'sections/auth_theme.dart';

// Re-exporta todo lo del sistema de diseño para que cualquier pantalla
// solo necesite: import '.../core/theme/app_theme.dart';
export 'app_colors.dart';
export 'app_typography.dart';
export 'app_radii.dart';
export 'app_animations.dart';
export 'sections/home_theme.dart';
export 'sections/finanzas_theme.dart';
export 'sections/tareas_theme.dart';
export 'sections/reportes_theme.dart';
export 'sections/auth_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgPrimary,
      primaryColor: AppColors.gold,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.green,
        surface: AppColors.surface,
        error: AppColors.red,
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: AppTypography.bodyBase,
        bodyMedium: AppTypography.secondary,
        titleLarge: AppTypography.screenTitle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.screenTitle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          side: const BorderSide(color: AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.white,
          textStyle: AppTypography.itemTitle.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl2)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.gold, width: AppRadii.borderWidth),
          textStyle: AppTypography.itemTitle.copyWith(fontSize: 16),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          textStyle: AppTypography.secondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          borderSide: const BorderSide(color: AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          borderSide: const BorderSide(color: AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          borderSide: const BorderSide(color: AppColors.gold, width: AppRadii.borderWidth),
        ),
        labelStyle: AppTypography.secondary,
        hintStyle: AppTypography.secondary.copyWith(color: AppColors.textTertiary),
      ),
      dividerColor: AppColors.borderSoft,
      // Temas propios de cada sección — para cambiar el diseño de un
      // módulo completo, se edita SOLO su archivo en core/theme/sections/.
      extensions: const [
        HomeTheme.estandar,
        FinanzasTheme.estandar,
        TareasTheme.estandar,
        ReportesTheme.estandar,
        AuthTheme.estandar,
      ],
    );
  }
}
