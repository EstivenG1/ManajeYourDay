import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Estilos de texto del sistema de diseño MYD.
/// - Space Grotesk: logo, títulos grandes, KPIs, balance, saludo.
/// - Inter: todo lo demás (labels, botones, chips, fechas, etc.)
class AppTypography {
  AppTypography._();

  // Logo / hero de la pantalla Splash
  static TextStyle heroTitle = GoogleFonts.spaceGrotesk(
    fontSize: 64, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
  );

  // Balance grande (Finanzas / Dashboard)
  static TextStyle balanceDisplay = GoogleFonts.spaceGrotesk(
    fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
  );

  // Números KPI en Reportes
  static TextStyle kpiNumber = GoogleFonts.spaceGrotesk(
    fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary,
  );

  // Títulos de pantalla: "Finanzas", "Tareas", "Reportes"
  static TextStyle screenTitle = GoogleFonts.spaceGrotesk(
    fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );

  // Saludo en dashboard: "¡Hola, Estiven!"
  static TextStyle greeting = GoogleFonts.spaceGrotesk(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );

  // Texto base: descripciones, consejos IA
  static TextStyle bodyBase = GoogleFonts.inter(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );

  // Nombres de transacciones / tareas / descripciones de módulo
  static TextStyle itemTitle = GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  // Etiquetas de sección: "MÓDULOS", "TAREAS PENDIENTES"
  static TextStyle sectionLabel = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.4,
  );

  // Labels del bottom nav
  static TextStyle navLabel = GoogleFonts.inter(
    fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary,
  );

  // Texto secundario genérico (subtítulos, labels de formulario)
  static TextStyle secondary = GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
  );
}
