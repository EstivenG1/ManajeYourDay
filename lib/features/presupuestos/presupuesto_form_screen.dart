import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';

class PresupuestoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? presupuesto;
  const PresupuestoFormScreen({super.key, this.presupuesto});

  @override
  State<PresupuestoFormScreen> createState() => _PresupuestoFormScreenState();
}

class _PresupuestoFormScreenState extends State<PresupuestoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limiteCtrl = TextEditingController();

  int? _categoriaId; // null = presupuesto general
  String _periodo = 'mensual';
  late DateTime _fechaInicio;
  late DateTime _fechaFin;

  List<Map<String, dynamic>> _categorias = [];
  bool _cargando = true;
  bool _guardando = false;

  bool get _editando => widget.presupuesto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.presupuesto;
    if (p != null) {
      _limiteCtrl.text = (p['monto_limite'] as num).toString();
      _categoriaId = p['categoria_id'];
      _periodo = p['periodo'] ?? 'mensual';
      _fechaInicio = DateTime.parse(p['fecha_inicio']);
      _fechaFin = DateTime.parse(p['fecha_fin']);
    } else {
      final hoy = DateTime.now();
      _fechaInicio = DateTime(hoy.year, hoy.month, 1);
      _fechaFin = DateTime(hoy.year, hoy.month + 1, 0); // último día del mes
    }
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('categorias')
          .select()
          .or('usuario_id.is.null,usuario_id.eq.$userId')
          .eq('tipo', 'gasto')
          .order('nombre');
      if (mounted) {
        setState(() {
          _categorias = List<Map<String, dynamic>>.from(data);
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _limiteCtrl.dispose();
    super.dispose();
  }

  /// Ajusta la fecha fin automáticamente según el periodo elegido,
  /// para que el usuario no tenga que calcularla a mano.
  void _recalcularFechaFin() {
    setState(() {
      if (_periodo == 'semanal') {
        _fechaFin = _fechaInicio.add(const Duration(days: 6));
      } else {
        _fechaFin = DateTime(_fechaInicio.year, _fechaInicio.month + 1, 0);
      }
    });
  }

  Future<void> _elegirFechaInicio() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (seleccion != null) {
      setState(() => _fechaInicio = seleccion);
      _recalcularFechaFin();
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    try {
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'categoria_id': _categoriaId,
        'monto_limite': double.parse(_limiteCtrl.text.replaceAll(',', '.')),
        'periodo': _periodo,
        'fecha_inicio': fmt(_fechaInicio),
        'fecha_fin': fmt(_fechaFin),
      };

      if (_editando) {
        await supabase.from('presupuestos').update(datos).eq('id', widget.presupuesto!['id']);
      } else {
        await supabase.from('presupuestos').insert({...datos, 'usuario_id': userId});
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmtVisual(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(_editando ? 'Editar presupuesto' : 'Nuevo presupuesto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('LÍMITE DE GASTO', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _limiteCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.balanceDisplay.copyWith(fontSize: 28, color: AppColors.red),
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
                if (_cargando)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chipCategoria('Todas (general)', null),
                      ..._categorias.map((c) => _chipCategoria(c['nombre'], c['id'] as int)),
                    ],
                  ),
                const SizedBox(height: 22),

                Text('PERIODO', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _chipPeriodo('Mensual', 'mensual')),
                    const SizedBox(width: 10),
                    Expanded(child: _chipPeriodo('Semanal', 'semanal')),
                  ],
                ),
                const SizedBox(height: 22),

                Text('DESDE', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.xl2),
                  onTap: _elegirFechaInicio,
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
                        Text(fmtVisual(_fechaInicio), style: AppTypography.itemTitle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoftBg,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available, color: AppColors.goldDeep, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Este presupuesto vence el ${fmtVisual(_fechaFin)}',
                            style: AppTypography.secondary.copyWith(color: AppColors.goldDeep, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(AppRadii.xl2),
                      boxShadow: AppColors.sombraPremium(AppColors.gold),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.xl2),
                        onTap: _guardando ? null : _guardar,
                        child: Center(
                          child: _guardando
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : Text(_editando ? 'Guardar cambios' : 'Crear presupuesto',
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

  Widget _chipCategoria(String nombre, int? id) {
    final activo = _categoriaId == id;
    return GestureDetector(
      onTap: () => setState(() => _categoriaId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? AppColors.redChipBg : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: activo ? AppColors.redChipBorder : AppColors.borderSoft,
            width: AppRadii.borderWidth,
          ),
        ),
        child: Text(nombre,
            style: TextStyle(
              color: activo ? AppColors.red : AppColors.textSecondary,
              fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            )),
      ),
    );
  }

  Widget _chipPeriodo(String texto, String valor) {
    final activo = _periodo == valor;
    return GestureDetector(
      onTap: () {
        setState(() => _periodo = valor);
        _recalcularFechaFin();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: activo ? AppColors.goldChipBg : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(
            color: activo ? AppColors.gold : AppColors.borderSoft,
            width: AppRadii.borderWidth,
          ),
        ),
        child: Center(
          child: Text(texto,
              style: TextStyle(
                color: activo ? AppColors.goldDeep : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    );
  }
}
