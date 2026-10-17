import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/theme/app_theme.dart';
import 'package:myd/features/auth/auth_screen.dart';
import 'package:myd/features/legal/centro_ayuda_screen.dart';
import 'package:myd/features/legal/legal_info_screen.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: home,
  );
}

void main() {
  testWidgets('help center exposes feature guides and legal documents', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const CentroAyudaScreen()));
    await tester.pumpAndSettle();

    expect(find.text('GUÍAS POR SECCIÓN'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('INFORMACIÓN LEGAL'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('INFORMACIÓN LEGAL'), findsOneWidget);
    expect(find.text('Repetir recorrido completo'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Tareas'), findsOneWidget);
    expect(find.text('Reportes'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Términos y condiciones'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalInfoScreen), findsOneWidget);
    expect(find.text('1. Aceptación y alcance'), findsOneWidget);
    expect(
      find.textContaining('manage.your.day.oficial@gmail.com'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('9. Ley aplicable'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('9. Ley aplicable'), findsOneWidget);

    await tester.tap(find.text('Privacidad'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('manage.your.day.oficial@gmail.com'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.textContaining('manage.your.day.oficial@gmail.com'),
      findsOneWidget,
    );
  });

  testWidgets('registration opens terms and privacy before acceptance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AuthScreen(initialTab: AuthTab.register)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Acepto los términos y condiciones y la política de privacidad.',
      ),
      findsOneWidget,
    );

    final termsLink = find.text('Leer términos y condiciones');
    await tester.ensureVisible(termsLink);
    await tester.tap(termsLink);
    await tester.pumpAndSettle();

    expect(find.byType(LegalInfoScreen), findsOneWidget);
    expect(find.text('1. Aceptación y alcance'), findsOneWidget);
  });

  testWidgets('feature guide explains an individual app section', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const CentroAyudaScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finanzas').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Registra ingresos y gastos, organiza presupuestos y consulta tus metas de ahorro.',
      ),
      findsNWidgets(2),
    );
  });
}
