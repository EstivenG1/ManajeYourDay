import 'package:flutter/material.dart';

import '../../core/services/home_utils.dart';
import '../../core/services/notification_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/formatters/money_input_formatter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/plan_service.dart';
import '../../core/services/guided_tour.dart';
import '../../core/localization/app_text.dart';

class MovimientosRecurrentesScreen extends StatefulWidget {
  const MovimientosRecurrentesScreen({super.key});

  @override
  State<MovimientosRecurrentesScreen> createState() =>
      _MovimientosRecurrentesScreenState();
}

class _MovimientosRecurrentesScreenState
    extends State<MovimientosRecurrentesScreen> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarGuiaInicial());
  }

  Future<void> _mostrarGuiaInicial() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final crear = await mostrarGuiaInicial(
      context: context,
      storageKey: 'guided_recurring_v1_$userId',
      title: appText(
        context,
        'Ingresos y pagos recurrentes',
        'Recurring income and bills',
      ),
      description: appText(
        context,
        'Programa un ingreso o pago con su valor y frecuencia semanal, quincenal o mensual. MYD te recordará la próxima fecha; podrás editarlo, pausarlo o eliminarlo.',
        'Schedule income or a bill with its amount and weekly, biweekly, or monthly frequency. MYD will remind you on the next date; you can edit, pause, or delete it.',
      ),
      startLabel: appText(
        context,
        'Programar movimiento',
        'Schedule transaction',
      ),
    );
    if (crear && mounted) await _form(mostrarGuia: true);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final data = await supabase
          .from('movimientos_recurrentes')
          .select('*, categorias(nombre)')
          .eq('usuario_id', userId)
          .order('proxima_fecha');
      final items = List<Map<String, dynamic>>.from(data);
      for (final item in items.where((item) => item['activo'] == true)) {
        var proxima = DateTime.parse(item['proxima_fecha']);
        final hoy = DateTime.now();
        while (!proxima.isAfter(DateTime(hoy.year, hoy.month, hoy.day))) {
          proxima = _siguienteFecha(proxima, item['frecuencia'] as String);
        }
        if (_fechaIso(proxima) != item['proxima_fecha']) {
          await supabase
              .from('movimientos_recurrentes')
              .update({'proxima_fecha': _fechaIso(proxima)})
              .eq('id', item['id']);
          item['proxima_fecha'] = _fechaIso(proxima);
        }
        await NotificationService.programarRecordatorioFinanciero(
          recurrenciaId: item['id'].toString(),
          tipo: item['tipo'] as String,
          descripcion:
              item['descripcion'] as String? ??
              item['categorias']?['nombre'] as String? ??
              'Movimiento recurrente',
          proximaFecha: proxima,
        );
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los movimientos recurrentes: $error';
        _cargando = false;
      });
    }
  }

  DateTime _siguienteFecha(DateTime fecha, String frecuencia) {
    if (frecuencia == 'semanal') return fecha.add(const Duration(days: 7));
    if (frecuencia == 'quincenal') return fecha.add(const Duration(days: 14));
    final primerDiaSiguiente = DateTime(fecha.year, fecha.month + 1, 1);
    final ultimoDiaSiguiente = DateTime(
      primerDiaSiguiente.year,
      primerDiaSiguiente.month + 1,
      0,
    );
    return DateTime(
      primerDiaSiguiente.year,
      primerDiaSiguiente.month,
      fecha.day.clamp(1, ultimoDiaSiguiente.day).toInt(),
    );
  }

  String _fechaIso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<void> _form({
    Map<String, dynamic>? item,
    bool mostrarGuia = false,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) =>
          _MovimientoRecurrenteForm(item: item, mostrarGuia: mostrarGuia),
    );
    if (saved == true) _cargar();
  }

  Future<void> _cambiarEstado(Map<String, dynamic> item) async {
    final activar = item['activo'] != true;
    try {
      await supabase
          .from('movimientos_recurrentes')
          .update({'activo': activar})
          .eq('id', item['id']);
      if (activar) {
        await NotificationService.programarRecordatorioFinanciero(
          recurrenciaId: item['id'].toString(),
          tipo: item['tipo'] as String,
          descripcion:
              item['descripcion'] as String? ??
              item['categorias']?['nombre'] as String? ??
              'Movimiento recurrente',
          proximaFecha: DateTime.parse(item['proxima_fecha']),
        );
      } else {
        await NotificationService.cancelarRecordatorioFinanciero(
          item['id'].toString(),
        );
      }
      _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo actualizar: ${PlanService.errorMessage(error)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _eliminar(Map<String, dynamic> item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar programación?'),
        content: const Text('Se quitará el recordatorio recurrente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await supabase
          .from('movimientos_recurrentes')
          .delete()
          .eq('id', item['id']);
      await NotificationService.cancelarRecordatorioFinanciero(
        item['id'].toString(),
      );
      _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos recurrentes')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recurring-create',
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: () => _form(),
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
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
              onRefresh: _cargar,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(
                            'Programa recordatorios para ingresos o pagos periódicos.',
                            textAlign: TextAlign.center,
                            style: AppTypography.secondary,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                      itemCount: _items.length,
                      itemBuilder: (context, index) => _tarjeta(_items[index]),
                    ),
            ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> item) {
    final ingreso = item['tipo'] == 'ingreso';
    final activo = item['activo'] == true;
    final color = ingreso ? AppColors.green : AppColors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          ingreso ? Icons.arrow_downward : Icons.arrow_upward,
          color: activo ? color : AppColors.textTertiary,
        ),
        title: Text(
          (item['descripcion'] as String?)?.trim().isNotEmpty == true
              ? item['descripcion'] as String
              : item['categorias']?['nombre'] as String? ?? 'Movimiento',
        ),
        subtitle: Text(
          '${formatearMonto(item['monto'])} · ${item['frecuencia']} · '
          'Próximo: ${item['proxima_fecha']}'
          '${activo ? '' : ' · Pausado'}',
        ),
        onTap: () => _form(item: item),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'estado') _cambiarEstado(item);
            if (action == 'eliminar') _eliminar(item);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'estado',
              child: Text(activo ? 'Pausar' : 'Activar'),
            ),
            const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}

class _MovimientoRecurrenteForm extends StatefulWidget {
  const _MovimientoRecurrenteForm({this.item, this.mostrarGuia = false});
  final Map<String, dynamic>? item;
  final bool mostrarGuia;

  @override
  State<_MovimientoRecurrenteForm> createState() =>
      _MovimientoRecurrenteFormState();
}

class _MovimientoRecurrenteFormState extends State<_MovimientoRecurrenteForm> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  final _tipoKey = GlobalKey();
  final _montoKey = GlobalKey();
  final _categoriaKey = GlobalKey();
  final _descripcionKey = GlobalKey();
  final _frecuenciaKey = GlobalKey();
  final _fechaKey = GlobalKey();
  final _guardarKey = GlobalKey();
  final _montoFocusNode = FocusNode();
  List<Map<String, dynamic>> _categorias = [];
  String _tipo = 'gasto';
  String _frecuencia = 'mensual';
  int? _categoriaId;
  DateTime _proxima = DateTime.now().add(const Duration(days: 1));
  bool _cargando = true;
  bool _guardando = false;
  bool _guiaIniciada = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _tipo = item['tipo'] as String;
      _frecuencia = item['frecuencia'] as String;
      _categoriaId = item['categoria_id'] as int;
      _proxima = DateTime.parse(item['proxima_fecha']);
      _monto.text = formatearMontoParaCampo(item['monto'] as num);
      _descripcion.text = item['descripcion'] as String? ?? '';
    }
    _cargarCategorias();
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    _montoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final data = await supabase
          .from('categorias')
          .select('id, nombre')
          .eq('tipo', _tipo)
          .or('usuario_id.is.null,usuario_id.eq.$userId')
          .order('nombre');
      if (!mounted) return;
      setState(() {
        _categorias = List<Map<String, dynamic>>.from(data);
        _categoriaId ??= _categorias.isEmpty
            ? null
            : _categorias.first['id'] as int;
        _cargando = false;
      });
      _programarGuia();
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las categorías: $error')),
      );
    }
  }

  void _programarGuia() {
    if (!widget.mostrarGuia || _guiaIniciada || _categorias.isEmpty) return;
    _guiaIniciada = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _mostrarGuiaFormulario();
    });
  }

  Future<void> _mostrarGuiaFormulario() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    await mostrarTourGuiado(
      context: context,
      storageKey: 'guided_recurring_form_v1_$userId',
      force: true,
      steps: [
        TutorialStep(
          title: appText(context, 'Elige el tipo', 'Choose a type'),
          description: appText(
            context,
            'Indica si vas a programar un ingreso o un gasto recurrente.',
            'Choose whether you are scheduling recurring income or an expense.',
          ),
          icon: Icons.swap_vert_rounded,
          color: AppColors.gold,
          target: _tipoKey,
        ),
        TutorialStep(
          title: appText(context, 'Escribe el monto', 'Enter the amount'),
          description: appText(
            context,
            'Indica el valor aproximado de cada movimiento.',
            'Enter the approximate amount for each transaction.',
          ),
          icon: Icons.payments_outlined,
          color: AppColors.gold,
          target: _montoKey,
        ),
        TutorialStep(
          title: appText(
            context,
            'Selecciona la categoría',
            'Choose a category',
          ),
          description: appText(
            context,
            'La categoría ayuda a organizar y revisar tus movimientos.',
            'A category helps organize and review your transactions.',
          ),
          icon: Icons.category_outlined,
          color: AppColors.gold,
          target: _categoriaKey,
        ),
        TutorialStep(
          title: appText(context, 'Añade una descripción', 'Add a description'),
          description: appText(
            context,
            'Es opcional; por ejemplo, puedes indicar para qué es el pago.',
            'This is optional; for example, describe what the payment is for.',
          ),
          icon: Icons.notes_outlined,
          color: AppColors.gold,
          target: _descripcionKey,
        ),
        TutorialStep(
          title: appText(context, 'Elige la frecuencia', 'Choose a frequency'),
          description: appText(
            context,
            'Puedes repetirlo cada semana, quincena o mes.',
            'Set it to repeat weekly, every two weeks, or monthly.',
          ),
          icon: Icons.repeat_rounded,
          color: AppColors.gold,
          target: _frecuenciaKey,
        ),
        TutorialStep(
          title: appText(
            context,
            'Indica la próxima fecha',
            'Set the next date',
          ),
          description: appText(
            context,
            'MYD te recordará un día antes. El movimiento no se registra automáticamente.',
            'MYD will remind you one day ahead. The transaction is not recorded automatically.',
          ),
          icon: Icons.calendar_month_outlined,
          color: AppColors.gold,
          target: _fechaKey,
        ),
        TutorialStep(
          title: appText(
            context,
            'Guarda la programación',
            'Save the schedule',
          ),
          description: appText(
            context,
            'Puedes editar, pausar o eliminar esta programación más adelante.',
            'You can edit, pause, or delete this schedule later.',
          ),
          icon: Icons.check_circle_outline,
          color: AppColors.gold,
          target: _guardarKey,
          nextLabel: appText(context, 'Terminar guía', 'Finish guide'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _categoriaId == null) return;
    setState(() => _guardando = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final datos = {
        'usuario_id': userId,
        'tipo': _tipo,
        'monto': parseMontoEntrada(_monto.text)!,
        'categoria_id': _categoriaId,
        'descripcion': _descripcion.text.trim().isEmpty
            ? null
            : _descripcion.text.trim(),
        'frecuencia': _frecuencia,
        'proxima_fecha':
            '${_proxima.year}-${_proxima.month.toString().padLeft(2, '0')}-${_proxima.day.toString().padLeft(2, '0')}',
      };
      dynamic resultado;
      if (widget.item == null) {
        await PlanService.ensureCanCreate(PlanResource.activeRecurring);
        resultado = await supabase
            .from('movimientos_recurrentes')
            .insert(datos)
            .select('id')
            .single();
      } else {
        await supabase
            .from('movimientos_recurrentes')
            .update(datos)
            .eq('id', widget.item!['id']);
        resultado = {'id': widget.item!['id']};
      }
      await NotificationService.cancelarRecordatorioFinanciero(
        resultado['id'].toString(),
      );
      await NotificationService.programarRecordatorioFinanciero(
        recurrenciaId: resultado['id'].toString(),
        tipo: _tipo,
        descripcion: _descripcion.text.trim().isEmpty
            ? _categorias.firstWhere((c) => c['id'] == _categoriaId)['nombre']
                  as String
            : _descripcion.text.trim(),
        proximaFecha: _proxima,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar: ${PlanService.errorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.item == null
                            ? 'Programar movimiento'
                            : 'Editar programación',
                        style: AppTypography.screenTitle,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        key: _tipoKey,
                        segments: const [
                          ButtonSegment(value: 'gasto', label: Text('Gasto')),
                          ButtonSegment(
                            value: 'ingreso',
                            label: Text('Ingreso'),
                          ),
                        ],
                        selected: {_tipo},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _tipo = selection.first;
                            _categoriaId = null;
                            _cargando = true;
                          });
                          _cargarCategorias();
                        },
                      ),
                      const SizedBox(height: 12),
                      MoneyTextFormField(
                        key: _montoKey,
                        controller: _monto,
                        focusNode: _montoFocusNode,
                        decoration: const InputDecoration(labelText: 'Monto'),
                        validator: (value) {
                          final amount = parseMontoEntrada(value ?? '');
                          return amount == null || amount <= 0
                              ? 'Ingresa un monto mayor que cero'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: _categoriaKey,
                        initialValue: _categoriaId,
                        decoration: const InputDecoration(
                          labelText: 'Categoría',
                        ),
                        items: _categorias
                            .map(
                              (item) => DropdownMenuItem(
                                value: item['id'] as int,
                                child: Text(item['nombre'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoriaId = value),
                        validator: (value) =>
                            value == null ? 'Elige una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: _descripcionKey,
                        controller: _descripcion,
                        decoration: const InputDecoration(
                          labelText: 'Descripción opcional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: _frecuenciaKey,
                        initialValue: _frecuencia,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'semanal',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'quincenal',
                            child: Text('Quincenal'),
                          ),
                          DropdownMenuItem(
                            value: 'mensual',
                            child: Text('Mensual'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _frecuencia = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: _fechaKey,
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _proxima,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 3650),
                            ),
                          );
                          if (selected != null) {
                            setState(() => _proxima = selected);
                          }
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Próxima fecha: ${_proxima.day}/${_proxima.month}/${_proxima.year}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MYD te avisará el día anterior. El movimiento no se registra automáticamente.',
                        style: AppTypography.secondary,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: _guardarKey,
                        onPressed: _guardando ? null : _guardar,
                        child: Text(_guardando ? 'Guardando…' : 'Guardar'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
