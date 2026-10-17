import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/formatters/money_input_formatter.dart';
import 'package:myd/core/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
  });

  group('money input formatting', () {
    test('groups COP integer digits with periods', () async {
      expect(formatearMontoEntrada('20000'), '20.000');
      expect(formatearMontoEntrada('2000000'), '2.000.000');
      expect(parseMontoEntrada('2.000.000'), 2000000);
    });

    test('keeps up to two COP decimal digits with comma separator', () {
      expect(formatearMontoEntrada('20000,50'), '20.000,50');
      expect(formatearMontoEntrada('20000,567'), '20.000,56');
      expect(parseMontoEntrada('20.000,50'), 20000.5);
    });

    test('uses the currency convention for USD and MXN', () async {
      for (final currency in ['USD', 'MXN']) {
        await AppSettings.instance.setRegionalPreferences(
          currency: currency,
          language: 'en',
        );
        expect(formatearMontoEntrada('20000'), '20,000');
        expect(formatearMontoEntrada('20000.50'), '20,000.50');
        expect(parseMontoEntrada('20,000.50'), 20000.5);
        expect(sufijoMonedaEntrada, currency);
      }
    });

    test('uses Spanish separators for EUR, ARS, CLP and PEN', () async {
      for (final currency in ['EUR', 'ARS', 'CLP', 'PEN']) {
        await AppSettings.instance.setRegionalPreferences(
          currency: currency,
          language: 'es',
        );
        if (currency == 'PEN') {
          expect(formatearMontoEntrada('20000'), '20,000');
          expect(formatearMontoEntrada('20000.50'), '20,000.50');
          expect(parseMontoEntrada('20,000.50'), 20000.5);
        } else {
          expect(formatearMontoEntrada('20000'), '20.000');
          expect(formatearMontoEntrada('20000,50'), '20.000,50');
          expect(parseMontoEntrada('20.000,50'), 20000.5);
        }
      }
    });

    test('formats existing numeric values for editing', () async {
      expect(formatearMontoParaCampo(20000), '20.000');
      expect(formatearMontoParaCampo(20000.5), '20.000,5');
      await AppSettings.instance.setRegionalPreferences(
        currency: 'USD',
        language: 'en',
      );
      expect(formatearMontoParaCampo(20000.5), '20,000.5');
    });

    test('returns null for empty or malformed numeric input', () {
      expect(parseMontoEntrada(''), isNull);
      expect(parseMontoEntrada('abc'), isNull);
    });
  });

  testWidgets('formats as the user types and preserves the caret', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyTextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Monto'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '20000');
    await tester.pump();

    expect(controller.text, '20.000');
    expect(controller.selection.extentOffset, controller.text.length);
    expect(parseMontoEntrada(controller.text), 20000);
    expect(find.text('COP'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('the shared entry field follows USD separators and currency', (
    tester,
  ) async {
    await AppSettings.instance.setRegionalPreferences(
      currency: 'USD',
      language: 'en',
    );
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoneyTextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '20000.50');
    await tester.pump();

    expect(controller.text, '20,000.50');
    expect(parseMontoEntrada(controller.text), 20000.5);
    expect(find.text('USD'), findsOneWidget);
    controller.dispose();
  });
}
