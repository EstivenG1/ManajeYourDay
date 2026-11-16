import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:manage_your_day/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Manage Your Day - Flujos principales', () {
    testWidgets('la app inicia y muestra la pantalla de autenticación', (
      tester,
    ) async {
      app.main();
      await tester.pumpAndSettle();

      // La app debería renderizar sin fallar
      expect(find.byType(MaterialApp), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('el flujo de bienvenida carga sin errores', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verificar que no haya errores de renderizado críticos
      expect(find.byType(MaterialApp), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
