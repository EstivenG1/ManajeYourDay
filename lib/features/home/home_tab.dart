import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/plan_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/finance_repository.dart';

class HomeTab extends StatefulWidget {
  final String? nombre;
  final VoidCallback onVerTareas;
  final VoidCallback onVerFinanzas;
  final VoidCallback onVerPlanes;
  final int planRefreshToken;

  const HomeTab({
    super.key,
    required this.nombre,
    required this.onVerTareas,
    required this.onVerFinanzas,
    required this.onVerPlanes,
    required this.planRefreshToken,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  bool _cargando = true;
  String? _errorCarga;
  bool _cargandoPlan = true;
  bool _finanzasActivas = true;
  bool _actualizandoPlan = false;
  bool _actualizarPlanPendiente = false;
  bool _sincronizacionPlanPendiente = false;
  PlanTier? _plan;
  PlanSubscriptionDetails? _suscripcion;
  double _ingresosMes = 0;
  double _gastosMes = 0;
  double _gastosMesAnterior = 0;
  double? _porcentajePresupuestoUsado;
  final List<Map<String, dynamic>> _alertasPresupuesto = [];
  double _proyeccionBalanceMes = 0;
  int _totalMovimientos = 0;
  List<Map<String, dynamic>> _tareasPendientes = [];
  int _tareasCompletadasMes = 0;
  int _tareasTotalesMes = 0;
  List<Map<String, dynamic>> _metasActivas = [];
  ResumenSemana _resumenSemana = const ResumenSemana(
    tareasCompletadas: 0,
    tareasTotales: 0,
    ingresos: 0,
    gastos: 0,
    balance: 0,
  );
  ResumenMeta _resumenMetas = const ResumenMeta(
    totalObjetivo: 0,
    totalActual: 0,
    metasActivas: 0,
    porcentajeGeneral: 0,
    nombreMetaMasCercana: 'Sin metas',
    porcentajeMetaMasCercana: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _cargarPlanHome(sincronizar: true);
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planRefreshToken != widget.planRefreshToken) {
      _cargarDatos();
      _cargarPlanHome(sincronizar: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarPlanHome(sincronizar: true);
    }
  }

  Future<void> _cargarPlanHome({required bool sincronizar}) async {
    if (_actualizandoPlan) {
      _actualizarPlanPendiente = true;
      _sincronizacionPlanPendiente =
          _sincronizacionPlanPendiente || sincronizar;
      return;
    }
    _actualizandoPlan = true;
    try {
      if (sincronizar) {
        try {
          await PlanService.syncCurrentUserSubscription();
        } catch (error) {
          debugPrint('Unable to sync subscription from home: $error');
        }
      }
      final plan = await PlanService.loadCurrentUserPlan();
      final subscription = await PlanService.loadCurrentUserSubscription();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _suscripcion = subscription;
        _cargandoPlan = false;
      });
    } catch (error) {
      debugPrint('Unable to load current plan on home: $error');
      if (mounted) setState(() => _cargandoPlan = false);
    } finally {
      _actualizandoPlan = false;
      if (_actualizarPlanPendiente && mounted) {
        final sincronizar = _sincronizacionPlanPendiente;
        _actualizarPlanPendiente = false;
        _sincronizacionPlanPendiente = false;
        _cargarPlanHome(sincronizar: sincronizar);
      }
    }
  }

