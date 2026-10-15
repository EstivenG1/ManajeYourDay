import 'package:intl/intl.dart';
import '../settings/app_settings.dart';

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
      ? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
      : ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  final meses = ingles
      ? [
          'January', 'February', 'March', 'April', 'May', 'June', 'July',
          'August', 'September', 'October', 'November', 'December'
        ]
      : [
          'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
          'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
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
    consejos.add('⚠️ Tus gastos superaron tus ingresos este mes. Revisa en qué '
        'categoría estás gastando más y ajusta tu presupuesto.');
  } else if (balance > 0 && ingresosMes > 0) {
    consejos.add('✅ ¡Vas muy bien! Tu balance de este mes es positivo. '
        'Considera guardar una parte en una meta de ahorro.');
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

  if (porcentajePresupuestoUsado != null &&
      porcentajePresupuestoUsado >= 80) {
    consejos.add(
      '⚠️ Has usado ${porcentajePresupuestoUsado.toStringAsFixed(0)}% de tus presupuestos activos.',
    );
  }

  if (tareasPendientes >= 5) {
    consejos.add('📋 Tienes $tareasPendientes tareas pendientes. Empieza por las '
        'de prioridad alta para no acumular más.');
  } else if (tareasTotales > 0 && tareasPendientes == 0) {
    consejos.add('🎉 ¡Completaste todas tus tareas! Es un buen momento para '
        'planear las de mañana.');
  }

  if (gastosMes == 0 && ingresosMes == 0) {
    consejos.add('💡 Aún no has registrado movimientos este mes. Anota tus gastos '
        'e ingresos a diario para tener reportes más precisos.');
  }

  if (consejos.isEmpty) {
    consejos.add('🌟 Sigue registrando tus tareas y finanzas para recibir consejos '
        'cada vez más personalizados.');
  }

  return consejos;
}
