import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/theme/app_theme.dart';
import 'package:myd/features/auth/password_recovery_screen.dart';

void main() {
  testWidgets('password recovery validates and updates the new password', (
    tester,
  ) async {
    String? savedPassword;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PasswordRecoveryScreen(
          onCompleted: () => completed = true,
          updatePassword: (password) async => savedPassword = password,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('new-password')),
      'secure-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'different-password',
    );
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(savedPassword, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('confirm-password')),
      'secure-password',
    );
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();

    expect(savedPassword, 'secure-password');
    expect(find.text('Contraseña actualizada'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    expect(completed, isTrue);
  });
}
