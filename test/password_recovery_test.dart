import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/supabase/supabase_config.dart';
import 'package:myd/core/theme/app_theme.dart';
import 'package:myd/features/auth/password_recovery_screen.dart';

void main() {
  test('recovery deep link remains detectable before AuthGate subscribes', () {
    final recoveryUri = Uri.parse(
      'io.supabase.myd://reset-password?code=verification-code',
    );

    expect(SupabaseConfig.detectAuthRedirect(recoveryUri), isTrue);
    expect(SupabaseConfig.consumePasswordRecoveryRedirect(), isTrue);
    expect(SupabaseConfig.consumePasswordRecoveryRedirect(), isFalse);
  });

  test('other authentication callbacks are still handled', () {
    final callbackUri = Uri.parse(
      'io.supabase.myd://login-callback?code=oauth-code',
    );

    expect(SupabaseConfig.detectAuthRedirect(callbackUri), isTrue);
    expect(SupabaseConfig.consumePasswordRecoveryRedirect(), isFalse);
  });

  testWidgets('password recovery validates and updates the new password', (
    tester,
  ) async {
    String? savedPassword;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
