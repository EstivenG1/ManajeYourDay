import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/app_settings.dart';

Future<bool> debeMostrarTutorial(String key) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) != true;
}

Future<void> marcarTutorialMostrado(String key) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, true);
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final GlobalKey target;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.target,
  });
}

class ResumenSemana {
  final int tareasCompletadas;
  final int tareasTotales;
  final double ingresos;
  final double gastos;
  final double balance;

  const ResumenSemana({
    required this.tareasCompletadas,
    required this.tareasTotales,
    required this.ingresos,
    required this.gastos,
    required this.balance,
  });
}

class ResumenMeta {
  final double totalObjetivo;
  final double totalActual;
  final int metasActivas;
  final double porcentajeGeneral;
  final String nombreMetaMasCercana;
  final double porcentajeMetaMasCercana;

  const ResumenMeta({
    required this.totalObjetivo,
    required this.totalActual,
    required this.metasActivas,
    required this.porcentajeGeneral,
    required this.nombreMetaMasCercana,
    required this.porcentajeMetaMasCercana,
  });
}

int _pesoPrioridad(String? prioridad) {
  switch ((prioridad ?? 'media').toLowerCase()) {
    case 'alta':
      return 3;
    case 'media':
      return 2;
    case 'baja':
    default:
      return 1;
  }
}

List<Map<String, dynamic>> ordenarTareasPorUrgencia(
  List<Map<String, dynamic>> tareas,
) {
  final lista = List<Map<String, dynamic>>.from(tareas);
  final ahora = DateTime.now();
  lista.sort((a, b) {
    final estadoA = (a['estado'] ?? 'pendiente') == 'completada';
    final estadoB = (b['estado'] ?? 'pendiente') == 'completada';
    if (estadoA != estadoB) {
      return estadoA ? 1 : -1;
    }

    final prioridadA = _pesoPrioridad(a['prioridad']?.toString());
    final prioridadB = _pesoPrioridad(b['prioridad']?.toString());
    if (prioridadA != prioridadB) {
      return prioridadB.compareTo(prioridadA);
    }

    final fechaA =
        DateTime.tryParse(a['fecha_limite']?.toString() ?? '') ??
        ahora.add(const Duration(days: 3650));
    final fechaB =
        DateTime.tryParse(b['fecha_limite']?.toString() ?? '') ??
        ahora.add(const Duration(days: 3650));

    final urgenteA = ahora.isAfter(fechaA) ? 1 : 0;
    final urgenteB = ahora.isAfter(fechaB) ? 1 : 0;
    if (urgenteA != urgenteB) {
      return urgenteB.compareTo(urgenteA);
    }

    return fechaA.compareTo(fechaB);
  });
  return lista;
}

ResumenMeta calcularResumenMetas(List<Map<String, dynamic>> metas) {
  final activas = metas.where((meta) => meta['estado'] == 'activa').toList();

  if (activas.isEmpty) {
    return const ResumenMeta(
      totalObjetivo: 0,
      totalActual: 0,
      metasActivas: 0,
      porcentajeGeneral: 0,
      nombreMetaMasCercana: 'Sin metas',
      porcentajeMetaMasCercana: 0,
    );
  }

  double totalObjetivo = 0;
  double totalActual = 0;
  String nombreMetaMasCercana = 'Sin metas';
  double porcentajeMetaMasCercana = 0;

  for (final meta in activas) {
    final objetivo = (meta['monto_objetivo'] as num?)?.toDouble() ?? 0;
    final actual = (meta['monto_actual'] as num?)?.toDouble() ?? 0;
    totalObjetivo += objetivo;
    totalActual += actual;

    final porcentaje = objetivo <= 0 ? 0.0 : (actual / objetivo) * 100;
    if (porcentaje > porcentajeMetaMasCercana) {
      nombreMetaMasCercana = (meta['nombre'] as String?) ?? 'Meta';
      porcentajeMetaMasCercana = porcentaje.toDouble();
    }
  }

  final porcentajeGeneral = totalObjetivo <= 0
      ? 0.0
      : (totalActual / totalObjetivo) * 100;

  return ResumenMeta(
    totalObjetivo: totalObjetivo,
    totalActual: totalActual,
    metasActivas: activas.length,
    porcentajeGeneral: porcentajeGeneral,
    nombreMetaMasCercana: nombreMetaMasCercana,
    porcentajeMetaMasCercana: porcentajeMetaMasCercana,
  );
}

/// Resume la actividad de la semana actual para el dashboard.
ResumenSemana calcularResumenSemana({
  required List<Map<String, dynamic>> movimientos,
  required List<Map<String, dynamic>> tareas,
}) {
  final ahora = DateTime.now();
  final inicioSemana = DateTime(
    ahora.year,
    ahora.month,
    ahora.day - (ahora.weekday - 1),
  );
  final finSemana = inicioSemana.add(const Duration(days: 6));

  double ingresos = 0;
  double gastos = 0;
  int tareasCompletadas = 0;
  int tareasTotales = 0;

  for (final movimiento in movimientos) {
    final fechaTexto = movimiento['fecha']?.toString();
    if (fechaTexto == null || fechaTexto.isEmpty) continue;
    final fecha = DateTime.tryParse(fechaTexto);
    if (fecha == null) continue;
    if (fecha.isBefore(inicioSemana) || fecha.isAfter(finSemana)) continue;

    final monto = (movimiento['monto'] as num?)?.toDouble() ?? 0;
    if (movimiento['tipo'] == 'ingreso') {
      ingresos += monto;
    } else if (movimiento['tipo'] == 'gasto') {
      gastos += monto;
    }
  }

  for (final tarea in tareas) {
    final fechaTexto = tarea['fecha_limite']?.toString();
    if (fechaTexto == null || fechaTexto.isEmpty) continue;
    final fecha = DateTime.tryParse(fechaTexto);
    if (fecha == null) continue;
    if (fecha.isBefore(inicioSemana) || fecha.isAfter(finSemana)) continue;

    tareasTotales++;
    if (tarea['estado'] == 'completada') {
      tareasCompletadas++;
    }
  }

  return ResumenSemana(
    tareasCompletadas: tareasCompletadas,
    tareasTotales: tareasTotales,
    ingresos: ingresos,
    gastos: gastos,
    balance: ingresos - gastos,
  );
}

