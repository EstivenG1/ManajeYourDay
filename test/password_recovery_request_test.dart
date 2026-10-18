import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/theme/app_theme.dart';
import 'package:myd/features/auth/auth_screen.dart';
import 'package:myd/features/auth/password_recovery_request_dialog.dart';

void main() {
  testWidgets('forgot-password action opens the email request form', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AuthScreen(),
      ),
    );

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ingresa el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enviar enlace'), findsOneWidget);
    expect(find.byKey(const ValueKey('recovery-email')), findsOneWidget);
  });

  testWidgets('asks for account email and confirms sending the reset link', (
    tester,
  ) async {
    String? sentEmail;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PasswordRecoveryRequestDialog(
                  initialEmail: 'persona@correo.com',
                  onSend: (email) async => sentEmail = email,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ingresa el correo de tu cuenta y te enviaremos un enlace para restablecer tu contraseña.',
      ),
      findsOneWidget,
    );
    expect(find.text('persona@correo.com'), findsOneWidget);

    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(sentEmail, 'persona@correo.com');
    expect(
      find.text(
        'Si la cuenta existe, recibirás un correo con los pasos para cambiar tu contraseña.',
      ),
      findsOneWidget,
    );
    expect(find.text('Entendido'), findsOneWidget);
  });

  testWidgets('validates the email before attempting to send', (tester) async {
    var sendAttempted = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PasswordRecoveryRequestDialog(
                  onSend: (_) async => sendAttempted = true,
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(sendAttempted, isFalse);
  });
}
