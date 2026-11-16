import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_your_day/core/theme/app_theme.dart';
import 'package:manage_your_day/features/reportes/reportes_screen.dart';

void main() {
  testWidgets('starts on Today and offers a report guide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const ReportesScreen(),
      ),
    );

    final today = tester.widget<Text>(find.text('Hoy'));
    final week = tester.widget<Text>(find.text('Semana'));
    expect(today.style?.color, Colors.white);
    expect(week.style?.color, isNot(Colors.white));

    await tester.tap(find.byTooltip('Guía de reportes'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cómo leer tus reportes'), findsOneWidget);
    expect(find.text('Hoy'), findsWidgets);
    expect(find.text('Semana'), findsWidgets);
    expect(find.text('Mes'), findsWidgets);
    expect(find.textContaining('Usa Exportar'), findsOneWidget);

    await tester.ensureVisible(find.text('Entendido'));
    await tester.tap(find.text('Entendido'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cómo leer tus reportes'), findsNothing);
  });
}
