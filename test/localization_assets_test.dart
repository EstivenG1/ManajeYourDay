import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:manage_your_day/core/localization/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads Spanish localization from the bundled ARB asset', () async {
    const locale = Locale('es');
    final localizations = AppLocalizations(locale);

    await localizations.load();

    expect(localizations.appTitle, 'Manage Your Day');
    expect(localizations.login, isNotEmpty);
  });

  test('loads English localization from the bundled ARB asset', () async {
    const locale = Locale('en');
    final localizations = AppLocalizations(locale);

    await localizations.load();

    expect(localizations.appTitle, 'Manage Your Day');
    expect(localizations.login, isNotEmpty);
  });
}
