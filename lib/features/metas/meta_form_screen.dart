import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/notification_service.dart';

const _iconosDisponibles = ['🎯', '🏖️', '🚗', '🏠', '🎓', '💍', '📱', '✈️', '🎁', '💻'];

class MetaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? meta;
  const MetaFormScreen({super.key, this.meta});

  @override
  State<MetaFormScreen> createState() => _MetaFormScreenState();
}

class _MetaFormScreenState extends State<MetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();
  final _aporteCtrl = TextEditingController();
  DateTime? _fechaLimite;
  String _icono = '🎯';
  String _frecuenciaAporte = 'mensual';
  bool _guardando = false;

  bool get _editando => widget.meta != null;

  @override
  void initState() {
    super.initState();
    if (widget.meta != null) {
      _nombreCtrl.text = widget.meta!['nombre'] ?? '';
      _objetivoCtrl.text = (widget.meta!['monto_objetivo'] as num).toString();
      _aporteCtrl.text =
          (widget.meta!['aporte_programado'] as num?)?.toString() ?? '';
      _frecuenciaAporte =
          widget.meta!['frecuencia_aporte'] as String? ?? 'mensual';
      _icono = widget.meta!['icono'] ?? '🎯';
      if (widget.meta!['fecha_limite'] != null) {
        _fechaLimite = DateTime.parse(widget.meta!['fecha_limite']);
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _objetivoCtrl.dispose();
    _aporteCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaLimite ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (seleccion != null) setState(() => _fechaLimite = seleccion);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'monto_objetivo': double.parse(_objetivoCtrl.text.replaceAll(',', '.')),
        'icono': _icono,
        'aporte_programado': double.tryParse(
              _aporteCtrl.text.replaceAll(',', '.'),
            ) ??
            0,
        'frecuencia_aporte': _frecuenciaAporte,
        'proximo_aporte': _aporteCtrl.text.trim().isEmpty
            ? null
            : _fechaProximoAporte(DateTime.now(), _frecuenciaAporte)
                .toIso8601String()
                .split('T')
                .first,
        'fecha_limite': _fechaLimite != null
            ? '${_fechaLimite!.year}-${_fechaLimite!.month.toString().padLeft(2, '0')}-${_fechaLimite!.day.toString().padLeft(2, '0')}'
            : null,
      };

      late String metaId;
      if (_editando) {
        metaId = widget.meta!['id'].toString();
        await supabase
            .from('metas_ahorro')
            .update(datos)
            .eq('id', metaId);
      } else {
        final creada = await supabase
            .from('metas_ahorro')
            .insert({
              ...datos,
              'usuario_id': userId,
              'monto_actual': 0,
              'estado': 'activa',
            })
            .select('id')
            .single();
        metaId = creada['id'].toString();
      }

      if ((datos['aporte_programado'] as double) > 0) {
        await NotificationService.programarRecordatorioMeta(
          metaId: metaId,
          nombre: datos['nombre'] as String,
          aporte: datos['aporte_programado'] as double,
          frecuencia: _frecuenciaAporte,
          proximoAporte: DateTime.parse(datos['proximo_aporte'] as String),
        );
      } else {
        await NotificationService.cancelarRecordatorioMeta(metaId);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  DateTime _fechaProximoAporte(DateTime desde, String frecuencia) {
    if (frecuencia == 'semanal') return desde.add(const Duration(days: 7));
    if (frecuencia == 'quincenal') return desde.add(const Duration(days: 14));
    final primerDia = DateTime(desde.year, desde.month + 1, 1);
    final ultimoDia = DateTime(primerDia.year, primerDia.month + 1, 0).day;
    return DateTime(
      primerDia.year,
      primerDia.month,
      desde.day.clamp(1, ultimoDia).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(_editando ? 'Editar meta' : 'Nueva meta de ahorro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('ÍCONO', style: AppTypography.sectionLabel),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _iconosDisponibles.map((i) {
                    final activo = _icono == i;
                    return GestureDetector(
                      onTap: () => setState(() => _icono = i),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: activo ? AppColors.goldChipBg : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                          border: Border.all(color: activo ? AppColors.gold : AppColors.borderSoft),
                        ),
                        alignment: Alignment.center,
                        child: Text(i, style: const TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                Text('NOMBRE DE LA META', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(hintText: 'Ej: Vacaciones en diciembre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ponle un nombre' : null,
                ),
                const SizedBox(height: 20),

                Text('MONTO OBJETIVO', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _objetivoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: AppTypography.balanceDisplay.copyWith(fontSize: 26, color: AppColors.goldDeep),
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Ingresa un monto válido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Text('APORTE PROGRAMADO (opcional)', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _aporteCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final amount = double.tryParse(value.replaceAll(',', '.'));
                    return amount == null || amount < 0
                        ? 'Ingresa un aporte válido'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frecuenciaAporte,
                  decoration: const InputDecoration(labelText: 'Frecuencia del aporte'),
                  items: const [
                    DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                    DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                    DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _frecuenciaAporte = value);
                  },
                ),
                const SizedBox(height: 20),

                Text('FECHA LÍMITE (opcional)', style: AppTypography.sectionLabel),
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
                        Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _fechaLimite == null
                              ? 'Sin fecha límite'
                              : '${_fechaLimite!.day.toString().padLeft(2, '0')}/${_fechaLimite!.month.toString().padLeft(2, '0')}/${_fechaLimite!.year}',
                          style: AppTypography.itemTitle,
                        ),
                        if (_fechaLimite != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _fechaLimite = null),
                            child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                          ),
                        ],
                      ],
                    ),
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
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                              : Text(_editando ? 'Guardar cambios' : 'Crear meta',
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
}
