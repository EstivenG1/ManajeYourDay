import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import 'transaction_form_screen.dart';
import '../metas/metas_screen.dart';
import 'presupuestos_screen.dart';
import 'movimientos_recurrentes_screen.dart';
import '../reportes/exportar_datos_screen.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({super.key});

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  bool _cargando = true;
  String? _errorCarga;
  List<Map<String, dynamic>> _movimientos = [];
  double _ingresos = 0;
  double _gastos = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('movimientos')
          .select('*, categorias(nombre, icono)')
          .eq('usuario_id', userId)
          .order('fecha', ascending: false)
          .order('creado_en', ascending: false)
          .limit(50);

      final totales = <Map<String, dynamic>>[];
      var inicio = 0;
      const tamanoPagina = 500;
      while (true) {
        final pagina = await supabase
            .from('movimientos')
            .select('tipo, monto')
            .eq('usuario_id', userId)
            .order('id')
            .range(inicio, inicio + tamanoPagina - 1);
        totales.addAll(List<Map<String, dynamic>>.from(pagina));
        if (pagina.length < tamanoPagina) break;
        inicio += tamanoPagina;
      }

      double ingresos = 0, gastos = 0;
      for (final m in totales) {
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
          _errorCarga = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudieron cargar tus movimientos: $e';
        });
      }
    }
  }

  Future<void> _abrirFormulario({
    String tipoInicial = 'gasto',
    Map<String, dynamic>? movimiento,
  }) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          tipoInicial: tipoInicial,
          movimiento: movimiento,
        ),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar', style: TextStyle(color: AppColors.red)),
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
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorCarga != null
          ? _estadoErrorCarga()
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _tarjetaBalance(finanzas),
                  const SizedBox(height: 14),
                  _botonMetas(),
                  const SizedBox(height: 10),
                  _botonPresupuestos(),
                  const SizedBox(height: 16),
                  _botonRecurrentes(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ExportarDatosScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.ios_share),
                      label: Text(
                        appText(
                          context,
                          'Exportar movimientos',
                          'Export transactions',
                        ),
                      ),
                    ),
                  ),
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
                  Text(
                    appText(
                      context,
                      'MOVIMIENTOS RECIENTES',
                      'RECENT TRANSACTIONS',
                    ),
                    style: AppTypography.sectionLabel,
                  ),
                  const SizedBox(height: 10),
                  if (_movimientos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          appText(
                            context,
                            'Aún no tienes movimientos registrados.',
                            'No transactions recorded yet.',
                          ),
                          style: AppTypography.secondary,
                        ),
                      ),
                    )
                  else
                    ..._movimientos.map((m) => _itemMovimiento(m, finanzas)),
                ],
              ),
            ),
    );
  }

  Widget _estadoErrorCarga() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: AppColors.red, size: 38),
            const SizedBox(height: 12),
            Text(_errorCarga!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonMetas() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MetasScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.goldSoftBg,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appText(context, 'Metas de ahorro', 'Savings goals'),
                style: AppTypography.itemTitle.copyWith(
                  color: AppColors.goldDeep,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.goldDeep, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _botonPresupuestos() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PresupuestosScreen()),
      ).then((_) => _cargar()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appText(context, 'Gestionar presupuestos', 'Manage budgets'),
                style: AppTypography.itemTitle,
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _botonRecurrentes() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MovimientosRecurrentesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            Icon(Icons.repeat, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appText(
                  context,
                  'Ingresos y pagos recurrentes',
                  'Recurring income and bills',
                ),
                style: AppTypography.itemTitle,
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appText(context, 'BALANCE DISPONIBLE', 'AVAILABLE BALANCE'),
            style: AppTypography.sectionLabel,
          ),
          const SizedBox(height: 6),
          Text(formatearMonto(balance), style: AppTypography.balanceDisplay),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _chipResumen(
                  'Ingresos',
                  formatearMonto(_ingresos),
                  finanzas.colorIngreso,
                  finanzas.chipIngresoBg,
                  finanzas.chipIngresoBorder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _chipResumen(
                  'Gastos',
                  formatearMonto(_gastos),
                  finanzas.colorGasto,
                  finanzas.chipGastoBg,
                  finanzas.chipGastoBorder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipResumen(
    String label,
    String valor,
    Color color,
    Color bg,
    Color borde,
  ) {
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
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({
    required String texto,
    required Gradient gradiente,
    required VoidCallback onTap,
  }) {
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
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
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
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(finanzas.radioTarjeta),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            alignment: Alignment.center,
            child: Icon(
              esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  _abrirFormulario(tipoInicial: m['tipo'], movimiento: m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['descripcion']?.toString().isNotEmpty == true
                        ? m['descripcion']
                        : categoria,
                    style: AppTypography.itemTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$categoria · $fechaTexto',
                    style: AppTypography.secondary.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${esIngreso ? '+' : '-'}${formatearMonto(m['monto'])}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.textTertiary,
              size: 18,
            ),
            onPressed: () => _eliminar(m),
          ),
        ],
      ),
    );
  }
}
