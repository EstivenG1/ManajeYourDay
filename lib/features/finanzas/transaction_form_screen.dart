import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/sugerencias_service.dart';

class TransactionFormScreen extends StatefulWidget {
  final String tipoInicial; // 'ingreso' o 'gasto'
  final Map<String, dynamic>? movimiento; // si viene, se está editando

  const TransactionFormScreen({super.key, required this.tipoInicial, this.movimiento});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  TextEditingController? _descripcionCtrl;

  late String _tipo;
  DateTime _fecha = DateTime.now();
  int? _categoriaId;
  bool _cargando = true;

  List<Map<String, dynamic>> _categorias = [];
  List<String> _sugerenciasDescripcion = [];

  bool get _editando => widget.movimiento != null;

  @override
  void initState() {
    super.initState();
    _tipo = widget.movimiento?['tipo'] ?? widget.tipoInicial;
    if (widget.movimiento != null) {
      _montoCtrl.text = (widget.movimiento!['monto'] as num).toString();
      _fecha = DateTime.parse(widget.movimiento!['fecha']);
      _categoriaId = widget.movimiento!['categoria_id'];
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final categorias = await supabase
          .from('categorias')
          .select()
          .or('usuario_id.is.null,usuario_id.eq.${supabase.auth.currentUser!.id}')
          .eq('tipo', _tipo)
          .order('nombre');

      final sugerencias = await SugerenciasService.obtener('gasto_descripcion');

      if (mounted) {
        setState(() {
          _categorias = List<Map<String, dynamic>>.from(categorias);
          _sugerenciasDescripcion = sugerencias;
          _categoriaId ??= _categorias.isNotEmpty ? _categorias.first['id'] as int : null;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (seleccion != null) setState(() => _fecha = seleccion);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Elige una categoría')));
      return;
    }

    setState(() => _cargando = true);
    final descripcion = _descripcionCtrl?.text.trim() ?? '';
    final monto = double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;

    try {
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'tipo': _tipo,
        'monto': monto,
        'categoria_id': _categoriaId,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'fecha': '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
      };

      if (_editando) {
        await supabase.from('movimientos').update(datos).eq('id', widget.movimiento!['id']);
      } else {
        await supabase.from('movimientos').insert({...datos, 'usuario_id': userId});
      }

      if (descripcion.isNotEmpty) {
        await SugerenciasService.registrarUso('gasto_descripcion', descripcion);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finanzas = Theme.of(context).extension<FinanzasTheme>()!;
    final esIngreso = _tipo == 'ingreso';
    final colorActivo = esIngreso ? finanzas.colorIngreso : finanzas.colorGasto;
    final gradienteActivo = esIngreso ? finanzas.gradienteBotonIngreso : finanzas.gradienteBotonGasto;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(_editando ? 'Editar movimiento' : 'Nuevo movimiento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Selector Ingreso / Gasto
                Row(
                  children: [
                    Expanded(
                      child: _selectorTipo('Ingreso', 'ingreso', finanzas.colorIngreso),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectorTipo('Gasto', 'gasto', finanzas.colorGasto),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('MONTO', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.balanceDisplay.copyWith(fontSize: 28, color: colorActivo),
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Ingresa un monto válido';
                    return null;
                  },
                ),
                const SizedBox(height: 22),

                Text('CATEGORÍA', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                _cargando
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categorias.map((c) {
                          final activa = _categoriaId == c['id'];
                          return GestureDetector(
                            onTap: () => setState(() => _categoriaId = c['id']),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: activa
                                    ? (esIngreso ? finanzas.chipIngresoBg : finanzas.chipGastoBg)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(finanzas.radioChip),
                                border: Border.all(
                                  color: activa
                                      ? (esIngreso ? finanzas.chipIngresoBorder : finanzas.chipGastoBorder)
                                      : AppColors.borderSoft,
                                  width: AppRadii.borderWidth,
                                ),
                              ),
                              child: Text(c['nombre'],
                                  style: TextStyle(
                                    color: activa ? colorActivo : AppColors.textSecondary,
                                    fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13,
                                  )),
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 22),

                Text('DESCRIPCIÓN (opcional)', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                _campoDescripcionConAutocompletado(),
                const SizedBox(height: 22),

                Text('FECHA', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.xl2),
                  onTap: _elegirFecha,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.xl2),
                      border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                          style: AppTypography.itemTitle,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: gradienteActivo,
                      borderRadius: BorderRadius.circular(AppRadii.xl2),
                      boxShadow: AppColors.sombraPremium(colorActivo),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.xl2),
                        onTap: _cargando ? null : _guardar,
                        child: Center(
                          child: _cargando
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : Text(_editando ? 'Guardar cambios' : 'Guardar ${esIngreso ? 'ingreso' : 'gasto'}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectorTipo(String texto, String valor, Color color) {
    final activo = _tipo == valor;
    return GestureDetector(
      onTap: () => setState(() {
        _tipo = valor;
        _categoriaId = null;
        _cargando = true;
        _cargarDatos();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: activo ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: activo ? color : AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
        child: Center(
          child: Text(texto,
              style: TextStyle(
                color: activo ? color : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    );
  }

  Widget _campoDescripcionConAutocompletado() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.movimiento?['descripcion'] ?? ''),
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return _sugerenciasDescripcion.take(5);
        return _sugerenciasDescripcion.where((s) => s.toLowerCase().contains(value.text.toLowerCase()));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _descripcionCtrl = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(hintText: 'Ej: Almuerzo con el equipo'),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            elevation: 4,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.xl2),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opcion = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, color: AppColors.gold, size: 18),
                    title: Text(opcion, style: AppTypography.itemTitle),
                    onTap: () => onSelected(opcion),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
