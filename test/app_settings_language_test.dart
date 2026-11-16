import 'package:flutter_test/flutter_test.dart';
import 'package:manage_your_day/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('language preference applies only after settings reload', () async {
    SharedPreferences.setMockInitialValues({
      'language': 'es',
      'currency': 'COP',
    });
    await AppSettings.load();
    final settings = AppSettings.instance;

    await settings.setRegionalPreferences(currency: 'USD', language: 'en');

    expect(settings.language, 'en');
    expect(settings.currency, 'USD');
    expect(settings.locale.languageCode, 'es');

    await AppSettings.load();
    expect(settings.locale.languageCode, 'en');
  });
}
