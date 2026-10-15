import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/notification_service.dart';
import 'meta_form_screen.dart';
import 'meta_detalle_screen.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  bool _cargando = true;
  String? _errorCarga;
  List<Map<String, dynamic>> _metas = [];
  bool _mostrarCompletadas = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('metas_ahorro')
          .select()
          .eq('usuario_id', userId)
          .order('creado_en', ascending: false);
      for (final meta in data as List) {
        final aporte = (meta['aporte_programado'] as num?)?.toDouble() ?? 0;
        if (meta['estado'] == 'activa' && aporte > 0) {
          var proximo = meta['proximo_aporte'] == null
              ? DateTime.now()
              : DateTime.parse(meta['proximo_aporte'] as String);
          final hoy = DateTime.now();
          while (!proximo.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
            proximo = _siguienteAporte(
              proximo,
              meta['frecuencia_aporte'] as String? ?? 'mensual',
            );
          }
          await supabase.from('metas_ahorro').update({
            'proximo_aporte': proximo.toIso8601String().split('T').first,
          }).eq('id', meta['id']);
          await NotificationService.programarRecordatorioMeta(
            metaId: meta['id'].toString(),
            nombre: meta['nombre'] as String,
            aporte: aporte,
            frecuencia: meta['frecuencia_aporte'] as String? ?? 'mensual',
            proximoAporte: proximo,
          );
        } else {
          await NotificationService.cancelarRecordatorioMeta(
            meta['id'].toString(),
          );
        }
      }
      if (mounted) {
        setState(() {
          _metas = List<Map<String, dynamic>>.from(data);
          _cargando = false;
          _errorCarga = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudieron cargar las metas: $error';
        });
      }
    }
  }

  DateTime _siguienteAporte(DateTime fecha, String frecuencia) {
    if (frecuencia == 'semanal') return fecha.add(const Duration(days: 7));
    if (frecuencia == 'quincenal') return fecha.add(const Duration(days: 14));
    final primerDiaSiguiente = DateTime(fecha.year, fecha.month + 1, 1);
    final ultimoDiaSiguiente =
        DateTime(primerDiaSiguiente.year, primerDiaSiguiente.month + 1, 0);
    return DateTime(
      primerDiaSiguiente.year,
      primerDiaSiguiente.month,
      fecha.day.clamp(1, ultimoDiaSiguiente.day),
    );
  }

  Future<void> _abrirCrear() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const MetaFormScreen()),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _abrirDetalle(Map<String, dynamic> meta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MetaDetalleScreen(meta: meta)),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final activas = _metas.where((m) => m['estado'] == 'activa').toList();
    final completadas = _metas.where((m) => m['estado'] == 'completada').toList();
    final totalObjetivo = activas.fold<double>(0, (sum, meta) {
      final valor = meta['monto_objetivo'];
      return sum + ((valor is num) ? valor.toDouble() : 0.0);
    });
    final totalActual = activas.fold<double>(0, (sum, meta) {
      final valor = meta['monto_actual'];
      return sum + ((valor is num) ? valor.toDouble() : 0.0);
    });

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Metas de ahorro')),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorCarga != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorCarga!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _cargar,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (activas.isNotEmpty || completadas.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(AppRadii.xl2),
                        boxShadow: AppColors.sombraPremium(AppColors.gold, blur: 18, dy: 8),
                      ),
                      child: Row(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Progreso general',
                                  style: AppTypography.secondary.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatearMonto(totalActual)} de ${formatearMonto(totalObjetivo)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (activas.isEmpty && completadas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text('Aún no tienes metas de ahorro.\nToca + para crear la primera.',
                              textAlign: TextAlign.center, style: AppTypography.secondary),
                        ],
                      ),
                    ),
                  ...activas.map((m) => _tarjetaMeta(m)),
                  if (completadas.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _mostrarCompletadas = !_mostrarCompletadas),
                      child: Row(
                        children: [
                          Text('COMPLETADAS (${completadas.length})',
                              style: AppTypography.sectionLabel),
                          const SizedBox(width: 6),
                          Icon(_mostrarCompletadas ? Icons.expand_less : Icons.expand_more,
                              size: 18, color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_mostrarCompletadas) ...completadas.map((m) => _tarjetaMeta(m)),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: _abrirCrear,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tarjetaMeta(Map<String, dynamic> meta) {
    final objetivo = (meta['monto_objetivo'] as num).toDouble();
    final actual = (meta['monto_actual'] as num).toDouble();
    final pct = objetivo == 0 ? 0.0 : (actual / objetivo).clamp(0, 1.0);
    final completada = meta['estado'] == 'completada';

    return GestureDetector(
      onTap: () => _abrirDetalle(meta),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: completada
              ? null
              : LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
          color: completada ? AppColors.surface : null,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: completada ? Border.all(color: AppColors.borderSoft) : null,
          boxShadow: completada ? null : AppColors.sombraPremium(AppColors.gold, blur: 18, dy: 6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(meta['icono'] ?? '🎯', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(meta['nombre'],
                      style: TextStyle(
                        color: completada ? AppColors.textPrimary : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      )),
                ),
                if (completada)
                  Icon(Icons.check_circle, color: AppColors.green, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                minHeight: 9,
                backgroundColor: completada ? AppColors.borderSoft : Colors.white.withValues(alpha: 0.3),
                color: completada ? AppColors.green : Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatearMonto(actual)} de ${formatearMonto(objetivo)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: completada
                              ? AppColors.textSecondary
                              : Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                      if (((meta['aporte_programado'] as num?)
                                  ?.toDouble() ??
                              0) >
                          0) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Aporte ${meta['frecuencia_aporte'] ?? 'mensual'}: '
                          '${formatearMonto(meta['aporte_programado'])}',
                          style: AppTypography.secondary.copyWith(
                            color: completada
                                ? AppColors.textSecondary
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: completada ? AppColors.textPrimary : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
