import '../supabase/supabase_config.dart';
import 'notification_service.dart';

/// Maneja las tareas que se repiten.
///
/// Enfoque: no se crean todas las ocurrencias futuras de golpe (eso
/// llenaría la base de datos de tareas que quizá nunca se usen).
/// En vez de eso, cuando el usuario completa una tarea recurrente se
/// genera automáticamente la SIGUIENTE ocurrencia. Así la lista siempre
/// muestra solo lo que viene ahora.
class RecurrenciaService {
  static const etiquetas = {
    'ninguna': 'No se repite',
    'diaria': 'Todos los días',
    'semanal': 'Cada semana',
    'quincenal': 'Cada 15 días',
    'mensual': 'Cada mes',
  };

  /// Calcula cuándo debería caer la próxima ocurrencia.
  static DateTime? proximaFecha(DateTime actual, String recurrencia) {
    switch (recurrencia) {
      case 'diaria':
        return actual.add(const Duration(days: 1));
      case 'semanal':
        return actual.add(const Duration(days: 7));
      case 'quincenal':
        return actual.add(const Duration(days: 15));
      case 'mensual':
        // Se usa DateTime(año, mes+1, día) para que el mes avance bien
        // incluso a fin de año. Si el día no existe en el mes siguiente
        // (ej. 31 de enero -> febrero), Dart lo ajusta automáticamente
        // al desbordarse hacia el mes siguiente, así que se corrige al
        // último día real del mes destino.
        final mesDestino = DateTime(actual.year, actual.month + 1, 1);
        final ultimoDiaMesDestino =
            DateTime(mesDestino.year, mesDestino.month + 1, 0).day;
        final dia = actual.day > ultimoDiaMesDestino ? ultimoDiaMesDestino : actual.day;
        return DateTime(
          mesDestino.year, mesDestino.month, dia, actual.hour, actual.minute,
        );
      default:
        return null;
    }
  }

  /// Si la tarea que se acaba de completar es recurrente, crea la
  /// siguiente ocurrencia y le programa su recordatorio.
  /// Devuelve true si creó una tarea nueva.
  static Future<bool> generarSiguienteSiAplica(Map<String, dynamic> tarea) async {
    final recurrencia = tarea['recurrencia'] as String? ?? 'ninguna';
    if (recurrencia == 'ninguna') return false;

    final fechaActual = DateTime.parse(tarea['fecha_limite']);
    final siguiente = proximaFecha(fechaActual, recurrencia);
    if (siguiente == null) return false;

    try {
      final userId = supabase.auth.currentUser!.id;
      // La serie apunta siempre a la tarea original; si esta ya venía de
      // una serie, se conserva la misma raíz.
      final serieId = tarea['serie_id'] ?? tarea['id'];

      final nueva = await supabase
          .from('tareas')
          .insert({
            'usuario_id': userId,
            'titulo': tarea['titulo'],
            'descripcion': tarea['descripcion'],
            'fecha_limite': siguiente.toIso8601String(),
            'prioridad': tarea['prioridad'],
            'estado': 'pendiente',
            'recurrencia': recurrencia,
            'serie_id': serieId,
          })
          .select('id')
          .single();

      await NotificationService.programarRecordatorioTarea(
        tareaId: nueva['id'],
        titulo: tarea['titulo'],
        fechaLimite: siguiente,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
