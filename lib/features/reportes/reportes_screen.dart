import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/reportes_service.dart';
import 'exportar_datos_screen.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  PeriodoReporte _periodo = PeriodoReporte.semana;
  ReporteData? _datos;
  bool _cargando = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final datos = await ReportesService.cargar(
        _periodo,
        english: Localizations.localeOf(context).languageCode == 'en',
      );
      if (mounted) {
        setState(() {
          _datos = datos;
          _errorCarga = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorCarga = appText(
            context,
            'No se pudo actualizar el reporte: $error',
            'Could not update the report: $error',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarPeriodo(PeriodoReporte p) {
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
          if (datos != null) ...[
            const SizedBox(height: 16),
            _tarjetaComparativa(datos),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportarDatosScreen()),
              ),
              icon: const Icon(Icons.ios_share),
              label: Text(appText(context, 'Exportar', 'Export')),
            ),
          ),
          if (_errorCarga != null && datos != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.redChipBg,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(_errorCarga!)),
                      TextButton(
                        onPressed: _cargar,
                        child: Text(appText(context, 'Reintentar', 'Retry')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (_cargando || datos == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: _errorCarga == null
                    ? CircularProgressIndicator(color: AppColors.gold)
                    : Column(
                        children: [
                          Text(_errorCarga!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _cargar,
                            child: Text(appText(context, 'Reintentar', 'Retry')),
                          ),
                        ],
                      ),
              ),
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

  Widget _tarjetaComparativa(ReporteData d) {
    final variacionIngresos = d.variacionIngresos;
    final variacionGastos = d.variacionGastos;
    final tieneIngreso = variacionIngresos != null;
    final tieneGasto = variacionGastos != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appText(context, 'COMPARATIVO', 'COMPARISON'), style: AppTypography.sectionLabel),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _chipComparativo(
                  titulo: appText(context, 'Ingresos', 'Income'),
                  valor: tieneIngreso
                      ? '${variacionIngresos.toStringAsFixed(0)}%'
                      : appText(context, 'Sin dato', 'No data'),
                  color: variacionIngresos != null && variacionIngresos >= 0
                      ? AppColors.green
                      : AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _chipComparativo(
                  titulo: appText(context, 'Gastos', 'Expenses'),
                  valor: tieneGasto
                      ? '${variacionGastos.toStringAsFixed(0)}%'
                      : appText(context, 'Sin dato', 'No data'),
                  color: variacionGastos != null && variacionGastos <= 0
                      ? AppColors.green
                      : AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipComparativo({
    required String titulo,
    required String valor,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldSoftBg,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: AppTypography.secondary.copyWith(fontSize: 10.5)),
          const SizedBox(height: 6),
          Text(
            valor,
            style: AppTypography.itemTitle.copyWith(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------- Selector de periodo ----------
  Widget _selectorPeriodo() {
    Widget boton(String texto, PeriodoReporte valor) {
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
              border: Border.all(
                color: activo ? AppColors.gold : AppColors.borderSoft,
              ),
            ),
            child: Column(
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    color: activo ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        boton(appText(context, 'Hoy', 'Today'), PeriodoReporte.hoy),
        boton(appText(context, 'Semana', 'Week'), PeriodoReporte.semana),
        boton(
          appText(context, 'Mes', 'Month'),
          PeriodoReporte.mes,
        ),
      ],
    );
  }

  // ---------- Vista "Hoy" (sin gráfica por hora: no guardamos hora en movimientos) ----------
  List<Widget> _contenidoHoy(ReporteData d, ReportesTheme tema) {
    return [
      Row(
        children: [
          Expanded(
            child: _kpi(
              appText(context, 'Ingresos hoy', 'Income today'),
              formatearMonto(d.ingresos),
              AppColors.green,
              tema.kpiIngresoBg,
              tema.kpiIngresoBorder,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _kpi(
              appText(context, 'Gastos hoy', 'Expenses today'),
              formatearMonto(d.gastos),
              AppColors.red,
              tema.kpiGastoBg,
              tema.kpiGastoBorder,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(appText(context, 'MOVIMIENTOS DE HOY', 'TODAY’S TRANSACTIONS'), style: AppTypography.sectionLabel),
      const SizedBox(height: 10),
      if (d.movimientosDeHoy.isEmpty)
        _tarjeta(
          child: Text(
            appText(context, 'Aún no registras movimientos hoy.', 'You have no transactions today yet.'),
            style: AppTypography.secondary,
          ),
        )
      else
        _tarjeta(
          child: Column(
            children: d.movimientosDeHoy.map((m) {
              final esIngreso = m['tipo'] == 'ingreso';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                      size: 15,
                      color: esIngreso ? AppColors.green : AppColors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m['categorias']?['nombre'] ?? 'Movimiento',
                        style: AppTypography.itemTitle,
                      ),
                    ),
                    Text(
                      '${esIngreso ? '+' : '-'}${formatearMonto(m['monto'])}',
                      style: TextStyle(
                        color: esIngreso ? AppColors.green : AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      const SizedBox(height: 20),
      Text(appText(context, 'TAREAS DE HOY', 'TODAY’S TASKS'), style: AppTypography.sectionLabel),
      const SizedBox(height: 10),
      if (d.tareasDeHoy.isEmpty)
        _tarjeta(
          child: Text(
            appText(context, 'No tienes tareas programadas para hoy.', 'You have no tasks scheduled for today.'),
            style: AppTypography.secondary,
          ),
        )
      else
        _tarjeta(
          child: Column(
            children: d.tareasDeHoy.map((t) {
              final completada = t['estado'] == 'completada';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      completada
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: completada
                          ? AppColors.green
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t['titulo'], style: AppTypography.itemTitle),
                    ),
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

      Text(appText(context, 'INGRESOS VS GASTOS', 'INCOME VS EXPENSES'), style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(child: _graficaBarras(d)),
      const SizedBox(height: 24),

      Text(appText(context, 'TENDENCIA DEL BALANCE', 'BALANCE TREND'), style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(child: _graficaLinea(d)),
      const SizedBox(height: 24),

      if (d.gastosPorCategoria.isNotEmpty) ...[
        Text(appText(context, 'GASTOS POR CATEGORÍA', 'EXPENSES BY CATEGORY'), style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: _graficaDona(d, tema)),
        const SizedBox(height: 24),
      ],

      Text(
        appText(context, 'CUMPLIMIENTO DE TAREAS POR PRIORIDAD', 'TASK COMPLETION BY PRIORITY'),
        style: AppTypography.sectionLabel,
      ),
      const SizedBox(height: 12),
      _tarjeta(child: _barrasCumplimiento(d, tema)),
      const SizedBox(height: 24),

      if (_periodo == PeriodoReporte.mes) ...[
        Text(appText(context, 'MAPA DE CALOR DE ACTIVIDAD', 'ACTIVITY HEATMAP'), style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(child: _mapaCalor(d)),
        const SizedBox(height: 24),
      ],

      if (d.presupuestos.isNotEmpty) ...[
        Text(appText(context, 'PRESUPUESTOS', 'BUDGETS'), style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(
          child: Column(
            children: d.presupuestos
                .map(
                  (p) => _barraProgreso(
                    nombre: p['nombre'],
                    actual: p['gastado'],
                    total: p['limite'],
                    colorNormal: AppColors.green,
                    colorAlerta: AppColors.red,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],

      if (d.metas.isNotEmpty) ...[
        Text(appText(context, 'METAS DE AHORRO', 'SAVINGS GOALS'), style: AppTypography.sectionLabel),
        const SizedBox(height: 12),
        _tarjeta(
          child: Column(
            children: d.metas
                .map(
                  (m) => _barraProgreso(
                    nombre: m['nombre'],
                    actual: m['actual'],
                    total: m['objetivo'],
                    colorNormal: AppColors.gold,
                    colorAlerta: AppColors.gold,
                    invertirAlerta: true,
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],

      Text(appText(context, 'CONCLUSIONES', 'INSIGHTS'), style: AppTypography.sectionLabel),
      const SizedBox(height: 12),
      _tarjeta(
        color: AppColors.goldSoftBg,
        borde: AppColors.goldBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: d.conclusiones
              .map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    c,
                    style: AppTypography.bodyBase.copyWith(fontSize: 13.5),
                  ),
                ),
              )
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
        border: Border.all(
          color: borde ?? AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: child,
    );
  }

  Widget _filaKpisPrincipales(ReporteData d, ReportesTheme tema) {
    return Row(
      children: [
        Expanded(
          child: _kpi(
            appText(context, 'Productividad', 'Productivity'),
            '${d.productividad.toStringAsFixed(0)}%',
            AppColors.goldDeep,
            AppColors.goldChipBg,
            AppColors.goldBorder,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpi(
            appText(context, 'Balance neto', 'Net balance'),
            formatearMonto(d.ingresos - d.gastos),
            AppColors.green,
            tema.kpiIngresoBg,
            tema.kpiIngresoBorder,
          ),
        ),
      ],
    );
  }

  Widget _filaKpisSecundarios(ReporteData d) {
    return Row(
      children: [
        Expanded(
          child: _kpiChico(
            appText(context, 'Gasto prom./día', 'Avg. daily spending'),
            formatearMonto(d.gastoPromedioDiario),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _kpiChico(appText(context, 'Mayor gasto', 'Top expense'), d.categoriaTop ?? '—')),
        const SizedBox(width: 8),
        Expanded(child: _kpiChico(appText(context, 'Vencidas', 'Overdue'), '${d.tareasVencidas}')),
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
          Text(
            valor,
            style: AppTypography.kpiNumber.copyWith(fontSize: 20, color: color),
          ),
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
          Text(
            valor,
            style: AppTypography.itemTitle.copyWith(fontSize: 12.5),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _graficaBarras(ReporteData d) {
    if (d.etiquetasSerie.isEmpty) {
      return Text(
        appText(context, 'Sin datos suficientes para graficar.', 'Not enough data to build this chart.'),
        style: AppTypography.secondary,
      );
    }
    final maxY = [
      ...d.ingresosPorSerie,
      ...d.gastosPorSerie,
    ].fold(0.0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 100 : maxY * 1.2,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    d.etiquetasSerie[value.toInt()],
                    style: AppTypography.secondary.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
          barGroups: List.generate(d.etiquetasSerie.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: d.ingresosPorSerie[i],
                  color: AppColors.green,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: d.gastosPorSerie[i],
                  color: AppColors.red,
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
              barsSpace: 3,
            );
          }),
        ),
      ),
    );
  }

  Widget _graficaLinea(ReporteData d) {
    if (d.balanceAcumulado.isEmpty) {
      return Text(
        appText(context, 'Sin datos suficientes para graficar.', 'Not enough data to build this chart.'),
        style: AppTypography.secondary,
      );
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
              spots: List.generate(
                d.balanceAcumulado.length,
                (i) => FlSpot(i.toDouble(), d.balanceAcumulado[i]),
              ),
              isCurved: true,
              color: AppColors.gold,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.goldChipBg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graficaDona(ReporteData d, ReportesTheme tema) {
    final total = d.gastosPorCategoria.fold(0.0, (a, e) => a + e.value);
    final colores = [
      AppColors.gold,
      AppColors.green,
      AppColors.red,
      tema.barraCategoria,
      AppColors.textTertiary,
    ];

    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(
            PieChartData(
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
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colores[i % colores.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: AppTypography.itemTitle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatearMonto(e.value),
                      style: AppTypography.secondary,
                    ),
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
    final coloresPrioridad = {
      'alta': AppColors.red,
      'media': AppColors.amber,
      'baja': AppColors.textTertiary,
    };
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
                  Text(
                    appText(
                      context,
                      switch (p) {
                        'alta' => 'ALTA',
                        'media' => 'MEDIA',
                        _ => 'BAJA',
                      },
                      switch (p) {
                        'alta' => 'HIGH',
                        'media' => 'MEDIUM',
                        _ => 'LOW',
                      },
                    ),
                    style: AppTypography.secondary.copyWith(
                      color: coloresPrioridad[p],
                    ),
                  ),
                  Text(
                    '$completadas / $totales',
                    style: AppTypography.secondary,
                  ),
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: coloresNivel[nivel],
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            '$dia',
            style: TextStyle(
              fontSize: 9,
              color: nivel >= 3 ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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
              Expanded(
                child: Text(
                  nombre,
                  style: AppTypography.itemTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${formatearMonto(actual)} / ${formatearMonto(total)}',
                  style: AppTypography.secondary.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
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
              child: Text(
                appText(context, '⚠️ Superaste el límite de este presupuesto', '⚠️ You exceeded this budget limit'),
                style: TextStyle(color: colorAlerta, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
