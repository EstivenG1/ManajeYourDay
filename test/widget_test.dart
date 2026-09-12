import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/theme/app_theme.dart';
import 'package:myd/features/splash/welcome_screen.dart';

void main() {
  testWidgets('La pantalla de bienvenida muestra el logo MYD y el CTA',
      (WidgetTester tester) async {
    // Se prueba solo WelcomeScreen (no MydApp completo), porque MydApp
    // arranca con AuthGate, que necesita Supabase ya inicializado —
    // algo que solo pasa dentro de main(), no en un test aislado.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const WelcomeScreen(),
    ));

    expect(find.text('MYD'), findsOneWidget);
    expect(find.textContaining('Comenzar ahora'), findsOneWidget);
  });
}