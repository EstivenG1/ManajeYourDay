import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/formatters/category_emoji.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/finance_repository.dart';
import 'transaction_form_screen.dart';
import '../metas/metas_screen.dart';
import 'presupuestos_screen.dart';
import 'movimientos_recurrentes_screen.dart';
import '../reportes/exportar_datos_screen.dart';
import 'transaction_location_card.dart';
import 'transaction_receipt_view.dart';

class FinanzasScreen extends StatefulWidget {
  const FinanzasScreen({
    super.key,
    this.onPrimerIngresoRegistrado,
    this.onFinanzasActivadas,
  });

  final VoidCallback? onPrimerIngresoRegistrado;
  final VoidCallback? onFinanzasActivadas;

  @override
  State<FinanzasScreen> createState() => _FinanzasScreenState();
}

class _FinanzasScreenState extends State<FinanzasScreen> {
  bool _cargando = true;
  bool _finanzasActivas = true;
  bool _activandoFinanzas = false;
  String? _errorCarga;
  List<Map<String, dynamic>> _movimientos = [];
  double _ingresos = 0;
  double _gastos = 0;
  final FinanceRepository _financeRepository = FinanceRepository(supabase);

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
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('A signed-in user is required to load finances.');
      }
      final perfil = await supabase
          .from('perfiles')
          .select('finanzas_activas')
          .eq('id', user.id)
          .single();
      if (perfil['finanzas_activas'] != true) {
        if (mounted) {
          setState(() {
            _finanzasActivas = false;
            _cargando = false;
            _errorCarga = null;
          });
        }
        return;
      }
      final overview = await _financeRepository.loadOverview(user.id);

      if (mounted) {
        setState(() {
          _finanzasActivas = true;
          _movimientos = overview.recentTransactions;
          _ingresos = overview.totals.income;
          _gastos = overview.totals.expenses;
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
    bool guiarHaciaReportes = false,
  }) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          tipoInicial: tipoInicial,
          movimiento: movimiento,
          mostrarGuia: guiarHaciaReportes,
        ),
      ),
    );
    if (resultado == true) {
      await _cargar();
      if (guiarHaciaReportes && mounted) {
        final verReporte = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(Icons.check_circle_outline, color: AppColors.green),
            title: Text(
              appText(
                context,
                '¡Primer ingreso guardado!',
                'First income saved!',
              ),
            ),
            content: Text(
              appText(
                context,
                'Ahora revisa Reportes > Hoy para ver el movimiento. Si registras tus movimientos con constancia, también podrás entender tu comportamiento semanal y mensual.',
                'Now open Reports > Today to see the transaction. With consistent tracking, you will also be able to understand your weekly and monthly patterns.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(appText(context, 'Después', 'Later')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(appText(context, 'Ver Hoy', 'View Today')),
              ),
            ],
          ),
        );
        if (verReporte == true) widget.onPrimerIngresoRegistrado?.call();
      }
    }
  }

  Future<void> _activarFinanzas() async {
    final activar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.account_balance_wallet_outlined),
        title: Text(appText(context, '¿Activar Finanzas?', 'Enable Finance?')),
        content: Text(
          appText(
            context,
            'Podrás registrar ingresos y gastos, consultar balances y usar presupuestos, metas de ahorro y pagos recurrentes. Puedes seguir usando MYD solo para tus tareas si prefieres.',
            'You can record income and expenses, review balances, and use budgets, savings goals, and recurring payments. You can keep using MYD just for tasks if you prefer.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appText(context, 'Ahora no', 'Not now')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(appText(context, 'Activar', 'Enable')),
          ),
        ],
      ),
    );
    if (activar != true || !mounted) return;

    setState(() => _activandoFinanzas = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('A signed-in user is required to enable finances.');
      }
      await supabase
          .from('perfiles')
          .update({'finanzas_activas': true})
          .eq('id', user.id);
      if (!mounted) return;
      setState(() {
        _finanzasActivas = true;
        _activandoFinanzas = false;
      });
      widget.onFinanzasActivadas?.call();
      await _cargar();

      if (!mounted) return;
      final iniciarGuia = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            appText(context, 'Tu primer movimiento', 'Your first transaction'),
          ),
          content: Text(
            appText(
              context,
              'Paso 1: registra un ingreso con su descripción, valor, categoría y fecha. Paso 2: al guardarlo, iremos a Reportes > Hoy para que veas cómo aparece. Más adelante podrás comparar tu actividad semanal y mensual.',
              'Step 1: record income with a description, amount, category, and date. Step 2: after saving, we will open Reports > Today so you can see it. Later, you can compare your weekly and monthly activity.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(appText(context, 'Saltar guía', 'Skip guide')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(appText(context, 'Empezar', 'Start')),
            ),
          ],
        ),
      );
      if (iniciarGuia == true && mounted) {
        await _abrirFormulario(
          tipoInicial: 'ingreso',
          guiarHaciaReportes: true,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _activandoFinanzas = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron activar las finanzas: $error'),
          ),
        );
      }
    }
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
      final comprobante = mov['comprobante_path'] as String?;
      if (comprobante != null) {
        await supabase.storage.from('receipts').remove([comprobante]);
      }
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
          : !_finanzasActivas
          ? _estadoFinanzasDesactivadas()
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

  Widget _estadoFinanzasDesactivadas() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl3),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.goldSoftBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.goldDeep,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                appText(
                  context,
                  'Tus finanzas, a tu ritmo',
                  'Your finances, your choice',
                ),
                style: AppTypography.screenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                appText(
                  context,
                  'Activa esta sección cuando quieras llevar el registro de ingresos, gastos, presupuestos, metas y pagos recurrentes. MYD también funciona para organizar tus tareas y recordatorios.',
                  'Enable this section whenever you want to track income, expenses, budgets, goals, and recurring payments. MYD also works for organizing tasks and reminders.',
                ),
                style: AppTypography.secondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _activandoFinanzas ? null : _activarFinanzas,
                  icon: _activandoFinanzas
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    appText(context, 'Activar Finanzas', 'Enable Finance'),
                  ),
                ),
              ),
            ],
          ),
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

  Future<void> _mostrarDetalleMovimiento(
    Map<String, dynamic> movimiento,
    FinanzasTheme finanzas,
  ) async {
    final esIngreso = movimiento['tipo'] == 'ingreso';
    final color = esIngreso ? finanzas.colorIngreso : finanzas.colorGasto;
    final categoria =
        movimiento['categorias']?['nombre']?.toString() ?? 'Sin categoría';
    final descripcion = movimiento['descripcion']?.toString().trim();
    final fecha = DateTime.parse(movimiento['fecha']);
    final latitud = (movimiento['ubicacion_latitud'] as num?)?.toDouble();
    final longitud = (movimiento['ubicacion_longitud'] as num?)?.toDouble();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl3),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderSoft,
                      borderRadius: BorderRadius.circular(AppRadii.full),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      emojiCategoria(
                        categoria,
                        tipo: esIngreso ? 'ingreso' : 'gasto',
                      ),
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descripcion?.isNotEmpty == true
                                ? descripcion!
                                : categoria,
                            style: AppTypography.screenTitle,
                          ),
                          Text(categoria, style: AppTypography.secondary),
                        ],
                      ),
                    ),
                    Text(
                      '${esIngreso ? '+' : '-'}${formatearMonto(movimiento['monto'])}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detalleFila(
                  Icons.calendar_month_outlined,
                  'Fecha',
                  '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}',
                ),
                const SizedBox(height: 16),
                Text('Ubicación', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                if (movimiento['comprobante_path'] is String) ...[
                  Text('Recibo', style: AppTypography.sectionLabel),
                  const SizedBox(height: 8),
                  TransactionReceiptView(
                    path: movimiento['comprobante_path'] as String,
                  ),
                  const SizedBox(height: 16),
                ],
                if (latitud != null && longitud != null)
                  TransactionLocationCard(
                    latitude: latitud,
                    longitude: longitud,
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.xl2),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_off_outlined,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No se guardó ubicación para este movimiento.',
                            style: AppTypography.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _abrirFormulario(
                      tipoInicial: movimiento['tipo'],
                      movimiento: movimiento,
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar movimiento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detalleFila(IconData icono, String etiqueta, String valor) {
    return Row(
      children: [
        Icon(icono, color: AppColors.goldDeep, size: 19),
        const SizedBox(width: 9),
        Text('$etiqueta: ', style: AppTypography.secondary),
        Expanded(child: Text(valor, style: AppTypography.itemTitle)),
      ],
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
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(finanzas.radioTarjeta),
        child: InkWell(
          borderRadius: BorderRadius.circular(finanzas.radioTarjeta),
          onTap: () => _mostrarDetalleMovimiento(m, finanzas),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                  child: Text(
                    emojiCategoria(
                      categoria,
                      tipo: esIngreso ? 'ingreso' : 'gasto',
                    ),
                    style: const TextStyle(fontSize: 19),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                  tooltip: 'Eliminar movimiento',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
