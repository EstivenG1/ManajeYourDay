import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  ThemeMode _themeMode = ThemeMode.light;
  double _textScale = 1;
  bool _highContrast = false;
  bool _notificationsEnabled = true;
  String _currency = 'COP';
  String _language = 'es';

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get notificationsEnabled => _notificationsEnabled;
  String get currency => _currency;
  String get language => _language;
  Locale get locale => Locale(_language);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final instance = AppSettings.instance;
    instance._themeMode = prefs.getBool('dark_mode') == true
        ? ThemeMode.dark
        : ThemeMode.light;
    instance._textScale = prefs.getDouble('text_scale') ?? 1;
    instance._highContrast = prefs.getBool('high_contrast') ?? false;
    instance._notificationsEnabled =
        prefs.getBool('notifications_enabled') ?? true;
    instance._currency = prefs.getString('currency') ?? 'COP';
    instance._language = prefs.getString('language') ?? 'es';
  }

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value == ThemeMode.dark);
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(0.85, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_scale', _textScale);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('high_contrast', value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
  }

  Future<void> setRegionalPreferences({
    required String currency,
    required String language,
  }) async {
    _currency = currency;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    await prefs.setString('language', language);
  }
}
