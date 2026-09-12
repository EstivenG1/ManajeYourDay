import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import 'transaction_form_screen.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _movimientos = [];
  double _ingresos = 0;
  double _gastos = 0;

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
          .from('movimientos')
          .select('*, categorias(nombre, icono)')
          .eq('usuario_id', userId)
          .order('fecha', ascending: false)
          .order('creado_en', ascending: false)
          .limit(50);

      double ingresos = 0, gastos = 0;
      for (final m in data as List) {
        final monto = (m['monto'] as num).toDouble();
        if (m['tipo'] == 'ingreso') {
          ingresos += monto;
        } else {
          gastos += monto;
        }
      }

      if (mounted) {
        setState(() {
          _movimientos = List<Map<String, dynamic>>.from(data);
          _ingresos = ingresos;
          _gastos = gastos;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirFormulario({String tipoInicial = 'gasto', Map<String, dynamic>? movimiento}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(tipoInicial: tipoInicial, movimiento: movimiento),
      ),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> mov) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar movimiento?'),
        content: Text('"${mov['descripcion'] ?? 'Movimiento'}" se eliminará.'),
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
      await supabase.from('movimientos').delete().eq('id', mov['id']);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = Theme.of(context).extension<FinanzasTheme>()!;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _tarjetaBalance(finanzas),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _botonAccion(
                          texto: '+ Agregar Ingreso',
                          gradiente: finanzas.gradienteBotonIngreso,
                          onTap: () => _abrirFormulario(tipoInicial: 'ingreso'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _botonAccion(
                          texto: '+ Agregar Gasto',
                          gradiente: finanzas.gradienteBotonGasto,
                          onTap: () => _abrirFormulario(tipoInicial: 'gasto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('MOVIMIENTOS RECIENTES', style: AppTypography.sectionLabel),
                  const SizedBox(height: 10),
                  if (_movimientos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('Aún no tienes movimientos registrados.',
                            style: AppTypography.secondary),
                      ),
                    )
                  else
                    ..._movimientos.map((m) => _itemMovimiento(m, finanzas)),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaBalance(FinanzasTheme finanzas) {
    final balance = _ingresos - _gastos;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BALANCE DISPONIBLE', style: AppTypography.sectionLabel),
          const SizedBox(height: 6),
          Text(formatearMonto(balance), style: AppTypography.balanceDisplay),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _chipResumen('Ingresos', formatearMonto(_ingresos), finanzas.colorIngreso,
                    finanzas.chipIngresoBg, finanzas.chipIngresoBorder),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _chipResumen('Gastos', formatearMonto(_gastos), finanzas.colorGasto,
                    finanzas.chipGastoBg, finanzas.chipGastoBorder),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipResumen(String label, String valor, Color color, Color bg, Color borde) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.secondary.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _botonAccion({required String texto, required Gradient gradiente, required VoidCallback onTap}) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradiente,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            onTap: onTap,
            child: Center(
              child: Text(texto,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemMovimiento(Map<String, dynamic> m, FinanzasTheme finanzas) {
    final esIngreso = m['tipo'] == 'ingreso';
    final color = esIngreso ? finanzas.colorIngreso : finanzas.colorGasto;
    final categoria = m['categorias']?['nombre'] ?? 'Sin categoría';
    final fecha = DateTime.parse(m['fecha']);
    final fechaTexto = '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(finanzas.radioTarjeta),
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            alignment: Alignment.center,
            child: Icon(esIngreso ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirFormulario(tipoInicial: m['tipo'], movimiento: m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m['descripcion']?.toString().isNotEmpty == true ? m['descripcion'] : categoria,
                      style: AppTypography.itemTitle),
                  const SizedBox(height: 2),
                  Text('$categoria · $fechaTexto',
                      style: AppTypography.secondary.copyWith(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
          ),
          Text('${esIngreso ? '+' : '-'}${formatearMonto(m['monto'])}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 18),
            onPressed: () => _eliminar(m),
          ),
        ],
      ),
    );
  }
}
