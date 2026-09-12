import 'package:intl/intl.dart';

/// Formatea un monto como pesos, con separador de miles ("$170.000").
String formatearMonto(num monto) {
  final formato = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  return formato.format(monto);
}

/// Formatea la fecha en español sin depender de datos de localización
/// de `intl` (evita el error de "Locale data has not been initialized").
String formatearFechaEs(DateTime fecha) {
  const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto',
    'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];
  final dia = dias[fecha.weekday - 1];
  final mes = meses[fecha.month - 1];
  final texto = '$dia, ${fecha.day} de $mes de ${fecha.year}';
  return texto[0].toUpperCase() + texto.substring(1);
}

/// Genera consejos simples basados en los datos del usuario. Es lógica
/// local (sin llamar a un modelo de IA todavía); más adelante se puede
/// reemplazar por una función que llame a un modelo real sin tocar la UI.
List<String> generarConsejosIA({
  required double ingresosMes,
  required double gastosMes,
  required int tareasPendientes,
  required int tareasCompletadas,
  required int tareasTotales,
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
