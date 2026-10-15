import 'package:flutter_test/flutter_test.dart';
import 'package:myd/core/services/home_utils.dart';

void main() {
  group('calcularIndiceProductividad', () {
    test('calcula el porcentaje completado', () {
      expect(calcularIndiceProductividad(completadas: 3, totales: 4), 75);
    });

    test('devuelve cero cuando no hay tareas', () {
      expect(calcularIndiceProductividad(completadas: 0, totales: 0), 0);
    });

    test('mantiene el resultado dentro de 0 y 100', () {
      expect(calcularIndiceProductividad(completadas: 9, totales: 4), 100);
    });
  });

  group('generarRecomendacionesLocales', () {
    test('advierte cuando sube el gasto y se acerca al presupuesto', () {
      final recomendaciones = generarRecomendacionesLocales(
        ingresosMes: 3000,
        gastosMes: 1500,
        tareasPendientes: 0,
        tareasCompletadas: 0,
        tareasTotales: 0,
        gastosMesAnterior: 1000,
        porcentajePresupuestoUsado: 85,
      );

      expect(
        recomendaciones.any((item) => item.contains('subieron 50%')),
        isTrue,
      );
      expect(recomendaciones.any((item) => item.contains('85%')), isTrue);
    });
  });
}
