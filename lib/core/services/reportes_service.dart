import '../supabase/supabase_config.dart';

enum PeriodoReporte { hoy, semana, mes }

class ReporteData {
  final double ingresos;
  final double gastos;
  final double ingresosAnterior;
  final double gastosAnterior;
  final double productividad; // 0-100
  final int tareasCompletadas;
  final int tareasTotales;
  final int tareasVencidas;
  final String? tareaMasVencidaTitulo;
  final double gastoPromedioDiario;
  final String? categoriaTop;

  final List<String> etiquetasSerie; // L,M,X... o Sem1,Sem2...
  final List<double> ingresosPorSerie;
  final List<double> gastosPorSerie;
  final List<double> balanceAcumulado;

  final List<MapEntry<String, double>> gastosPorCategoria;

  // prioridad -> (completadas, totales)
  final Map<String, (int, int)> cumplimientoPorPrioridad;

  // día del mes -> nivel de actividad (0-4), solo para vista Mes
  final Map<int, int> mapaCalor;

  final List<Map<String, dynamic>> presupuestos; // {nombre, limite, gastado}
  final List<Map<String, dynamic>> metas; // {nombre, objetivo, actual}

  final List<Map<String, dynamic>> movimientosDeHoy;
  final List<Map<String, dynamic>> tareasDeHoy;

  final List<String> conclusiones;

  const ReporteData({
    required this.ingresos,
    required this.gastos,
    required this.ingresosAnterior,
    required this.gastosAnterior,
    required this.productividad,
    required this.tareasCompletadas,
    required this.tareasTotales,
    required this.tareasVencidas,
    required this.tareaMasVencidaTitulo,
    required this.gastoPromedioDiario,
    required this.categoriaTop,
    required this.etiquetasSerie,
    required this.ingresosPorSerie,
    required this.gastosPorSerie,
    required this.balanceAcumulado,
    required this.gastosPorCategoria,
    required this.cumplimientoPorPrioridad,
    required this.mapaCalor,
    required this.presupuestos,
    required this.metas,
    required this.movimientosDeHoy,
    required this.tareasDeHoy,
    required this.conclusiones,
  });

  double? get variacionIngresos =>
      ingresosAnterior == 0 ? null : ((ingresos - ingresosAnterior) / ingresosAnterior) * 100;
  double? get variacionGastos =>
      gastosAnterior == 0 ? null : ((gastos - gastosAnterior) / gastosAnterior) * 100;
}