/// Formatea un monto como pesos, con separador de miles ("$170.000").
String formatearMonto(num monto) {
  final settings = AppSettings.instance;
  const locales = {
    'COP': 'es_CO',
    'USD': 'en_US',
    'MXN': 'es_MX',
    'EUR': 'es_ES',
    'ARS': 'es_AR',
    'CLP': 'es_CL',
    'PEN': 'es_PE',
  };
  final formato = NumberFormat.currency(
    locale: locales[settings.currency] ?? 'es_CO',
    name: settings.currency,
    decimalDigits: 0,
  );
  return formato.format(monto);
}

/// Formatea la fecha en español sin depender de datos de localización
/// de `intl` (evita el error de "Locale data has not been initialized").
String formatearFechaEs(DateTime fecha) {
  final ingles = AppSettings.instance.language == 'en';
  final dias = ingles
      ? [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ]
      : [
          'lunes',
          'martes',
          'miércoles',
          'jueves',
          'viernes',
          'sábado',
          'domingo',
        ];
  final meses = ingles
      ? [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ]
      : [
          'enero',
          'febrero',
          'marzo',
          'abril',
          'mayo',
          'junio',
          'julio',
          'agosto',
          'septiembre',
          'octubre',
          'noviembre',
          'diciembre',
        ];
  final dia = dias[fecha.weekday - 1];
  final mes = meses[fecha.month - 1];
  final texto = ingles
      ? '$dia, ${meses[fecha.month - 1]} ${fecha.day}, ${fecha.year}'
      : '$dia, ${fecha.day} de $mes de ${fecha.year}';
  return texto[0].toUpperCase() + texto.substring(1);
}

double calcularIndiceProductividad({
  required int completadas,
  required int totales,
}) {
  if (totales <= 0) return 0;
  return (completadas / totales * 100).clamp(0, 100).toDouble();
}

/// Genera sugerencias deterministas a partir de los datos del usuario.
List<String> generarRecomendacionesLocales({
  required double ingresosMes,
  required double gastosMes,
  required int tareasPendientes,
  required int tareasCompletadas,
  required int tareasTotales,
  double? gastosMesAnterior,
  double? porcentajePresupuestoUsado,
}) {
  final consejos = <String>[];
  final balance = ingresosMes - gastosMes;

  if (gastosMes > 0 && ingresosMes > 0 && gastosMes > ingresosMes) {
    consejos.add(
      '⚠️ Tus gastos superaron tus ingresos este mes. Revisa en qué '
      'categoría estás gastando más y ajusta tu presupuesto.',
    );
  } else if (balance > 0 && ingresosMes > 0) {
    consejos.add(
      '✅ ¡Vas muy bien! Tu balance de este mes es positivo. '
      'Considera guardar una parte en una meta de ahorro.',
    );
  }

  if (gastosMesAnterior != null && gastosMesAnterior > 0) {
    final variacion =
        ((gastosMes - gastosMesAnterior) / gastosMesAnterior) * 100;
    if (variacion >= 20) {
      consejos.add(
        '📈 Tus gastos subieron ${variacion.toStringAsFixed(0)}% frente al mes pasado. '
        'Revisa tus movimientos recientes para detectar cambios.',
      );
    } else if (variacion <= -20) {
      consejos.add(
        '✅ Tus gastos bajaron ${variacion.abs().toStringAsFixed(0)}% frente al mes pasado. '
        'Mantén los hábitos que te están funcionando.',
      );
    }
  }

  if (porcentajePresupuestoUsado != null && porcentajePresupuestoUsado >= 80) {
    consejos.add(
      '⚠️ Has usado ${porcentajePresupuestoUsado.toStringAsFixed(0)}% de tus presupuestos activos.',
    );
  }

  if (tareasPendientes >= 5) {
    consejos.add(
      '📋 Tienes $tareasPendientes tareas pendientes. Empieza por las '
      'de prioridad alta para no acumular más.',
    );
  } else if (tareasTotales > 0 && tareasPendientes == 0) {
    consejos.add(
      '🎉 ¡Completaste todas tus tareas! Es un buen momento para '
      'planear las de mañana.',
    );
  }

  if (gastosMes == 0 && ingresosMes == 0) {
    consejos.add(
      '💡 Aún no has registrado movimientos este mes. Anota tus gastos '
      'e ingresos a diario para tener reportes más precisos.',
    );
  }

  if (consejos.isEmpty) {
    consejos.add(
      '🌟 Sigue registrando tus tareas y finanzas para recibir consejos '
      'cada vez más personalizados.',
    );
  }

  return consejos;
}
