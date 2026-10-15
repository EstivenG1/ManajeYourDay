import 'package:flutter/material.dart';

import '../../core/services/home_utils.dart';
import '../../core/services/notification_service.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

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
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
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
          descripcion: item['descripcion'] as String? ??
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
        _error =
            'No se pudieron cargar los movimientos recurrentes: $error';
        _cargando = false;
      });
    }
  }

  DateTime _siguienteFecha(DateTime fecha, String frecuencia) {
    if (frecuencia == 'semanal') return fecha.add(const Duration(days: 7));
    if (frecuencia == 'quincenal') return fecha.add(const Duration(days: 14));
    final primerDiaSiguiente = DateTime(fecha.year, fecha.month + 1, 1);
    final ultimoDiaSiguiente =
        DateTime(primerDiaSiguiente.year, primerDiaSiguiente.month + 1, 0);
    return DateTime(
      primerDiaSiguiente.year,
      primerDiaSiguiente.month,
      fecha.day.clamp(1, ultimoDiaSiguiente.day).toInt(),
    );
  }

  String _fechaIso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<void> _form({Map<String, dynamic>? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _MovimientoRecurrenteForm(item: item),
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
          descripcion: item['descripcion'] as String? ??
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
          SnackBar(content: Text('No se pudo actualizar: $error')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos recurrentes')),
      floatingActionButton: FloatingActionButton(
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
                          itemBuilder: (context, index) =>
                              _tarjeta(_items[index]),
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
  const _MovimientoRecurrenteForm({this.item});
  final Map<String, dynamic>? item;

  @override
  State<_MovimientoRecurrenteForm> createState() =>
      _MovimientoRecurrenteFormState();
}

class _MovimientoRecurrenteFormState
    extends State<_MovimientoRecurrenteForm> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();
  List<Map<String, dynamic>> _categorias = [];
  String _tipo = 'gasto';
  String _frecuencia = 'mensual';
  int? _categoriaId;
  DateTime _proxima = DateTime.now().add(const Duration(days: 1));
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _tipo = item['tipo'] as String;
      _frecuencia = item['frecuencia'] as String;
      _categoriaId = item['categoria_id'] as int;
      _proxima = DateTime.parse(item['proxima_fecha']);
      _monto.text = item['monto'].toString();
      _descripcion.text = item['descripcion'] as String? ?? '';
    }
    _cargarCategorias();
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('categorias')
          .select('id, nombre')
          .eq('tipo', _tipo)
          .or('usuario_id.is.null,usuario_id.eq.$userId')
          .order('nombre');
      if (!mounted) return;
      setState(() {
        _categorias = List<Map<String, dynamic>>.from(data);
        _categoriaId ??=
            _categorias.isEmpty ? null : _categorias.first['id'] as int;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar las categorías: $error')),
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _categoriaId == null) return;
    setState(() => _guardando = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'usuario_id': userId,
        'tipo': _tipo,
        'monto': double.parse(_monto.text.replaceAll(',', '.')),
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
          SnackBar(content: Text('No se pudo guardar: $error')),
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
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
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
                        segments: const [
                          ButtonSegment(value: 'gasto', label: Text('Gasto')),
                          ButtonSegment(value: 'ingreso', label: Text('Ingreso')),
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
                      TextFormField(
                        controller: _monto,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Monto'),
                        validator: (value) {
                          final amount = double.tryParse(
                            (value ?? '').replaceAll(',', '.'),
                          );
                          return amount == null || amount <= 0
                              ? 'Ingresa un monto mayor que cero'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _categoriaId,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((item) => DropdownMenuItem(
                                  value: item['id'] as int,
                                  child: Text(item['nombre'] as String),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _categoriaId = value),
                        validator: (value) =>
                            value == null ? 'Elige una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descripcion,
                        decoration: const InputDecoration(
                          labelText: 'Descripción opcional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _frecuencia,
                        decoration: const InputDecoration(labelText: 'Frecuencia'),
                        items: const [
                          DropdownMenuItem(
                              value: 'semanal', child: Text('Semanal')),
                          DropdownMenuItem(
                              value: 'quincenal', child: Text('Quincenal')),
                          DropdownMenuItem(
                              value: 'mensual', child: Text('Mensual')),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _frecuencia = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
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
