import '../supabase/supabase_config.dart';

class Logro {
  final String emoji;
  final String titulo;
  final String descripcion;
  final bool desbloqueado;
  final int progreso; // valor actual
  final int meta; // valor necesario para desbloquear

  const Logro({
    required this.emoji,
    required this.titulo,
    required this.descripcion,
    required this.desbloqueado,
    required this.progreso,
    required this.meta,
  });

  double get porcentaje => meta == 0 ? 0 : (progreso / meta).clamp(0.0, 1.0);
}

class EstadisticasGamificacion {
  final int rachaActual; // días seguidos con actividad, hasta hoy
  final int rachaMaxima; // la mejor racha histórica
  final int tareasCompletadas;
  final int movimientosRegistrados;
  final int diasActivos;
  final int aportesAhorro;
  final int metasCompletadas;
  final List<Logro> logros;

  const EstadisticasGamificacion({
    required this.rachaActual,
    required this.rachaMaxima,
    required this.tareasCompletadas,
    required this.movimientosRegistrados,
    required this.diasActivos,
    required this.aportesAhorro,
    required this.metasCompletadas,
    required this.logros,
  });

  int get logrosDesbloqueados => logros.where((l) => l.desbloqueado).length;
}

/// Calcula rachas y logros SIN tablas nuevas: todo se deriva de la
/// actividad que la app ya guarda (tareas, movimientos, aportes, metas).
/// Así no hay que mantener contadores sincronizados que se puedan
/// desfasar si el usuario edita o borra registros.
class GamificacionService {
  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  static Future<EstadisticasGamificacion> cargar() async {
    final userId = supabase.auth.currentUser!.id;

    final tareas = await supabase
        .from('tareas')
        .select('estado, completado_en')
        .eq('usuario_id', userId);

    final movimientos = await supabase
        .from('movimientos')
        .select('creado_en')
        .eq('usuario_id', userId);

    final aportes = await supabase
        .from('aportes_ahorro')
        .select('creado_en')
        .eq('usuario_id', userId);

    final metas = await supabase
        .from('metas_ahorro')
        .select('estado')
        .eq('usuario_id', userId);

    // ---- Días con actividad (cualquier acción cuenta) ----
    final diasConActividad = <DateTime>{};
    var tareasCompletadas = 0;

    for (final t in tareas as List) {
      if (t['estado'] == 'completada' && t['completado_en'] != null) {
        tareasCompletadas++;
        diasConActividad.add(_soloFecha(DateTime.parse(t['completado_en']).toLocal()));
      }
    }
    for (final m in movimientos as List) {
      diasConActividad.add(_soloFecha(DateTime.parse(m['creado_en']).toLocal()));
    }
    for (final a in aportes as List) {
      diasConActividad.add(_soloFecha(DateTime.parse(a['creado_en']).toLocal()));
    }

    final metasCompletadas =
        (metas as List).where((m) => m['estado'] == 'completada').length;

    final (rachaActual, rachaMaxima) = _calcularRachas(diasConActividad);

    final movimientosCount = movimientos.length;
    final aportesCount = aportes.length;
    final diasActivos = diasConActividad.length;

    final logros = _construirLogros(
      rachaMaxima: rachaMaxima,
      tareasCompletadas: tareasCompletadas,
      movimientos: movimientosCount,
      diasActivos: diasActivos,
      aportes: aportesCount,
      metasCompletadas: metasCompletadas,
    );

    return EstadisticasGamificacion(
      rachaActual: rachaActual,
      rachaMaxima: rachaMaxima,
      tareasCompletadas: tareasCompletadas,
      movimientosRegistrados: movimientosCount,
      diasActivos: diasActivos,
      aportesAhorro: aportesCount,
      metasCompletadas: metasCompletadas,
      logros: logros,
    );
  }

  /// Devuelve (racha actual, racha máxima) en días consecutivos.
  /// La racha actual sigue viva si hubo actividad hoy o ayer — así no se
  /// "rompe" injustamente por consultar la app temprano en la mañana.
  static (int, int) _calcularRachas(Set<DateTime> dias) {
    if (dias.isEmpty) return (0, 0);

    final ordenados = dias.toList()..sort();

    var maxima = 1;
    var consecutivos = 1;
    for (var i = 1; i < ordenados.length; i++) {
      final diferencia = ordenados[i].difference(ordenados[i - 1]).inDays;
      if (diferencia == 1) {
        consecutivos++;
        if (consecutivos > maxima) maxima = consecutivos;
      } else {
        consecutivos = 1;
      }
    }

    // Racha actual: se cuenta hacia atrás desde el último día activo,
    // siempre que ese día sea hoy o ayer.
    final hoy = _soloFecha(DateTime.now());
    final ultimo = ordenados.last;
    final distanciaAHoy = hoy.difference(ultimo).inDays;
    if (distanciaAHoy > 1) return (0, maxima);

    var actual = 1;
    for (var i = ordenados.length - 1; i > 0; i--) {
      if (ordenados[i].difference(ordenados[i - 1]).inDays == 1) {
        actual++;
      } else {
        break;
      }
    }
    return (actual, maxima);
  }

  static List<Logro> _construirLogros({
    required int rachaMaxima,
    required int tareasCompletadas,
    required int movimientos,
    required int diasActivos,
    required int aportes,
    required int metasCompletadas,
  }) {
    Logro crear(String emoji, String titulo, String descripcion, int progreso, int meta) {
      return Logro(
        emoji: emoji,
        titulo: titulo,
        descripcion: descripcion,
        desbloqueado: progreso >= meta,
        progreso: progreso > meta ? meta : progreso,
        meta: meta,
      );
    }

    return [
      crear('🌱', 'Primer paso', 'Completa tu primera tarea', tareasCompletadas, 1),
      crear('✅', 'En marcha', 'Completa 10 tareas', tareasCompletadas, 10),
      crear('🏆', 'Imparable', 'Completa 50 tareas', tareasCompletadas, 50),
      crear('💸', 'Contador', 'Registra tu primer movimiento', movimientos, 1),
      crear('📒', 'Ordenado', 'Registra 25 movimientos', movimientos, 25),
      crear('🔥', 'Racha de 3', 'Usa la app 3 días seguidos', rachaMaxima, 3),
      crear('⚡', 'Racha de 7', 'Usa la app 7 días seguidos', rachaMaxima, 7),
      crear('👑', 'Racha de 30', 'Usa la app 30 días seguidos', rachaMaxima, 30),
      crear('🐷', 'Ahorrador', 'Haz tu primer aporte a una meta', aportes, 1),
      crear('🎯', 'Meta cumplida', 'Completa una meta de ahorro', metasCompletadas, 1),
      crear('📅', 'Constante', 'Ten actividad en 30 días distintos', diasActivos, 30),
    ];
  }
}
