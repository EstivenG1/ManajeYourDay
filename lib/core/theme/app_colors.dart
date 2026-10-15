import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

class AppColors {
  AppColors._();

  static bool get _dark => AppSettings.instance.isDark;
  static bool get _contrast => AppSettings.instance.highContrast;

  static Color get bgPrimary => _dark
      ? const Color(0xFF121212)
      : _contrast
          ? Colors.white
          : const Color(0xFFFAF8F2);
  static Color get surface =>
      _dark ? const Color(0xFF1E1E1E) : Colors.white;

  static List<Color> get bgSplashGradient => _dark
      ? const [Color(0xFF121212), Color(0xFF1D1B17), Color(0xFF252117)]
      : const [Color(0xFFFAF8F2), Color(0xFFFDF6E3), Color(0xFFFAF3D7)];

  static Color get gold => const Color(0xFFC9A84C);
  static Color get goldDark => const Color(0xFFA8873A);
  static Color get goldDeep => _dark ? const Color(0xFFFFD76A) : const Color(0xFF8B6914);
  static Color get goldSoftBg => _dark ? const Color(0xFF302A19) : const Color(0xFFFEF9EC);
  static Color get goldChipBg => _dark ? const Color(0xFF382F17) : const Color(0xFFFFF8E1);
  static Color get goldBorder => _dark ? const Color(0xFF776126) : const Color(0xFFFDE68A);
  static Color get goldMid => const Color(0xFFF0D87A);

  static LinearGradient get goldGradient => LinearGradient(
        colors: [gold, goldDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Color get green => const Color(0xFF2D7A4F);
  static Color get greenDark => const Color(0xFF1A5C38);
  static Color get greenChipBg => _dark ? const Color(0xFF173322) : const Color(0xFFDCFCE7);
  static Color get greenChipBorder => _dark ? const Color(0xFF285A3C) : const Color(0xFFBBF7D0);

  static LinearGradient get greenGradient => LinearGradient(
        colors: [green, greenDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Color get red => const Color(0xFFC0392B);
  static Color get redBright => const Color(0xFFE53E3E);
  static Color get redChipBg => _dark ? const Color(0xFF3A1C1A) : const Color(0xFFFEE2E2);
  static Color get redChipBorder => _dark ? const Color(0xFF6A302A) : const Color(0xFFFECACA);

  static LinearGradient get redGradient => LinearGradient(
        colors: [redBright, red],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static Color get textPrimary =>
      _dark ? Colors.white : const Color(0xFF1C1917);
  static Color get textSecondary => _dark
      ? const Color(0xFFD0CCC7)
      : _contrast
          ? const Color(0xFF4A4540)
          : const Color(0xFF78716C);
  static Color get textTertiary => _dark || _contrast
      ? const Color(0xFFB8B2AC)
      : const Color(0xFFA8A29E);
  static Color get borderSoft => _dark
      ? const Color(0xFF3A3733)
      : _contrast
          ? const Color(0xFF6B6258)
          : const Color(0xFFEDE8DE);

  static Color get amber => const Color(0xFFD97706);
  static Color get overlayDark => const Color.fromRGBO(0, 0, 0, 0.55);
  static Color get navBlurBg =>
      _dark ? const Color(0xF21E1E1E) : const Color.fromRGBO(255, 252, 245, 0.95);

  static List<BoxShadow> sombraPremium(
    Color color, {
    double blur = 20,
    double dy = 8,
  }) =>
      [
        BoxShadow(
          color: color.withValues(alpha: 0.28),
          blurRadius: blur,
          offset: Offset(0, dy),
        ),
      ];
}