  Future<void> _actualizarInicio() async {
    await Future.wait([_cargarDatos(), _cargarPlanHome(sincronizar: true)]);
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final perfil = await supabase
          .from('perfiles')
          .select('finanzas_activas')
          .eq('id', userId)
          .single();
      final finanzasActivas = perfil['finanzas_activas'] == true;
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final inicioMesAnterior = DateTime(ahora.year, ahora.month - 1, 1);
      final movimientos = <Map<String, dynamic>>[];
      const tamanoPagina = 500;
      if (finanzasActivas) {
        for (var inicio = 0; ; inicio += tamanoPagina) {
          final pagina = await supabase
              .from('movimientos')
              .select('tipo, monto, fecha')
              .eq('usuario_id', userId)
              .gte(
                'fecha',
                '${inicioMesAnterior.year}-${inicioMesAnterior.month.toString().padLeft(2, '0')}-01',
              )
              .lte('fecha', _fechaTexto(ahora))
              .order('id')
              .range(inicio, inicio + tamanoPagina - 1);
          movimientos.addAll(List<Map<String, dynamic>>.from(pagina));
          if (pagina.length < tamanoPagina) break;
        }
      }

      double ingresos = 0;
      double gastos = 0;
      double gastosAnteriores = 0;
      var movimientosMes = 0;
      final inicioMesTexto =
          '${inicioMes.year}-${inicioMes.month.toString().padLeft(2, '0')}-01';
      for (final m in movimientos) {
        final monto = (m['monto'] as num).toDouble();
        final estaEnEsteMes =
            (m['fecha'] as String).compareTo(inicioMesTexto) >= 0;
        if (estaEnEsteMes) movimientosMes++;
        if (m['tipo'] == 'ingreso' && estaEnEsteMes) {
          ingresos += monto;
        } else if (m['tipo'] == 'gasto' && estaEnEsteMes) {
          gastos += monto;
        } else if (m['tipo'] == 'gasto') {
          gastosAnteriores += monto;
        }
      }

      final presupuestos = finanzasActivas
          ? await supabase
                .from('presupuestos')
                .select(
                  'id, monto_limite, categoria_id, fecha_inicio, fecha_fin, categorias(nombre)',
                )
                .eq('usuario_id', userId)
                .lte('fecha_inicio', _fechaTexto(ahora))
                .gte('fecha_fin', _fechaTexto(ahora))
          : <Map<String, dynamic>>[];
      final gastosPorPresupuesto = finanzasActivas
          ? await FinanceRepository(supabase).loadBudgetSpending()
          : <String, double>{};
      var totalLimites = 0.0;
      var totalGastadoPresupuestos = 0.0;
      final alertasPresupuesto = <Map<String, dynamic>>[];
      for (final presupuesto in presupuestos as List) {
        totalLimites += (presupuesto['monto_limite'] as num).toDouble();
        final totalCategoria =
            gastosPorPresupuesto[presupuesto['id'].toString()] ?? 0;
        totalGastadoPresupuestos += totalCategoria;
        final limite = (presupuesto['monto_limite'] as num).toDouble();
        final porcentajeCategoria = totalCategoria / limite * 100;
        if (porcentajeCategoria >= 75) {
          alertasPresupuesto.add({
            'nombre': presupuesto['categorias']?['nombre'] ?? 'Categoría',
            'porcentaje': porcentajeCategoria,
          });
        }
      }
      alertasPresupuesto.sort(
        (a, b) =>
            (b['porcentaje'] as double).compareTo(a['porcentaje'] as double),
      );
      final diasMes = DateTime(ahora.year, ahora.month + 1, 0).day;
      final gastosProyectados = gastos * diasMes / ahora.day;

      final tareasPend = await supabase
          .from('tareas')
          .select()
          .eq('usuario_id', userId)
          .eq('estado', 'pendiente')
          .order('fecha_limite', ascending: true)
          .limit(5);

      final metasActivas = finanzasActivas
          ? await supabase
                .from('metas_ahorro')
                .select('nombre, monto_objetivo, monto_actual, estado')
                .eq('usuario_id', userId)
                .eq('estado', 'activa')
          : <Map<String, dynamic>>[];
      final resumenMetas = calcularResumenMetas(
        List<Map<String, dynamic>>.from(metasActivas),
      );

      final tareasMes = await supabase
          .from('tareas')
          .select('estado')
          .eq('usuario_id', userId)
          .gte('creado_en', inicioMes.toIso8601String());

      final semanaInicio = DateTime(
        ahora.year,
        ahora.month,
        ahora.day - (ahora.weekday - 1),
      );
      final semanaFin = semanaInicio.add(const Duration(days: 6));
      final tareasSemana = await supabase
          .from('tareas')
          .select('estado, fecha_limite')
          .eq('usuario_id', userId)
          .gte('fecha_limite', semanaInicio.toIso8601String())
          .lte('fecha_limite', semanaFin.toIso8601String());

      final completadas = (tareasMes as List)
          .where((t) => t['estado'] == 'completada')
          .length;
      final resumenSemana = calcularResumenSemana(
        movimientos: List<Map<String, dynamic>>.from(movimientos),
        tareas: List<Map<String, dynamic>>.from(tareasSemana),
      );

      if (!mounted) return;
      setState(() {
        _finanzasActivas = finanzasActivas;
        _ingresosMes = ingresos;
        _gastosMes = gastos;
        _gastosMesAnterior = gastosAnteriores;
        _porcentajePresupuestoUsado = totalLimites <= 0
            ? null
            : totalGastadoPresupuestos / totalLimites * 100;
        _alertasPresupuesto
          ..clear()
          ..addAll(alertasPresupuesto.take(3));
        _proyeccionBalanceMes = ingresos - gastosProyectados;
        _totalMovimientos = movimientosMes;
        _tareasPendientes = List<Map<String, dynamic>>.from(tareasPend);
        _tareasCompletadasMes = completadas;
        _tareasTotalesMes = tareasMes.length;
        _metasActivas = List<Map<String, dynamic>>.from(metasActivas);
        _resumenMetas = resumenMetas;
        _resumenSemana = resumenSemana;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudieron cargar los datos del inicio: $error';
        });
      }
    }
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Widget _botonAccionInicio({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorCarga!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cargarDatos,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final hoy = formatearFechaEs(DateTime.now());
    final consejos = generarRecomendacionesLocales(
      ingresosMes: _ingresosMes,
      gastosMes: _gastosMes,
      tareasPendientes: _tareasPendientes.length,
      tareasCompletadas: _tareasCompletadasMes,
      tareasTotales: _tareasTotalesMes,
      gastosMesAnterior: _gastosMesAnterior,
      porcentajePresupuestoUsado: _porcentajePresupuestoUsado,
    );
    final balanceMes = _ingresosMes - _gastosMes;
    final productividad = calcularIndiceProductividad(
      completadas: _tareasCompletadasMes,
      totales: _tareasTotalesMes,
    );

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _actualizarInicio,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(hoy, style: AppTypography.secondary),
          const SizedBox(height: 4),
          Text(
            appText(
              context,
              '¡Hola, ${widget.nombre ?? "de nuevo"}! 👋',
              'Hello, ${widget.nombre ?? "again"}! 👋',
            ),
            style: AppTypography.greeting,
          ),
          const SizedBox(height: 10),
          _insigniaPlan(),
          const SizedBox(height: 18),
          if (_suscripcion != null &&
              (_suscripcion!.isCheckoutPending ||
                  _suscripcion!.isPaymentPending)) ...[
            _tarjetaCompraPendiente(_suscripcion!),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final botonFinanzas = _botonAccionInicio(
                icon: _finanzasActivas
                    ? Icons.add_card_rounded
                    : Icons.account_balance_wallet_outlined,
                label: _finanzasActivas
                    ? appText(
                        context,
                        'Registrar movimiento',
                        'Add transaction',
                      )
                    : appText(context, 'Explorar Finanzas', 'Explore Finance'),
                onPressed: widget.onVerFinanzas,
              );
              final botonTarea = _botonAccionInicio(
                icon: Icons.add_task_rounded,
                label: appText(context, 'Nueva tarea', 'New task'),
                onPressed: widget.onVerTareas,
              );
              if (constraints.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    botonFinanzas,
                    const SizedBox(height: 10),
                    botonTarea,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: botonFinanzas),
                  const SizedBox(width: 12),
                  Expanded(child: botonTarea),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          if (_finanzasActivas) ...[
            _tarjetaBalance(),
            const SizedBox(height: 18),
            _tarjetaProyeccion(),
            const SizedBox(height: 18),
            _resumenMetasCard(),
            const SizedBox(height: 18),
            _resumenSemanaCard(),
            const SizedBox(height: 18),
            if (_alertasPresupuesto.isNotEmpty ||
                _porcentajePresupuestoUsado != null) ...[
              _alertaPresupuesto(),
              const SizedBox(height: 18),
            ],
          ] else ...[
            _tarjetaFinanzasInactivas(),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: _chipResumen(
                  titulo: appText(context, 'Productividad', 'Productivity'),
                  valor: '${productividad.toStringAsFixed(0)}%',
                  color: AppColors.goldDeep,
                  fondo: AppColors.goldSoftBg,
                  borde: AppColors.goldBorder,
                ),
              ),
              const SizedBox(width: 10),
              if (_finanzasActivas)
                Expanded(
                  child: _chipResumen(
                    titulo: appText(context, 'Balance', 'Balance'),
                    valor: formatearMonto(balanceMes),
                    color: balanceMes >= 0 ? AppColors.green : AppColors.red,
                    fondo: balanceMes >= 0
                        ? AppColors.greenChipBg
                        : AppColors.redChipBg,
                    borde: balanceMes >= 0
                        ? AppColors.greenChipBorder
                        : AppColors.redChipBorder,
                  ),
                ),
            ],
          ),

          if (_tareasPendientes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _seccionTareasPendientes(),
          ] else ...[
            const SizedBox(height: 20),
            _seccionSinTareas(),
          ],

          const SizedBox(height: 20),
          _seccionRecomendaciones(consejos),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _insigniaPlan() {
    final plan = _plan;
    final color = switch (plan) {
      PlanTier.free => AppColors.green,
      PlanTier.standard => AppColors.goldDeep,
      PlanTier.premium => const Color(0xFF7C3AED),
      null => AppColors.textSecondary,
    };
    final background = switch (plan) {
      PlanTier.free => AppColors.greenChipBg,
      PlanTier.standard => AppColors.goldChipBg,
      PlanTier.premium => const Color(0xFFF3E8FF),
      null => AppColors.surface,
    };
    final border = switch (plan) {
      PlanTier.free => AppColors.greenChipBorder,
      PlanTier.standard => AppColors.goldBorder,
      PlanTier.premium => const Color(0xFFDDD6FE),
      null => AppColors.borderSoft,
    };
    final planName = switch (plan) {
      PlanTier.free => appText(context, 'Gratis', 'Free'),
      PlanTier.standard => appText(context, 'Estándar', 'Standard'),
      PlanTier.premium => 'Premium',
      null =>
        _cargandoPlan
            ? appText(context, 'Consultando plan…', 'Checking plan…')
            : appText(context, 'Plan no disponible', 'Plan unavailable'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.workspace_premium_rounded, color: color, size: 18),
            const SizedBox(width: 7),
            Text(
              '${appText(context, 'Plan', 'Plan')} $planName',
              style: AppTypography.itemTitle.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaFinanzasInactivas() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.goldDeep,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(
                    context,
                    'Finanzas cuando tú quieras',
                    'Finance when you are ready',
                  ),
                  style: AppTypography.itemTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  appText(
                    context,
                    'Activa el registro de movimientos desde Finanzas cuando quieras empezar.',
                    'Enable transaction tracking in Finance whenever you are ready.',
                  ),
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCompraPendiente(PlanSubscriptionDetails subscription) {
    final isPreparing = subscription.isCheckoutPending;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldSoftBg,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, color: AppColors.goldDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appText(
                    context,
                    'Compra pendiente: ${subscription.plan.label}',
                    'Pending purchase: ${subscription.plan.label}',
                  ),
                  style: AppTypography.itemTitle.copyWith(
                    color: AppColors.goldDeep,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isPreparing
                      ? appText(
                          context,
                          'Puedes retomar el proceso desde aquí.',
                          'You can resume checkout from here.',
                        )
                      : appText(
                          context,
                          'Completa el pago para activar tu plan.',
                          'Complete checkout to activate your plan.',
                        ),
                  style: AppTypography.secondary,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onVerPlanes,
            child: Text(appText(context, 'Continuar', 'Continue')),
          ),
        ],
      ),
    );
  }

  Widget _chipResumen({
    required String titulo,
    required String valor,
    required Color color,
    required Color fondo,
    required Color borde,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: AppTypography.secondary.copyWith(
              color: color,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: AppTypography.itemTitle.copyWith(color: color, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _seccionSinTareas() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appText(
                context,
                'Todo está tranquilo por ahora. Toca Tareas para crear tu próxima prioridad.',
                'You are all caught up. Open Tasks to set your next priority.',
              ),
              style: AppTypography.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaBalance() {
    final home = Theme.of(context).extension<HomeTheme>()!;
    final balance = _ingresosMes - _gastosMes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: home.gradienteBalance,
        borderRadius: BorderRadius.circular(home.radioTarjetaBalance),
        boxShadow: AppColors.sombraPremium(AppColors.gold, blur: 24, dy: 10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(
              context,
              'BALANCE TOTAL DEL MES',
              'TOTAL BALANCE THIS MONTH',
            ),
            style: AppTypography.sectionLabel.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatearMonto(balance),
            style: AppTypography.balanceDisplay.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          Row(
            children: [
              _datoBalance(
                appText(context, 'Ingresos', 'Income'),
                '+${formatearMonto(_ingresosMes)}',
              ),
              _datoBalance(
                appText(context, 'Gastos', 'Expenses'),
                '-${formatearMonto(_gastosMes)}',
              ),
              _datoBalance(
                appText(context, 'Mov.', 'Items'),
                '$_totalMovimientos',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaProyeccion() {
    final color = _proyeccionBalanceMes >= 0 ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: color, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _totalMovimientos == 0
                      ? appText(
                          context,
                          'Proyección mensual',
                          'Monthly forecast',
                        )
                      : appText(
                          context,
                          'Proyección al cierre del mes',
                          'Forecast at month end',
                        ),
                  style: AppTypography.itemTitle,
                ),
                Text(
                  _totalMovimientos == 0
                      ? appText(
                          context,
                          'Registra actividad para estimarla',
                          'Add transactions to see an estimate',
                        )
                      : appText(
                          context,
                          'Si mantienes el ritmo de gasto actual',
                          'If you keep spending at this pace',
                        ),
                  style: AppTypography.secondary.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _totalMovimientos == 0
                ? '—'
                : formatearMonto(_proyeccionBalanceMes),
            style: AppTypography.itemTitle.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _datoBalance(String label, String valor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumenMetasCard() {
    final metaMasCercana = _resumenMetas.metasActivas > 0
        ? '${_resumenMetas.nombreMetaMasCercana} • ${_resumenMetas.porcentajeMetaMasCercana.toStringAsFixed(0)}%'
        : appText(context, 'Sin metas activas', 'No active goals');
    final descripcionMetas = _metasActivas.isNotEmpty
        ? appText(
            context,
            '${_metasActivas.length} metas activas',
            '${_metasActivas.length} active goals',
          )
        : appText(context, 'Aún no tienes metas', 'You have no goals yet');

    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            appText(context, 'AVANCE DE METAS', 'GOAL PROGRESS'),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniKpiResumen(
                  titulo: appText(context, 'Progreso', 'Progress'),
                  valor:
                      '${_resumenMetas.porcentajeGeneral.toStringAsFixed(0)}%',
                  subtitulo: descripcionMetas,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: appText(context, 'Ahorro', 'Savings'),
                  valor: formatearMonto(_resumenMetas.totalActual),
                  subtitulo:
                      '${appText(context, 'de', 'of')} ${formatearMonto(_resumenMetas.totalObjetivo)}',
                  color: AppColors.goldDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            appText(
              context,
              'Más cerca: $metaMasCercana',
              'Closest goal: $metaMasCercana',
            ),
            style: AppTypography.secondary.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _resumenSemanaCard() {
    final porcentaje = _resumenSemana.tareasTotales > 0
        ? (_resumenSemana.tareasCompletadas / _resumenSemana.tareasTotales) *
              100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
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
          Text(
            appText(context, 'RESUMEN DE LA SEMANA', 'WEEKLY SUMMARY'),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniKpiResumen(
                  titulo: appText(context, 'Tareas', 'Tasks'),
                  valor:
                      '${_resumenSemana.tareasCompletadas}/${_resumenSemana.tareasTotales}',
                  subtitulo: _resumenSemana.tareasTotales > 0
                      ? appText(
                          context,
                          '${porcentaje.toStringAsFixed(0)}% hechas',
                          '${porcentaje.toStringAsFixed(0)}% done',
                        )
                      : appText(
                          context,
                          'Sin tareas programadas',
                          'No scheduled tasks',
                        ),
                  color: AppColors.goldDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: appText(context, 'Gastos', 'Expenses'),
                  valor: formatearMonto(_resumenSemana.gastos),
                  subtitulo: appText(context, 'Esta semana', 'This week'),
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: appText(context, 'Balance', 'Balance'),
                  valor: formatearMonto(_resumenSemana.balance),
                  subtitulo: appText(context, 'Semana actual', 'Current week'),
                  color: _resumenSemana.balance >= 0
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

  Widget _miniKpiResumen({
    required String titulo,
    required String valor,
    required String subtitulo,
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
          Text(
            titulo,
            style: AppTypography.secondary.copyWith(
              fontSize: 10.5,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            style: AppTypography.itemTitle.copyWith(fontSize: 14, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: AppTypography.secondary.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _alertaPresupuesto() {
    final porcentaje = _alertasPresupuesto.isNotEmpty
        ? _alertasPresupuesto.first['porcentaje'] as double
        : _porcentajePresupuestoUsado ?? 0;
    final color = porcentaje >= 90
        ? AppColors.red
        : porcentaje >= 75
        ? AppColors.amber
        : AppColors.green;
    final texto = porcentaje >= 90
        ? appText(
            context,
            'Estás muy cerca del límite de tus presupuestos.',
            'You are close to your budget limits.',
          )
        : porcentaje >= 75
        ? appText(
            context,
            'Tu gasto acumulado ya está alto para esta semana.',
            'Your spending is already high this week.',
          )
        : appText(
            context,
            'Tu presupuesto va por buen camino esta semana.',
            'Your budget is on track this week.',
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: AppRadii.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alertasPresupuesto.isNotEmpty
                      ? appText(
                          context,
                          'Límites por categoría cerca del tope',
                          'Category budgets nearing their limits',
                        )
                      : appText(
                          context,
                          'Presupuesto activo: ${porcentaje.toStringAsFixed(0)}% usado',
                          'Active budget: ${porcentaje.toStringAsFixed(0)}% used',
                        ),
                  style: AppTypography.itemTitle.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  _alertasPresupuesto.isNotEmpty
                      ? _alertasPresupuesto
                            .map(
                              (alerta) =>
                                  '${alerta['nombre']}: ${(alerta['porcentaje'] as double).toStringAsFixed(0)}%',
                            )
                            .join(' · ')
                      : texto,
                  style: AppTypography.secondary.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionTareasPendientes() {
    final tareasTheme = Theme.of(context).extension<TareasTheme>()!;
    final coloresPrioridad = {
      'alta': tareasTheme.prioridadAlta,
      'media': tareasTheme.prioridadMedia,
      'baja': tareasTheme.prioridadBaja,
    };

    return Container(
      padding: const EdgeInsets.all(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  appText(context, 'TAREAS PENDIENTES', 'PENDING TASKS'),
                  style: AppTypography.sectionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onVerTareas,
                child: Text(
                  appText(context, 'Ver todas →', 'View all →'),
                  style: AppTypography.secondary.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._tareasPendientes.map((t) {
            final fechaLimiteRaw = t['fecha_limite'];
            final fechaLimite = fechaLimiteRaw is String
                ? DateTime.tryParse(fechaLimiteRaw)
                : null;
            final hora = fechaLimite != null
                ? '${fechaLimite.hour.toString().padLeft(2, '0')}:${fechaLimite.minute.toString().padLeft(2, '0')}'
                : appText(context, 'Sin hora', 'No time set');
            final color =
                coloresPrioridad[t['prioridad']] ?? AppColors.textTertiary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t['titulo'] ?? 'Tarea sin título',
                      style: AppTypography.itemTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    hora,
                    style: AppTypography.secondary.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _seccionRecomendaciones(List<String> consejos) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.goldSoftBg,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(
          color: AppColors.goldBorder,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨ ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  appText(
                    context,
                    'RECOMENDACIONES PARA TI',
                    'SUGGESTIONS FOR YOU',
                  ),
                  style: AppTypography.sectionLabel.copyWith(
                    color: AppColors.goldDeep,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appText(
              context,
              'Sugerencias basadas en tus registros; no se usa IA generativa.',
              'Suggestions based on your records; no generative AI is used.',
            ),
            style: AppTypography.secondary.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...consejos.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                c,
                style: AppTypography.bodyBase.copyWith(
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
