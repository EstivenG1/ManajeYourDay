import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import 'meta_form_screen.dart';

class MetaDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> meta;
  const MetaDetalleScreen({super.key, required this.meta});

  @override
  State<MetaDetalleScreen> createState() => _MetaDetalleScreenState();
}

class _MetaDetalleScreenState extends State<MetaDetalleScreen> {
  late Map<String, dynamic> _meta;
  List<Map<String, dynamic>> _aportes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _meta = widget.meta;
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final metaActualizada = await supabase
          .from('metas_ahorro')
          .select()
          .eq('id', _meta['id'])
          .single();
      final aportes = await supabase
          .from('aportes_ahorro')
          .select()
          .eq('meta_id', _meta['id'])
          .order('fecha', ascending: false);

      if (mounted) {
        setState(() {
          _meta = metaActualizada;
          _aportes = List<Map<String, dynamic>>.from(aportes);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _agregarAporte() async {
    final montoCtrl = TextEditingController();
    final notaCtrl = TextEditingController();

    final resultado = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl3)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agregar aporte', style: AppTypography.screenTitle.copyWith(fontSize: 18)),
            const SizedBox(height: 16),
            Text('MONTO', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            TextField(
              controller: montoCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTypography.balanceDisplay.copyWith(fontSize: 26, color: AppColors.gold),
              decoration: const InputDecoration(hintText: '0'),
            ),
            const SizedBox(height: 14),
            Text('NOTA (opcional)', style: AppTypography.sectionLabel),
            const SizedBox(height: 8),
            TextField(controller: notaCtrl, decoration: const InputDecoration(hintText: 'Ej: Bono de diciembre')),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(AppRadii.xl2),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.xl2),
                    onTap: () {
                      final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
                      if (monto == null || monto <= 0) return;
                      Navigator.pop(context, true);
                    },
                    child: const Center(
                      child: Text('Guardar aporte',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (resultado == true) {
      final monto = double.tryParse(montoCtrl.text.replaceAll(',', '.'));
      if (monto == null || monto <= 0) return;
      try {
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('aportes_ahorro').insert({
          'meta_id': _meta['id'],
          'usuario_id': userId,
          'monto': monto,
          'nota': notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
        });
        _cargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
        }
      }
    }
  }

  Future<void> _eliminarAporte(Map<String, dynamic> aporte) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar aporte?'),
        content: Text('Se eliminará el aporte de ${formatearMonto(aporte['monto'])}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await supabase.from('aportes_ahorro').delete().eq('id', aporte['id']);
      _cargar();
    }
  }

  Future<void> _editarMeta() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MetaFormScreen(meta: _meta)),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _eliminarMeta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar meta?'),
        content: Text('"${_meta['nombre']}" y todo su historial de aportes se eliminarán.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await supabase.from('metas_ahorro').delete().eq('id', _meta['id']);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final objetivo = (_meta['monto_objetivo'] as num).toDouble();
    final actual = (_meta['monto_actual'] as num).toDouble();
    final pct = objetivo == 0 ? 0.0 : (actual / objetivo).clamp(0, 1.0);
    final completada = _meta['estado'] == 'completada';
    final restante = (objetivo - actual).clamp(0, objetivo);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(_meta['nombre']),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'editar' ? _editarMeta() : _eliminarMeta(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'editar', child: Text('Editar meta')),
              const PopupMenuItem(value: 'eliminar', child: Text('Eliminar meta')),
            ],
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.gold, AppColors.goldDark]),
                      borderRadius: BorderRadius.circular(AppRadii.xl3),
                      boxShadow: AppColors.sombraPremium(AppColors.gold, blur: 24, dy: 10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_meta['icono'] ?? '🎯', style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            if (completada)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(AppRadii.full),
                                ),
                                child: const Text('✅ Completada',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(formatearMonto(actual),
                            style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                        Text('de ${formatearMonto(objetivo)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.full),
                          child: LinearProgressIndicator(
                            value: pct.toDouble(),
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${(pct * 100).toStringAsFixed(0)}% completado',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            if (!completada)
                              Text('Faltan ${formatearMonto(restante)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('HISTORIAL DE APORTES', style: AppTypography.sectionLabel),
                  const SizedBox(height: 12),
                  if (_aportes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('Aún no has agregado ningún aporte.', style: AppTypography.secondary),
                    )
                  else
                    ..._aportes.map((a) {
                      final fecha = DateTime.parse(a['fecha']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl2),
                          border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_outlined, color: AppColors.gold, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatearMonto(a['monto']),
                                      style: AppTypography.itemTitle.copyWith(color: AppColors.green)),
                                  Text(
                                    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'
                                    '${a['nota'] != null ? ' · ${a['nota']}' : ''}',
                                    style: AppTypography.secondary.copyWith(fontSize: 11.5),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 18),
                              onPressed: () => _eliminarAporte(a),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: completada
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              onPressed: _agregarAporte,
              icon: const Icon(Icons.add),
              label: const Text('Agregar aporte'),
            ),
    );
  }
}
