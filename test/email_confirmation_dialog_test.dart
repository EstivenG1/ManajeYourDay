import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_your_day/core/theme/app_theme.dart';
import 'package:manage_your_day/features/auth/email_confirmation_dialog.dart';

void main() {
  testWidgets('shows signup confirmation steps and the registered email', (
    tester,
  ) async {
    const email = 'myd.test@example.com';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const EmailConfirmationDialog(email: email),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('¡Tu cuenta casi está lista!'), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(find.text('Ve al correo de la cuenta que ingresaste.'), findsOneWidget);
    expect(
      find.textContaining('correo de confirmación de cuenta de MYD'),
      findsOneWidget,
    );
    expect(find.textContaining('botón “Confirmar correo”'), findsOneWidget);
    expect(
      find.text('Vuelve a MYD e inicia sesión con tu correo y contraseña.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Entendido'));
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('¡Tu cuenta casi está lista!'), findsNothing);
  });
}
