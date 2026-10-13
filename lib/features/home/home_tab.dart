import 'package:flutter/material.dart';
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
  double _ingresosMes = 0;
  double _gastosMes = 0;
  int _totalMovimientos = 0;
  List<Map<String, dynamic>> _tareasPendientes = [];
  int _tareasCompletadasMes = 0;
  int _tareasTotalesMes = 0;

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
      final inicioMesStr =
          '${inicioMes.year}-${inicioMes.month.toString().padLeft(2, '0')}-01';

      final movimientos = await supabase
          .from('movimientos')
          .select('tipo, monto')
          .eq('usuario_id', userId)
          .gte('fecha', inicioMesStr);

      double ingresos = 0;
      double gastos = 0;
      for (final m in movimientos as List) {
        final monto = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'ingreso') {
          ingresos += monto;
        } else {
          gastos += monto;
        }
      }

      final tareasPend = await supabase
          .from('tareas')
          .select()
          .eq('usuario_id', userId)
          .eq('estado', 'pendiente')
          .order('fecha_limite', ascending: true)
          .limit(5);

      final tareasMes = await supabase
          .from('tareas')
          .select('estado')
          .eq('usuario_id', userId)
          .gte('creado_en', inicioMes.toIso8601String());

      final completadas =
          (tareasMes as List).where((t) => t['estado'] == 'completada').length;

      if (!mounted) return;
      setState(() {
        _ingresosMes = ingresos;
        _gastosMes = gastos;
        _totalMovimientos = movimientos.length;
        _tareasPendientes = List<Map<String, dynamic>>.from(tareasPend);
        _tareasCompletadasMes = completadas;
        _tareasTotalesMes = tareasMes.length;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    final hoy = formatearFechaEs(DateTime.now());
    final consejos = generarConsejosIA(
      ingresosMes: _ingresosMes,
      gastosMes: _gastosMes,
      tareasPendientes: _tareasPendientes.length,
      tareasCompletadas: _tareasCompletadasMes,
      tareasTotales: _tareasTotalesMes,
    );
    final balanceMes = _ingresosMes - _gastosMes;
    final productividad = _tareasTotalesMes == 0
        ? 0.0
        : (_tareasCompletadasMes / _tareasTotalesMes) * 100;

    return RefreshIndicator(
      color: AppColors.gold,
      onRefresh: _cargarDatos,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(hoy, style: AppTypography.secondary),
          const SizedBox(height: 4),
          Text('¡Hola, ${widget.nombre ?? "de nuevo"}! 👋', style: AppTypography.greeting),
          const SizedBox(height: 20),

          _tarjetaBalance(),
          const SizedBox(height: 18),
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
                  fondo: balanceMes >= 0 ? AppColors.greenChipBg : AppColors.redChipBg,
                  borde: balanceMes >= 0 ? AppColors.greenChipBorder : AppColors.redChipBorder,
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
          _seccionConsejosIA(consejos),
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
          Text(titulo, style: AppTypography.secondary.copyWith(color: color, fontSize: 10.5)),
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
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
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
          Text('BALANCE TOTAL DEL MES',
              style: AppTypography.sectionLabel.copyWith(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(formatearMonto(balance),
              style: AppTypography.balanceDisplay.copyWith(color: Colors.white)),
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
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
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TAREAS PENDIENTES', style: AppTypography.sectionLabel),
              GestureDetector(
                onTap: widget.onVerTareas,
                child: Text('Ver todas →',
                    style: AppTypography.secondary.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700)),
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
            final color = coloresPrioridad[t['prioridad']] ?? AppColors.textTertiary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                    style: AppTypography.secondary.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _seccionConsejosIA(List<String> consejos) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.goldSoftBg,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.goldBorder, width: AppRadii.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨ ', style: TextStyle(fontSize: 16)),
              Text('RECOMENDACIONES PARA TI',
                  style: AppTypography.sectionLabel.copyWith(color: AppColors.goldDeep)),
            ],
          ),
          const SizedBox(height: 12),
          ...consejos.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(c,
                  style: AppTypography.bodyBase.copyWith(fontSize: 13.5, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}