class ReportesService {
  static DateTime _inicioDelDia(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _lunesDeLaSemana(DateTime d) =>
      _inicioDelDia(d).subtract(Duration(days: d.weekday - 1));

  static DateTime _primerDiaDelMes(DateTime d) => DateTime(d.year, d.month, 1);

  static Future<ReporteData> cargar(PeriodoReporte periodo) async {
    final userId = supabase.auth.currentUser!.id;
    final hoy = DateTime.now();

    late DateTime inicioActual;
    late DateTime inicioAnterior;
    late DateTime finAnterior;

    switch (periodo) {
      case PeriodoReporte.hoy:
        inicioActual = _inicioDelDia(hoy);
        inicioAnterior = inicioActual.subtract(const Duration(days: 1));
        finAnterior = inicioActual;
        break;
      case PeriodoReporte.semana:
        inicioActual = _lunesDeLaSemana(hoy);
        inicioAnterior = inicioActual.subtract(const Duration(days: 7));
        finAnterior = inicioActual;
        break;
      case PeriodoReporte.mes:
        inicioActual = _primerDiaDelMes(hoy);
        inicioAnterior = DateTime(hoy.year, hoy.month - 1, 1);
        finAnterior = inicioActual;
        break;
    }

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Traemos movimientos desde el inicio del periodo ANTERIOR hasta hoy,
    // así con una sola consulta cubrimos actual + anterior para comparar.
    final movimientos = await supabase
        .from('movimientos')
        .select('tipo, monto, fecha, categorias(nombre)')
        .eq('usuario_id', userId)
        .gte('fecha', fmt(inicioAnterior));

    double ingActual = 0, gasActual = 0, ingAnterior = 0, gasAnterior = 0;
    final categorias = <String, double>{};
    final movimientosHoy = <Map<String, dynamic>>[];

    // Series por día (para línea de tendencia y mapa de calor)
    final gastosPorDiaDelMes = <int, double>{};
    final actividadPorDia = <int, int>{};

    for (final m in movimientos as List) {
      final fecha = DateTime.parse(m['fecha']);
      final monto = (m['monto'] as num).toDouble();
      final esIngreso = m['tipo'] == 'ingreso';
      final enPeriodoActual = !fecha.isBefore(inicioActual);

      if (fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day) {
        movimientosHoy.add(Map<String, dynamic>.from(m));
      }

      if (fecha.month == hoy.month && fecha.year == hoy.year) {
        actividadPorDia[fecha.day] = (actividadPorDia[fecha.day] ?? 0) + 1;
        if (!esIngreso) {
          gastosPorDiaDelMes[fecha.day] = (gastosPorDiaDelMes[fecha.day] ?? 0) + monto;
        }
      }

      if (enPeriodoActual) {
        if (esIngreso) {
          ingActual += monto;
        } else {
          gasActual += monto;
          final cat = m['categorias']?['nombre'] ?? 'Otros';
          categorias[cat] = (categorias[cat] ?? 0) + monto;
        }
      } else if (!fecha.isBefore(inicioAnterior) && fecha.isBefore(finAnterior)) {
        if (esIngreso) {
          ingAnterior += monto;
        } else {
          gasAnterior += monto;
        }
      }
    }

    // Series de barras + balance acumulado, según granularidad del periodo
    List<String> etiquetas;
    List<double> ingresosSerie;
    List<double> gastosSerie;
    List<double> balanceAcumulado;

    if (periodo == PeriodoReporte.semana) {
      etiquetas = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
      ingresosSerie = List.filled(7, 0);
      gastosSerie = List.filled(7, 0);
      for (final m in movimientos as List) {
        final fecha = DateTime.parse(m['fecha']);
        if (fecha.isBefore(inicioActual)) continue;
        final i = fecha.weekday - 1;
        if (i < 0 || i > 6) continue;
        final monto = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'ingreso') {
          ingresosSerie[i] += monto;
        } else {
          gastosSerie[i] += monto;
        }
      }
      balanceAcumulado = [];
      double acum = 0;
      for (var i = 0; i < 7; i++) {
        acum += ingresosSerie[i] - gastosSerie[i];
        balanceAcumulado.add(acum);
      }
    } else if (periodo == PeriodoReporte.mes) {
      etiquetas = ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4', 'Sem 5'];
      ingresosSerie = List.filled(5, 0);
      gastosSerie = List.filled(5, 0);
      for (final m in movimientos as List) {
        final fecha = DateTime.parse(m['fecha']);
        if (fecha.isBefore(inicioActual)) continue;
        final semanaIndex = ((fecha.day - 1) / 7).floor().clamp(0, 4);
        final monto = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'ingreso') {
          ingresosSerie[semanaIndex] += monto;
        } else {
          gastosSerie[semanaIndex] += monto;
        }
      }
      balanceAcumulado = [];
      double acum = 0;
      for (var i = 0; i < 5; i++) {
        acum += ingresosSerie[i] - gastosSerie[i];
        balanceAcumulado.add(acum);
      }
    } else {
      etiquetas = [];
      ingresosSerie = [];
      gastosSerie = [];
      balanceAcumulado = [];
    }

    final categoriasOrdenadas = categorias.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Tareas del periodo (creadas dentro del rango, para cumplimiento)
    final tareas = await supabase
        .from('tareas')
        .select('estado, prioridad, fecha_limite, titulo, creado_en')
        .eq('usuario_id', userId)
        .gte('creado_en', inicioActual.toIso8601String());

    int completadas = 0;
    final porPrioridad = <String, (int, int)>{
      'alta': (0, 0),
      'media': (0, 0),
      'baja': (0, 0),
    };
    var tareasVencidas = 0;
    String? tareaMasVencidaTitulo;
    DateTime? fechaMasVencida;

    for (final t in tareas as List) {
      final prioridad = t['prioridad'] as String;
      final estado = t['estado'] as String;
      final esCompletada = estado == 'completada';
      if (esCompletada) completadas++;

      final actual = porPrioridad[prioridad] ?? (0, 0);
      porPrioridad[prioridad] = (actual.$1 + (esCompletada ? 1 : 0), actual.$2 + 1);

      if (estado == 'pendiente') {
        final limite = DateTime.parse(t['fecha_limite']);
        if (limite.isBefore(hoy)) {
          tareasVencidas++;
          if (fechaMasVencida == null || limite.isBefore(fechaMasVencida)) {
            fechaMasVencida = limite;
            tareaMasVencidaTitulo = t['titulo'];
          }
        }
      }

      if (t['creado_en'] != null) {
        final creado = DateTime.parse(t['creado_en']).toLocal();
        if (creado.month == hoy.month && creado.year == hoy.year) {
          actividadPorDia[creado.day] = (actividadPorDia[creado.day] ?? 0) + 1;
        }
      }
    }

