import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';

class HomeTab extends StatefulWidget {
  final String? nombre;
  final VoidCallback onVerTareas;

  const HomeTab({super.key, required this.nombre, required this.onVerTareas});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _cargando = true;
  String? _errorCarga;
  double _ingresosMes = 0;
  double _gastosMes = 0;
  double _gastosMesAnterior = 0;
  double? _porcentajePresupuestoUsado;
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
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final inicioMesAnterior = DateTime(ahora.year, ahora.month - 1, 1);
      final movimientos = <Map<String, dynamic>>[];
      const tamanoPagina = 500;
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

      final presupuestos = await supabase
          .from('presupuestos')
          .select('monto_limite, categoria_id, fecha_inicio, fecha_fin')
          .eq('usuario_id', userId)
          .lte('fecha_inicio', _fechaTexto(ahora))
          .gte('fecha_fin', _fechaTexto(ahora));
      var totalLimites = 0.0;
      var totalGastadoPresupuestos = 0.0;
      for (final presupuesto in presupuestos as List) {
        totalLimites += (presupuesto['monto_limite'] as num).toDouble();
        for (var inicio = 0; ; inicio += tamanoPagina) {
          final gastado = await supabase
              .from('movimientos')
              .select('monto')
              .eq('usuario_id', userId)
              .eq('categoria_id', presupuesto['categoria_id'])
              .eq('tipo', 'gasto')
              .gte('fecha', presupuesto['fecha_inicio'])
              .lte('fecha', presupuesto['fecha_fin'])
              .order('id')
              .range(inicio, inicio + tamanoPagina - 1);
          totalGastadoPresupuestos += (gastado as List).fold<double>(
            0,
            (sum, item) => sum + (item['monto'] as num).toDouble(),
          );
          if (gastado.length < tamanoPagina) break;
        }
      }

      final tareasPend = await supabase
          .from('tareas')
          .select()
          .eq('usuario_id', userId)
          .eq('estado', 'pendiente')
          .order('fecha_limite', ascending: true)
          .limit(5);

      final metasActivas = await supabase
          .from('metas_ahorro')
          .select('nombre, monto_objetivo, monto_actual, estado')
          .eq('usuario_id', userId)
          .eq('estado', 'activa');
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
        _ingresosMes = ingresos;
        _gastosMes = gastos;
        _gastosMesAnterior = gastosAnteriores;
        _porcentajePresupuestoUsado = totalLimites <= 0
            ? null
            : totalGastadoPresupuestos / totalLimites * 100;
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
      onRefresh: _cargarDatos,
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
          const SizedBox(height: 20),

          _tarjetaBalance(),
          const SizedBox(height: 18),
          _resumenMetasCard(),
          const SizedBox(height: 18),
          _resumenSemanaCard(),
          const SizedBox(height: 18),
          if (_porcentajePresupuestoUsado != null) ...[
            _alertaPresupuesto(),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: _chipResumen(
                  titulo: 'Productividad',
                  valor: '${productividad.toStringAsFixed(0)}%',
                  color: AppColors.goldDeep,
                  fondo: AppColors.goldSoftBg,
                  borde: AppColors.goldBorder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _chipResumen(
                  titulo: 'Balance',
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
              'Todo está tranquilo por ahora. Toca Tareas para crear tu próxima prioridad.',
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
            'BALANCE TOTAL DEL MES',
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
              _datoBalance('Ingresos', '+${formatearMonto(_ingresosMes)}'),
              _datoBalance('Gastos', '-${formatearMonto(_gastosMes)}'),
              _datoBalance('Mov.', '$_totalMovimientos'),
            ],
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
        : 'Sin metas activas';
    final descripcionMetas = _metasActivas.isNotEmpty
        ? '${_metasActivas.length} metas activas'
        : 'Aún no tienes metas';

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
          Text('AVANCE DE METAS', style: AppTypography.sectionLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniKpiResumen(
                  titulo: 'Progreso',
                  valor: '${_resumenMetas.porcentajeGeneral.toStringAsFixed(0)}%',
                  subtitulo: descripcionMetas,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: 'Ahorro',
                  valor: formatearMonto(_resumenMetas.totalActual),
                  subtitulo: 'de ${formatearMonto(_resumenMetas.totalObjetivo)}',
                  color: AppColors.goldDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Más cerca: $metaMasCercana',
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
          Text('RESUMEN DE LA SEMANA', style: AppTypography.sectionLabel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniKpiResumen(
                  titulo: 'Tareas',
                  valor:
                      '${_resumenSemana.tareasCompletadas}/${_resumenSemana.tareasTotales}',
                  subtitulo: _resumenSemana.tareasTotales > 0
                      ? '${porcentaje.toStringAsFixed(0)}% hechas'
                      : 'Sin tareas programadas',
                  color: AppColors.goldDeep,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: 'Gastos',
                  valor: formatearMonto(_resumenSemana.gastos),
                  subtitulo: 'Esta semana',
                  color: AppColors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniKpiResumen(
                  titulo: 'Balance',
                  valor: formatearMonto(_resumenSemana.balance),
                  subtitulo: 'Semana actual',
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
    final porcentaje = _porcentajePresupuestoUsado ?? 0;
    final color = porcentaje >= 90
        ? AppColors.red
        : porcentaje >= 75
        ? AppColors.amber
        : AppColors.green;
    final texto = porcentaje >= 90
        ? 'Estás muy cerca del límite de tus presupuestos.'
        : porcentaje >= 75
        ? 'Tu gasto acumulado ya está alto para esta semana.'
        : 'Tu presupuesto va por buen camino esta semana.';

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
                  'Presupuesto activo: ${porcentaje.toStringAsFixed(0)}% usado',
                  style: AppTypography.itemTitle.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
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
                  'TAREAS PENDIENTES',
                  style: AppTypography.sectionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onVerTareas,
                child: Text(
                  'Ver todas →',
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
                : 'Sin hora';
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
