import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import 'presupuesto_form_screen.dart';

class PresupuestosScreen extends StatefulWidget {
  const PresupuestosScreen({super.key});

  @override
  State<PresupuestosScreen> createState() => _PresupuestosScreenState();
}

class _PresupuestosScreenState extends State<PresupuestosScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _presupuestos = [];
  // presupuesto_id -> monto gastado en su periodo
  final Map<String, double> _consumo = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      final presupuestos = await supabase
          .from('presupuestos')
          .select('*, categorias(nombre, icono)')
          .eq('usuario_id', userId)
          .order('fecha_fin', ascending: false);

      _consumo.clear();

      // Por cada presupuesto, suma los gastos de su categoría dentro de
      // su ventana de fechas.
      for (final p in presupuestos as List) {
        var consulta = supabase
            .from('movimientos')
            .select('monto')
            .eq('usuario_id', userId)
            .eq('tipo', 'gasto')
            .gte('fecha', p['fecha_inicio'])
            .lte('fecha', p['fecha_fin']);

        // categoria_id nulo = presupuesto general (todos los gastos)
        if (p['categoria_id'] != null) {
          consulta = consulta.eq('categoria_id', p['categoria_id']);
        }

        final gastos = await consulta;
        final total = (gastos as List)
            .fold<double>(0, (a, g) => a + (g['monto'] as num).toDouble());
        _consumo[p['id']] = total;
      }

      if (mounted) {
        setState(() {
          _presupuestos = List<Map<String, dynamic>>.from(presupuestos);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? presupuesto}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PresupuestoFormScreen(presupuesto: presupuesto),
      ),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final nombre = p['categorias']?['nombre'] ?? 'General';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar presupuesto?'),
        content: Text('Se eliminará el presupuesto de "$nombre".'),
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
      await supabase.from('presupuestos').delete().eq('id', p['id']);
      _cargar();
    }
  }

  bool _estaVigente(Map<String, dynamic> p) {
    final hoy = DateTime.now();
    final inicio = DateTime.parse(p['fecha_inicio']);
    final fin = DateTime.parse(p['fecha_fin']);
    return !hoy.isBefore(inicio) && !hoy.isAfter(fin.add(const Duration(days: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final vigentes = _presupuestos.where(_estaVigente).toList();
    final vencidos = _presupuestos.where((p) => !_estaVigente(p)).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Presupuestos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_presupuestos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          const Text('📊', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                            'Aún no tienes presupuestos.\nCrea uno para controlar cuánto gastas\ny recibir alertas antes de pasarte.',
                            textAlign: TextAlign.center,
                            style: AppTypography.secondary,
                          ),
                        ],
                      ),
                    ),
                  if (vigentes.isNotEmpty) ...[
                    Text('VIGENTES', style: AppTypography.sectionLabel),
                    const SizedBox(height: 12),
                    ...vigentes.map(_tarjetaPresupuesto),
                    const SizedBox(height: 14),
                  ],
                  if (vencidos.isNotEmpty) ...[
                    Text('FUERA DE PERIODO', style: AppTypography.sectionLabel),
                    const SizedBox(height: 12),
                    ...vencidos.map(_tarjetaPresupuesto),
                  ],
                  const SizedBox(height: 70),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _tarjetaPresupuesto(Map<String, dynamic> p) {
    final limite = (p['monto_limite'] as num).toDouble();
    final gastado = _consumo[p['id']] ?? 0;
    final pct = limite == 0 ? 0.0 : gastado / limite;
    final restante = limite - gastado;
    final vigente = _estaVigente(p);

    final Color colorBarra;
    if (pct >= 1.0) {
      colorBarra = AppColors.red;
    } else if (pct >= 0.8) {
      colorBarra = AppColors.amber;
    } else {
      colorBarra = AppColors.green;
    }

    final nombre = p['categorias']?['nombre'] ?? 'General (todas las categorías)';
    final inicio = DateTime.parse(p['fecha_inicio']);
    final fin = DateTime.parse(p['fecha_fin']);
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

    return Opacity(
      opacity: vigente ? 1 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(
            color: pct >= 1.0 && vigente ? AppColors.red : AppColors.borderSoft,
            width: AppRadii.borderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis),
                      Text('${p['periodo']} · ${fmt(inicio)} - ${fmt(fin)}',
                          style: AppTypography.secondary.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textTertiary),
                  onSelected: (v) =>
                      v == 'editar' ? _abrirFormulario(presupuesto: p) : _eliminar(p),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'editar', child: Text('Editar')),
                    PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.full),
              child: LinearProgressIndicator(
                value: pct > 1 ? 1 : pct,
                minHeight: 9,
                backgroundColor: AppColors.borderSoft,
                color: colorBarra,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${formatearMonto(gastado)} de ${formatearMonto(limite)}',
                    style: AppTypography.secondary.copyWith(fontSize: 12)),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: colorBarra, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              restante >= 0
                  ? 'Te quedan ${formatearMonto(restante)}'
                  : '⚠️ Te pasaste por ${formatearMonto(restante.abs())}',
              style: TextStyle(
                color: restante >= 0 ? AppColors.textSecondary : AppColors.red,
                fontSize: 12,
                fontWeight: restante >= 0 ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
