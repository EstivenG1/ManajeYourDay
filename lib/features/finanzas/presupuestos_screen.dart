import 'package:flutter/material.dart';

import '../../core/services/home_utils.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class PresupuestosScreen extends StatefulWidget {
  const PresupuestosScreen({super.key});

  @override
  State<PresupuestosScreen> createState() => _PresupuestosScreenState();
}

class _PresupuestosScreenState extends State<PresupuestosScreen> {
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _presupuestos = [];
  Map<String, double> _gastos = {};

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
      final rows = await supabase
          .from('presupuestos')
          .select('*, categorias(nombre)')
          .eq('usuario_id', userId)
          .order('fecha_inicio', ascending: false);
      final presupuestos = List<Map<String, dynamic>>.from(rows);
      final gastos = <String, double>{};
      for (final presupuesto in presupuestos) {
        var total = 0.0;
        const tamanoPagina = 500;
        for (var inicio = 0;; inicio += tamanoPagina) {
          final movimientos = await supabase
              .from('movimientos')
              .select('monto')
              .eq('usuario_id', userId)
              .eq('categoria_id', presupuesto['categoria_id'])
              .eq('tipo', 'gasto')
              .gte('fecha', presupuesto['fecha_inicio'])
              .lte('fecha', presupuesto['fecha_fin'])
              .order('id')
              .range(inicio, inicio + tamanoPagina - 1);
          total += (movimientos as List).fold<double>(
            0,
            (subtotal, movimiento) =>
                subtotal + (movimiento['monto'] as num).toDouble(),
          );
          if (movimientos.length < tamanoPagina) break;
        }
        gastos[presupuesto['id'].toString()] = total;
      }
      if (!mounted) return;
      setState(() {
        _presupuestos = presupuestos;
        _gastos = gastos;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los presupuestos: $error';
        _cargando = false;
      });
    }
  }

  Future<void> _editar({Map<String, dynamic>? presupuesto}) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _PresupuestoForm(presupuesto: presupuesto),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> presupuesto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar presupuesto?'),
        content: Text(
          'Se eliminará el límite de ${presupuesto['categorias']?['nombre'] ?? 'esta categoría'}.',
        ),
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
      await supabase.from('presupuestos').delete().eq('id', presupuesto['id']);
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
      appBar: AppBar(title: const Text('Presupuestos')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: () => _editar(),
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: _presupuestos.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'Aún no tienes presupuestos.\nCrea uno para controlar tus gastos.',
                                textAlign: TextAlign.center,
                                style: AppTypography.secondary,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: _presupuestos.length,
                          itemBuilder: (context, index) {
                            final item = _presupuestos[index];
                            return _tarjeta(item);
                          },
                        ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
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

  Widget _tarjeta(Map<String, dynamic> presupuesto) {
    final limite = (presupuesto['monto_limite'] as num).toDouble();
    final gastado = _gastos[presupuesto['id'].toString()] ?? 0;
    final progreso = limite <= 0 ? 0.0 : (gastado / limite).clamp(0.0, 1.0);
    final excedido = gastado > limite;
    final color = excedido ? AppColors.red : AppColors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    presupuesto['categorias']?['nombre'] ?? 'Categoría',
                    style: AppTypography.itemTitle,
                  ),
                ),
                IconButton(
                  tooltip: 'Editar presupuesto',
                  onPressed: () => _editar(presupuesto: presupuesto),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar presupuesto',
                  onPressed: () => _eliminar(presupuesto),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              '${presupuesto['fecha_inicio']} – ${presupuesto['fecha_fin']}',
              style: AppTypography.secondary,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progreso,
              color: color,
              backgroundColor: AppColors.borderSoft,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatearMonto(gastado)} de ${formatearMonto(limite)} · '
              '${excedido ? 'Excedido por ${formatearMonto(gastado - limite)}' : 'Disponible ${formatearMonto(limite - gastado)}'}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresupuestoForm extends StatefulWidget {
  const _PresupuestoForm({this.presupuesto});

  final Map<String, dynamic>? presupuesto;

  @override
  State<_PresupuestoForm> createState() => _PresupuestoFormState();
}

class _PresupuestoFormState extends State<_PresupuestoForm> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController();
  List<Map<String, dynamic>> _categorias = [];
  int? _categoria;
  late DateTime _inicio;
  late DateTime _fin;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _inicio = widget.presupuesto == null
        ? DateTime(now.year, now.month, 1)
        : DateTime.parse(widget.presupuesto!['fecha_inicio']);
    _fin = widget.presupuesto == null
        ? DateTime(now.year, now.month + 1, 0)
        : DateTime.parse(widget.presupuesto!['fecha_fin']);
    _categoria = widget.presupuesto?['categoria_id'] as int?;
    _monto.text = widget.presupuesto?['monto_limite']?.toString() ?? '';
    _cargarCategorias();
  }

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('categorias')
          .select('id, nombre')
          .eq('tipo', 'gasto')
          .or('usuario_id.is.null,usuario_id.eq.$userId')
          .order('nombre');
      if (!mounted) return;
      setState(() {
        _categorias = List<Map<String, dynamic>>.from(data);
        _categoria ??=
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

  Future<void> _seleccionarFecha({required bool inicio}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: inicio ? _inicio : _fin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha == null) return;
    setState(() {
      if (inicio) {
        _inicio = fecha;
        if (_fin.isBefore(_inicio)) _fin = _inicio;
      } else {
        _fin = fecha;
        if (_inicio.isAfter(_fin)) _inicio = _fin;
      }
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _categoria == null) return;
    setState(() => _guardando = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      var solapados = supabase
          .from('presupuestos')
          .select('id')
          .eq('usuario_id', userId)
          .eq('categoria_id', _categoria!)
          .lte('fecha_inicio', _fechaIso(_fin))
          .gte('fecha_fin', _fechaIso(_inicio));
      if (widget.presupuesto != null) {
        solapados = solapados.neq('id', widget.presupuesto!['id']);
      }
      final existente = await solapados.maybeSingle();
      if (existente != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ya existe un presupuesto de esta categoría que se cruza con ese periodo.',
              ),
            ),
          );
        }
        return;
      }
      final datos = {
        'usuario_id': userId,
        'categoria_id': _categoria,
        'monto_limite': double.parse(_monto.text.replaceAll(',', '.')),
        'fecha_inicio': _fechaIso(_inicio),
        'fecha_fin': _fechaIso(_fin),
      };
      if (widget.presupuesto == null) {
        await supabase.from('presupuestos').insert(datos);
      } else {
        await supabase
            .from('presupuestos')
            .update(datos)
            .eq('id', widget.presupuesto!['id']);
      }
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

  String _fechaIso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

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
                        widget.presupuesto == null
                            ? 'Nuevo presupuesto'
                            : 'Editar presupuesto',
                        style: AppTypography.screenTitle,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _categoria,
                        decoration: const InputDecoration(labelText: 'Categoría'),
                        items: _categorias
                            .map((item) => DropdownMenuItem(
                                  value: item['id'] as int,
                                  child: Text(item['nombre'] as String),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _categoria = value),
                        validator: (value) =>
                            value == null ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _monto,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Límite de gasto',
                        ),
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
                      OutlinedButton.icon(
                        onPressed: () => _seleccionarFecha(inicio: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Desde ${_fechaIso(_inicio)}'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _seleccionarFecha(inicio: false),
                        icon: const Icon(Icons.event),
                        label: Text('Hasta ${_fechaIso(_fin)}'),
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
