import 'package:flutter/material.dart';

/// Paleta de colores oficial de MYD, tomada 1:1 del sistema de diseño
/// de Figma. Única fuente de colores "crudos" del proyecto — ninguna
/// pantalla debería escribir Color(0x...) directo, siempre a través de
/// AppColors o del tema de su sección (ver core/theme/sections/).
class AppColors {
  AppColors._();

  // ------- Fondos -------
  static const Color bgPrimary = Color(0xFFFAF8F2); // marfil cálido
  static const Color surface = Color(0xFFFFFFFF); // tarjetas, modales, inputs, bottom nav

  // Degradado de fondo de la pantalla Splash
  static const List<Color> bgSplashGradient = [
    Color(0xFFFAF8F2),
    Color(0xFFFDF6E3),
    Color(0xFFFAF3D7),
  ];

  // ------- Dorado (marca) -------
  static const Color gold = Color(0xFFC9A84C); // acento principal
  static const Color goldDark = Color(0xFFA8873A); // 2do color de gradiente / labels
  static const Color goldDeep = Color(0xFF8B6914); // variante más oscura de texto/label
  static const Color goldSoftBg = Color(0xFFFEF9EC); // fondo tarjeta "Consejo IA"
  static const Color goldChipBg = Color(0xFFFFF8E1); // chips / pills en splash
  static const Color goldBorder = Color(0xFFFDE68A); // bordes de acento dorado
  static const Color goldMid = Color(0xFFF0D87A); // hover / variación suave

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------- Verde (ingresos / positivo) -------
  static const Color green = Color(0xFF2D7A4F);
  static const Color greenDark = Color(0xFF1A5C38);
  static const Color greenChipBg = Color(0xFFDCFCE7);
  static const Color greenChipBorder = Color(0xFFBBF7D0);

  static const LinearGradient greenGradient = LinearGradient(
    colors: [green, greenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------- Rojo (gastos / negativo) -------
  static const Color red = Color(0xFFC0392B); // montos negativos, prioridad alta
  static const Color redBright = Color(0xFFE53E3E); // botón "Agregar gasto"
  static const Color redChipBg = Color(0xFFFEE2E2);
  static const Color redChipBorder = Color(0xFFFECACA);

  static const LinearGradient redGradient = LinearGradient(
    colors: [redBright, red],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ------- Texto -------
  static const Color textPrimary = Color(0xFF1C1917); // títulos, texto principal
  static const Color textSecondary = Color(0xFF78716C); // subtítulos, labels
  static const Color textTertiary = Color(0xFFA8A29E); // fechas, hints, nav inactivo, prioridad baja

  // ------- Bordes -------
  static const Color borderSoft = Color(0xFFEDE8DE);

  // ------- Especiales -------
  static const Color amber = Color(0xFFD97706); // prioridad media
  static const Color overlayDark = Color.fromRGBO(28, 25, 23, 0.45);
  static const Color navBlurBg = Color.fromRGBO(255, 252, 245, 0.95);

  /// Sombra "premium": el color propio del elemento, a ~42% de opacidad.
  static List<BoxShadow> sombraPremium(Color color, {double blur = 20, double dy = 8}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.42),
        blurRadius: blur,
        offset: Offset(0, dy),
      ),
    ];
  }
}
