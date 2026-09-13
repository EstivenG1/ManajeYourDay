import '../supabase/supabase_config.dart';

enum TipoHistorial { ingreso, gasto, tareaCreada, tareaCompletada, aporte }

class HistorialItem {
  final TipoHistorial tipo;
  final String titulo;
  final String subtitulo;
  final DateTime fecha;

  const HistorialItem({
    required this.tipo,
    required this.titulo,
    required this.subtitulo,
    required this.fecha,
  });
}

enum FiltroHistorial { todo, finanzas, tareas, metas }

class HistorialService {
  static Future<List<HistorialItem>> cargar({required DateTime desde}) async {
    final userId = supabase.auth.currentUser!.id;
    final desdeIso = desde.toIso8601String();
    final items = <HistorialItem>[];

    // ---- Movimientos (ingresos y gastos) ----
    final movimientos = await supabase
        .from('movimientos')
        .select('tipo, monto, descripcion, creado_en, categorias(nombre)')
        .eq('usuario_id', userId)
        .gte('creado_en', desdeIso);

    for (final m in movimientos as List) {
      final esIngreso = m['tipo'] == 'ingreso';
      final categoria = m['categorias']?['nombre'] ?? 'Sin categoría';
      final descripcion = (m['descripcion'] as String?)?.trim();
      items.add(HistorialItem(
        tipo: esIngreso ? TipoHistorial.ingreso : TipoHistorial.gasto,
        titulo: (descripcion != null && descripcion.isNotEmpty) ? descripcion : categoria,
        subtitulo: '${esIngreso ? '+' : '-'}\$${(m['monto'] as num).toStringAsFixed(0)} · $categoria',
        fecha: DateTime.parse(m['creado_en']).toLocal(),
      ));
    }

    // ---- Tareas (creación y finalización) ----
    final tareas = await supabase
        .from('tareas')
        .select('titulo, prioridad, creado_en, completado_en')
        .eq('usuario_id', userId)
        .gte('creado_en', desdeIso);

    for (final t in tareas as List) {
      items.add(HistorialItem(
        tipo: TipoHistorial.tareaCreada,
        titulo: t['titulo'],
        subtitulo: 'Tarea creada · prioridad ${t['prioridad']}',
        fecha: DateTime.parse(t['creado_en']).toLocal(),
      ));
      if (t['completado_en'] != null) {
        final completadoEn = DateTime.parse(t['completado_en']).toLocal();
        if (!completadoEn.isBefore(desde)) {
          items.add(HistorialItem(
            tipo: TipoHistorial.tareaCompletada,
            titulo: t['titulo'],
            subtitulo: 'Tarea completada ✅',
            fecha: completadoEn,
          ));
        }
      }
    }

    // ---- Aportes a metas de ahorro ----
    final aportes = await supabase
        .from('aportes_ahorro')
        .select('monto, nota, creado_en, metas_ahorro(nombre)')
        .eq('usuario_id', userId)
        .gte('creado_en', desdeIso);

    for (final a in aportes as List) {
      final nombreMeta = a['metas_ahorro']?['nombre'] ?? 'Meta de ahorro';
      items.add(HistorialItem(
        tipo: TipoHistorial.aporte,
        titulo: 'Aporte a "$nombreMeta"',
        subtitulo: '+\$${(a['monto'] as num).toStringAsFixed(0)}${a['nota'] != null ? ' · ${a['nota']}' : ''}',
        fecha: DateTime.parse(a['creado_en']).toLocal(),
      ));
    }

    items.sort((a, b) => b.fecha.compareTo(a.fecha));
    return items;
  }

  static bool coincideFiltro(HistorialItem item, FiltroHistorial filtro) {
    switch (filtro) {
      case FiltroHistorial.todo:
        return true;
      case FiltroHistorial.finanzas:
        return item.tipo == TipoHistorial.ingreso || item.tipo == TipoHistorial.gasto;
      case FiltroHistorial.tareas:
        return item.tipo == TipoHistorial.tareaCreada || item.tipo == TipoHistorial.tareaCompletada;
      case FiltroHistorial.metas:
        return item.tipo == TipoHistorial.aporte;
    }
  }
}
