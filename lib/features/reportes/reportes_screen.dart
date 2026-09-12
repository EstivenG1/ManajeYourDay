import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/reportes_service.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  PeriodoReporte _periodo = PeriodoReporte.semana;
  ReporteData? _datos;
  bool _cargando = true;
  bool _esPremium = true; // se ajusta al cargar el perfil

  @override
  void initState() {
    super.initState();
    _cargarPlanYDatos();
  }

  Future<void> _cargarPlanYDatos() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final perfil = await supabase
          .from('perfiles')
          .select('planes(nombre)')
          .eq('id', userId)
          .single();
      final nombrePlan = perfil['planes']?['nombre'] ?? 'Basico';
      _esPremium = nombrePlan != 'Basico';
    } catch (_) {
      _esPremium = true; // si falla, no bloqueamos por error nuestro
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await ReportesService.cargar(_periodo);
      if (mounted) setState(() => _datos = datos);
    } catch (_) {
      // deja _datos como estaba
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarPeriodo(PeriodoReporte p) {
    if (p == PeriodoReporte.mes && !_esPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El reporte mensual es una función Premium ✨')),
      );
      return;
    }
    setState(() => _periodo = p);
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).extension<ReportesTheme>()!;
    final datos = _datos;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _selectorPeriodo(),
          const SizedBox(height: 18),
          if (_cargando || datos == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else ...[
            if (_periodo == PeriodoReporte.hoy)
              ..._contenidoHoy(datos, tema)
            else
              ..._contenidoPeriodo(datos, tema),
          ],
        ],
      ),
    );
  }

  // ---------- Selector de periodo ----------
  Widget _selectorPeriodo() {
    Widget boton(String texto, PeriodoReporte valor, {bool premium = false}) {
      final activo = _periodo == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => _cambiarPeriodo(valor),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: activo ? AppColors.gold : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
              border: Border.all(color: activo ? AppColors.gold : AppColors.borderSoft),
            ),
            child: Column(
              children: [
                Text(texto,
                    style: TextStyle(
                      color: activo ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
                if (premium && !_esPremium)
                  const Text('🔒 Premium', style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        boton('Hoy', PeriodoReporte.hoy),
        boton('Semana', PeriodoReporte.semana),
        boton('Mes', PeriodoReporte.mes, premium: true),
      ],
    );
  }

  // ---------- Vista "Hoy" (sin gráfica por hora: no guardamos hora en movimientos) ----------
  List<Widget> _contenidoHoy(ReporteData d, ReportesTheme tema) {
    return [
      Row(
        children: [
          Expanded(child: _kpi('Ingresos hoy', formatearMonto(d.ingresos), AppColors.green, tema.kpiIngresoBg, tema.kpiIngresoBorder)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Gastos hoy', formatearMonto(d.gastos), AppColors.red, tema.kpiGastoBg, tema.kpiGastoBorder)),
        ],
      ),
      const SizedBox(height: 20),
      Text('MOVIMIENTOS DE HOY', style: AppTypography.sectionLabel),
      const SizedBox(height: 10),
      if (d.movimientosDeHoy.isEmpty)
        _tarjeta(child: Text('Aún no registras movimientos hoy.', style: AppTypography.secondary))
      else
        _tarjeta(
          child: Column(
            children: d.movimientosDeHoy.map((m) {
              final esIngreso = m['tipo'] == 'ingreso';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 15, color: esIngreso ? AppColors.green : AppColors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(m['categorias']?['nombre'] ?? 'Movimiento', style: AppTypography.itemTitle)),
                    Text('${esIngreso ? '+' : '-'}${formatearMonto(m['monto'])}',
                        style: TextStyle(color: esIngreso ? AppColors.green : AppColors.red, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      const SizedBox(height: 20),
      Text('TAREAS DE HOY', style: AppTypography.sectionLabel),
      const SizedBox(height: 10),
      if (d.tareasDeHoy.isEmpty)
        _tarjeta(child: Text('No tienes tareas programadas para hoy.', style: AppTypography.secondary))
      else
        _tarjeta(
          child: Column(
            children: d.tareasDeHoy.map((t) {
              final completada = t['estado'] == 'completada';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(completada ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16, color: completada ? AppColors.green : AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t['titulo'], style: AppTypography.itemTitle)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  // ---------- Vista "Semana" / "Mes" ----------
  List<Widget> _contenidoPeriodo(ReporteData d, ReportesTheme tema) {
    return [
      _filaKpisPrincipales(d, tema),
      const SizedBox(height: 14),
      _filaKpisSecundarios(d),
      const SizedBox(height: 24),

      Text('INGRESOS VS GASTOS', style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(child: _graficaBarras(d)),
      const SizedBox(height: 24),

      Text('TENDENCIA DEL BALANCE', style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(child: _graficaLinea(d)),
      const SizedBox(height: 24),

      if (d.gastosPorCategoria.isNotEmpty) ...[
        Text('GASTOS POR CATEGORÍA', style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: _graficaDona(d, tema)),
        const SizedBox(height: 24),
      ],

      Text('CUMPLIMIENTO DE TAREAS POR PRIORIDAD', style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(child: _barrasCumplimiento(d, tema)),
      const SizedBox(height: 24),

      if (_periodo == PeriodoReporte.mes) ...[
        Text('MAPA DE CALOR DE ACTIVIDAD', style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: _mapaCalor(d)),
        const SizedBox(height: 24),
      ],

      if (d.presupuestos.isNotEmpty) ...[
        Text('PRESUPUESTOS', style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: Column(children: d.presupuestos.map((p) => _barraProgreso(
              nombre: p['nombre'],
              actual: p['gastado'],
              total: p['limite'],
              colorNormal: AppColors.green,
              colorAlerta: AppColors.red,
            )).toList())),
        const SizedBox(height: 24),
      ],

      if (d.metas.isNotEmpty) ...[
        Text('METAS DE AHORRO', style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: Column(children: d.metas.map((m) => _barraProgreso(
              nombre: m['nombre'],
              actual: m['actual'],
              total: m['objetivo'],
              colorNormal: AppColors.gold,
              colorAlerta: AppColors.gold,
              invertirAlerta: true,
            )).toList())),
        const SizedBox(height: 24),
      ],

      Text('CONCLUSIONES', style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(
        color: AppColors.goldSoftBg,
        borde: AppColors.goldBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: d.conclusiones
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(c, style: AppTypography.bodyBase.copyWith(fontSize: 13.5)),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _tarjeta({required Widget child, Color? color, Color? borde}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: borde ?? AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: child,
    );
  }

  Widget _filaKpisPrincipales(ReporteData d, ReportesTheme tema) {
    return Row(
      children: [
        Expanded(child: _kpi('Productividad', '${d.productividad.toStringAsFixed(0)}%', AppColors.goldDeep, AppColors.goldChipBg, AppColors.goldBorder)),
        const SizedBox(width: 10),
        Expanded(child: _kpi('Balance neto', formatearMonto(d.ingresos - d.gastos), AppColors.green, tema.kpiIngresoBg, tema.kpiIngresoBorder)),
      ],
    );
  }

  Widget _filaKpisSecundarios(ReporteData d) {
    return Row(
      children: [
        Expanded(child: _kpiChico('Gasto prom./día', formatearMonto(d.gastoPromedioDiario))),
        const SizedBox(width: 8),
        Expanded(child: _kpiChico('Top gasto', d.categoriaTop ?? '—')),
        const SizedBox(width: 8),
        Expanded(child: _kpiChico('Vencidas', '${d.tareasVencidas}')),
      ],
    );
  }

  Widget _kpi(String label, String valor, Color color, Color bg, Color borde) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.secondary.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(valor, style: AppTypography.kpiNumber.copyWith(fontSize: 20, color: color)),
        ],
      ),
    );
  }

  Widget _kpiChico(String label, String valor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.secondary.copyWith(fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(valor,
              style: AppTypography.itemTitle.copyWith(fontSize: 12.5),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _graficaBarras(ReporteData d) {
    if (d.etiquetasSerie.isEmpty) {
      return Text('Sin datos suficientes para graficar.', style: AppTypography.secondary);
    }
    final maxY = [...d.ingresosPorSerie, ...d.gastosPorSerie].fold(0.0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 100 : maxY * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(d.etiquetasSerie[value.toInt()],
                      style: AppTypography.secondary.copyWith(color: AppColors.textTertiary, fontSize: 10)),
                ),
              ),
            ),
          ),
          barGroups: List.generate(d.etiquetasSerie.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: d.ingresosPorSerie[i], color: AppColors.green, width: 8, borderRadius: BorderRadius.circular(3)),
              BarChartRodData(toY: d.gastosPorSerie[i], color: AppColors.red, width: 8, borderRadius: BorderRadius.circular(3)),
            ], barsSpace: 3);
          }),
        ),
      ),
    );
  }

  Widget _graficaLinea(ReporteData d) {
    if (d.balanceAcumulado.isEmpty) {
      return Text('Sin datos suficientes para graficar.', style: AppTypography.secondary);
    }
    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(d.balanceAcumulado.length, (i) => FlSpot(i.toDouble(), d.balanceAcumulado[i])),
              isCurved: true,
              color: AppColors.gold,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.goldChipBg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graficaDona(ReporteData d, ReportesTheme tema) {
    final total = d.gastosPorCategoria.fold(0.0, (a, e) => a + e.value);
    final colores = [AppColors.gold, AppColors.green, AppColors.red, tema.barraCategoria, AppColors.textTertiary];

    return Row(
      children: [
        SizedBox(
          width: 110, height: 110,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 28,
            sections: List.generate(d.gastosPorCategoria.length, (i) {
              final e = d.gastosPorCategoria[i];
              final pct = total == 0 ? 0 : (e.value / total) * 100;
              return PieChartSectionData(
                value: e.value,
                color: colores[i % colores.length],
                radius: 20,
                title: '${pct.toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
              );
            }),
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(d.gastosPorCategoria.length, (i) {
              final e = d.gastosPorCategoria[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: colores[i % colores.length], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.key, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis)),
                    Text(formatearMonto(e.value), style: AppTypography.secondary),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _barrasCumplimiento(ReporteData d, ReportesTheme tema) {
    final coloresPrioridad = {'alta': AppColors.red, 'media': AppColors.amber, 'baja': AppColors.textTertiary};
    return Column(
      children: ['alta', 'media', 'baja'].map((p) {
        final (completadas, totales) = d.cumplimientoPorPrioridad[p] ?? (0, 0);
        final pct = totales == 0 ? 0.0 : completadas / totales;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.toUpperCase(), style: AppTypography.secondary.copyWith(color: coloresPrioridad[p])),
                  Text('$completadas / $totales', style: AppTypography.secondary),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.full),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.borderSoft,
                  color: coloresPrioridad[p],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _mapaCalor(ReporteData d) {
    final hoy = DateTime.now();
    final diasEnMes = DateTime(hoy.year, hoy.month + 1, 0).day;
    final coloresNivel = [
      AppColors.borderSoft,
      AppColors.goldChipBg,
      AppColors.goldMid,
      AppColors.gold,
      AppColors.goldDeep,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(diasEnMes, (i) {
        final dia = i + 1;
        final nivel = d.mapaCalor[dia] ?? 0;
        return Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: coloresNivel[nivel],
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text('$dia',
              style: TextStyle(
                fontSize: 9,
                color: nivel >= 3 ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              )),
        );
      }),
    );
  }

  Widget _barraProgreso({
    required String nombre,
    required double actual,
    required double total,
    required Color colorNormal,
    required Color colorAlerta,
    bool invertirAlerta = false,
  }) {
    final pct = total == 0 ? 0.0 : (actual / total).clamp(0, 1.5);
    final excedido = !invertirAlerta && pct >= 1.0;
    final color = excedido ? colorAlerta : colorNormal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(nombre, style: AppTypography.itemTitle),
              Text('${formatearMonto(actual)} / ${formatearMonto(total)}',
                  style: AppTypography.secondary.copyWith(fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.full),
            child: LinearProgressIndicator(
              value: pct > 1 ? 1 : pct.toDouble(),
              minHeight: 9,
              backgroundColor: AppColors.borderSoft,
              color: color,
            ),
          ),
          if (excedido)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚠️ Superaste el límite de este presupuesto',
                  style: TextStyle(color: colorAlerta, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
