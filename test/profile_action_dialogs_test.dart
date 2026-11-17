import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manage_your_day/core/theme/app_theme.dart';
import 'package:manage_your_day/features/perfil/perfil_action_dialogs.dart';

void main() {
  testWidgets('email change request dialog closes safely when empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<String>(
                context: context,
                builder: (_) => const EmailChangeRequestDialog(
                  initialEmail: 'actual@example.com',
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
    expect(find.text('Cambiar dirección de correo'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Cambiar dirección de correo'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Cambiar dirección de correo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email change dialog explains confirmation steps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const EmailChangeConfirmationDialog(
                  email: 'nuevo@example.com',
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

    expect(find.text('Confirma el cambio de correo'), findsOneWidget);
    expect(find.text('nuevo@example.com'), findsOneWidget);
    expect(find.textContaining('correo actual y del nuevo'), findsOneWidget);
    expect(
      find.textContaining('Al regresar a MYD, ese correo ya quedó confirmado'),
      findsOneWidget,
    );
    expect(
      find.textContaining('cuando confirmes los dos enlaces'),
      findsOneWidget,
    );
  });

  testWidgets('invite dialog calls share action', (WidgetTester tester) async {
    var shared = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => InviteUsersDialog(onShare: () => shared = true),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compartir invitación'));

    expect(shared, isTrue);
  });
}