    // Tareas de hoy (por fecha_limite = hoy)
    final tareasHoy = (tareas as List).where((t) {
      final limite = DateTime.parse(t['fecha_limite']);
      return limite.year == hoy.year && limite.month == hoy.month && limite.day == hoy.day;
    }).map((t) => Map<String, dynamic>.from(t)).toList();

    // Mapa de calor: normaliza el conteo de actividad a niveles 0-4
    final maxActividad =
        actividadPorDia.values.isEmpty ? 1 : actividadPorDia.values.reduce((a, b) => a > b ? a : b);
    final mapaCalor = <int, int>{};
    actividadPorDia.forEach((dia, conteo) {
      final nivel = maxActividad == 0 ? 0 : ((conteo / maxActividad) * 4).ceil().clamp(0, 4);
      mapaCalor[dia] = nivel;
    });

    // Presupuestos activos con su consumo
    final presupuestosRaw = await supabase
        .from('presupuestos')
        .select('id, monto_limite, categoria_id, fecha_inicio, fecha_fin, categorias(nombre)')
        .eq('usuario_id', userId)
        .lte('fecha_inicio', fmt(hoy))
        .gte('fecha_fin', fmt(hoy));

    final presupuestos = <Map<String, dynamic>>[];
    for (final p in presupuestosRaw as List) {
      final gastado = categorias[p['categorias']?['nombre']] ?? 0.0;
      presupuestos.add({
        'nombre': p['categorias']?['nombre'] ?? 'General',
        'limite': (p['monto_limite'] as num).toDouble(),
        'gastado': gastado,
      });
    }

    // Metas de ahorro activas
    final metasRaw = await supabase
        .from('metas_ahorro')
        .select('nombre, monto_objetivo, monto_actual')
        .eq('usuario_id', userId)
        .eq('estado', 'activa');

    final metas = (metasRaw as List).map((m) => {
          'nombre': m['nombre'],
          'objetivo': (m['monto_objetivo'] as num).toDouble(),
          'actual': (m['monto_actual'] as num).toDouble(),
        }).toList();

    final dias = hoy.difference(inicioActual).inDays + 1;
    final gastoPromedioDiario = dias == 0 ? gasActual : gasActual / dias;

    // Conclusiones automáticas (reglas locales, no IA generativa todavía)
    final conclusiones = <String>[];
    if (categoriasOrdenadas.isNotEmpty) {
      final top = categoriasOrdenadas.first;
      final pct = gasActual == 0 ? 0 : (top.value / gasActual) * 100;
      conclusiones.add('💸 "${top.key}" es tu categoría con más gasto: ${pct.toStringAsFixed(0)}% del total.');
    }
    final varGastos = gasAnterior == 0 ? null : ((gasActual - gasAnterior) / gasAnterior) * 100;
    if (varGastos != null) {
      final subio = varGastos >= 0;
      conclusiones.add(
        '${subio ? '⚠️' : '✅'} Gastaste ${varGastos.abs().toStringAsFixed(0)}% ${subio ? 'más' : 'menos'} que el periodo anterior.',
      );
    }
    if (tareasVencidas > 0) {
      conclusiones.add('⏰ Tienes $tareasVencidas tarea(s) vencida(s) sin completar.');
    }
    if (conclusiones.isEmpty) {
      conclusiones.add('📊 Sigue registrando datos para ver conclusiones más precisas.');
    }

    return ReporteData(
      ingresos: ingActual,
      gastos: gasActual,
      ingresosAnterior: ingAnterior,
      gastosAnterior: gasAnterior,
      productividad: tareas.isEmpty ? 0 : (completadas / tareas.length) * 100,
      tareasCompletadas: completadas,
      tareasTotales: tareas.length,
      tareasVencidas: tareasVencidas,
      tareaMasVencidaTitulo: tareaMasVencidaTitulo,
      gastoPromedioDiario: gastoPromedioDiario,
      categoriaTop: categoriasOrdenadas.isNotEmpty ? categoriasOrdenadas.first.key : null,
      etiquetasSerie: etiquetas,
      ingresosPorSerie: ingresosSerie,
      gastosPorSerie: gastosSerie,
      balanceAcumulado: balanceAcumulado,
      gastosPorCategoria: categoriasOrdenadas.take(5).toList(),
      cumplimientoPorPrioridad: porPrioridad,
      mapaCalor: mapaCalor,
      presupuestos: presupuestos,
      metas: metas,
      movimientosDeHoy: movimientosHoy,
      tareasDeHoy: tareasHoy,
      conclusiones: conclusiones,
    );
  }
}
