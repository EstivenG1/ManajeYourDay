import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import 'meta_form_screen.dart';
import 'meta_detalle_screen.dart';

class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  bool _cargando = true;
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
      if (mounted) {
        setState(() {
          _metas = List<Map<String, dynamic>>.from(data);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
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

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Metas de ahorro')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
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
              : const LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
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
                  const Icon(Icons.check_circle, color: AppColors.green, size: 18),
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
                Text('${formatearMonto(actual)} de ${formatearMonto(objetivo)}',
                    style: TextStyle(
                      color: completada ? AppColors.textSecondary : Colors.white70,
                      fontSize: 12.5,
                    )),
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
