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

  group('ordenarTareasPorUrgencia', () {
    test('las tareas más urgentes quedan primero', () {
      final tareas = [
        {
          'titulo': 'Tarea baja',
          'prioridad': 'baja',
          'estado': 'pendiente',
          'fecha_limite': '2026-10-20T09:00:00',
        },
        {
          'titulo': 'Tarea alta',
          'prioridad': 'alta',
          'estado': 'pendiente',
          'fecha_limite': '2026-10-18T09:00:00',
        },
        {
          'titulo': 'Tarea media',
          'prioridad': 'media',
          'estado': 'pendiente',
          'fecha_limite': '2026-10-22T09:00:00',
        },
      ];

      final orden = ordenarTareasPorUrgencia(tareas);

      expect(orden.first['titulo'], 'Tarea alta');
      expect(orden[1]['titulo'], 'Tarea media');
      expect(orden.last['titulo'], 'Tarea baja');
    });
  });

  group('calcularResumenMetas', () {
    test('resume el progreso total y la meta más cercana', () {
      final resumen = calcularResumenMetas([
        {
          'nombre': 'Viaje',
          'monto_objetivo': 1000,
          'monto_actual': 600,
          'estado': 'activa',
        },
        {
          'nombre': 'Emergencias',
          'monto_objetivo': 2000,
          'monto_actual': 1000,
          'estado': 'activa',
        },
        {
          'nombre': 'Archivada',
          'monto_objetivo': 500,
          'monto_actual': 500,
          'estado': 'completada',
        },
      ]);

      expect(resumen.totalObjetivo, 3000);
      expect(resumen.totalActual, 1600);
      expect(resumen.metasActivas, 2);
      expect(resumen.porcentajeGeneral, closeTo(53.333333, 0.001));
      expect(resumen.nombreMetaMasCercana, 'Viaje');
      expect(resumen.porcentajeMetaMasCercana, 60);
    });

    test('devuelve valores vacíos cuando no hay metas activas', () {
      final resumen = calcularResumenMetas([]);

      expect(resumen.totalObjetivo, 0);
      expect(resumen.totalActual, 0);
      expect(resumen.metasActivas, 0);
      expect(resumen.porcentajeGeneral, 0);
      expect(resumen.nombreMetaMasCercana, 'Sin metas');
    });
  });

  group('calcularResumenSemana', () {
    test('resume ingresos, gastos y tareas de la semana actual', () {
      final hoy = DateTime.now();
      final inicioSemana = DateTime(
        hoy.year,
        hoy.month,
        hoy.day - (hoy.weekday - 1),
      );
      final finalSemana = inicioSemana.add(const Duration(days: 2));

      final resumen = calcularResumenSemana(
        movimientos: [
          {
            'fecha': inicioSemana.toIso8601String(),
            'tipo': 'ingreso',
            'monto': 500,
          },
          {
            'fecha': finalSemana.toIso8601String(),
            'tipo': 'gasto',
            'monto': 200,
          },
          {
            'fecha': inicioSemana
                .subtract(const Duration(days: 20))
                .toIso8601String(),
            'tipo': 'gasto',
            'monto': 1000,
          },
        ],
        tareas: [
          {
            'fecha_limite': inicioSemana.toIso8601String(),
            'estado': 'completada',
          },
          {
            'fecha_limite': finalSemana.toIso8601String(),
            'estado': 'pendiente',
          },
          {
            'fecha_limite': inicioSemana
                .subtract(const Duration(days: 30))
                .toIso8601String(),
            'estado': 'completada',
          },
        ],
      );

      expect(resumen.ingresos, 500);
      expect(resumen.gastos, 200);
      expect(resumen.balance, 300);
      expect(resumen.tareasCompletadas, 1);
      expect(resumen.tareasTotales, 2);
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
