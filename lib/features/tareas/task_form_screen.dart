import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/sugerencias_service.dart';
import '../../core/services/notification_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic>? tarea;
  const TaskFormScreen({super.key, this.tarea});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descripcionCtrl = TextEditingController();
  TextEditingController? _tituloCtrl;

  late DateTime _fecha;
  late TimeOfDay _hora;
  String _prioridad = 'media';
  bool _guardando = true;

  List<String> _sugerenciasTitulo = [];
  List<String> _sugerenciasHora = [];

  bool get _editando => widget.tarea != null;

  @override
  void initState() {
    super.initState();
    final tarea = widget.tarea;

    if (tarea != null) {
      final fechaLimite = DateTime.parse(tarea['fecha_limite']);
      _fecha = fechaLimite;
      _hora = TimeOfDay(hour: fechaLimite.hour, minute: fechaLimite.minute);
      _descripcionCtrl.text = tarea['descripcion'] ?? '';
      _prioridad = tarea['prioridad'] ?? 'media';
    } else {
      final ahora = DateTime.now();
      _fecha = ahora;
      _hora = TimeOfDay(hour: (ahora.hour + 1) % 24, minute: 0);
    }

    _cargarSugerencias();
  }

  Future<void> _cargarSugerencias() async {
    final titulos = await SugerenciasService.obtener('tarea_titulo');
    final horas = await SugerenciasService.obtener('tarea_hora', limite: 6);
    if (mounted) {
      setState(() {
        _sugerenciasTitulo = titulos;
        _sugerenciasHora = horas;
        _guardando = false;
      });
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (seleccion != null) setState(() => _fecha = seleccion);
  }

  Future<void> _elegirHora() async {
    final seleccion = await showTimePicker(context: context, initialTime: _hora);
    if (seleccion != null) setState(() => _hora = seleccion);
  }

  String _formatearHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final titulo = (_tituloCtrl?.text ?? '').trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ponle un título a la tarea')));
      return;
    }

    setState(() => _guardando = true);
    final fechaLimite = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);

    try {
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'titulo': titulo,
        'descripcion': _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
        'fecha_limite': fechaLimite.toIso8601String(),
        'prioridad': _prioridad,
      };

      String tareaId;
      if (_editando) {
        tareaId = widget.tarea!['id'];
        await supabase.from('tareas').update(datos).eq('id', tareaId);
      } else {
        final insertado = await supabase
            .from('tareas')
            .insert({...datos, 'usuario_id': userId, 'estado': 'pendiente'})
            .select('id')
            .single();
        tareaId = insertado['id'];
      }

      await SugerenciasService.registrarUso('tarea_titulo', titulo);
      await SugerenciasService.registrarUso('tarea_hora', _formatearHora(_hora));

      // Reprograma el recordatorio (si se edita, primero se cancela el
      // anterior para no dejar uno viejo con la fecha equivocada).
      await NotificationService.cancelarRecordatorioTarea(tareaId);
      await NotificationService.programarRecordatorioTarea(
        tareaId: tareaId,
        titulo: titulo,
        fechaLimite: fechaLimite,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).extension<TareasTheme>()!;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(_editando ? 'Editar tarea' : 'Nueva tarea')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('TÍTULO', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                _campoTituloConAutocompletado(),
                const SizedBox(height: 20),

                Text('DESCRIPCIÓN (opcional)', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descripcionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Detalles de la tarea...'),
                ),
                const SizedBox(height: 20),

                Text('FECHA Y HORA LÍMITE', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _botonSelector(
                        icono: Icons.calendar_today,
                        texto: '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                        onTap: _elegirFecha,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _botonSelector(
                        icono: Icons.access_time,
                        texto: _formatearHora(_hora),
                        onTap: _elegirHora,
                      ),
                    ),
                  ],
                ),

                if (_sugerenciasHora.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Horas que usas seguido:', style: AppTypography.secondary.copyWith(color: AppColors.textTertiary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sugerenciasHora.map((h) {
                      final partes = h.split(':');
                      final activa = _formatearHora(_hora) == h;
                      return GestureDetector(
                        onTap: () => setState(() => _hora = TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1]))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: activa ? AppColors.gold : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            border: Border.all(color: activa ? AppColors.gold : AppColors.borderSoft),
                          ),
                          child: Text(h,
                              style: TextStyle(
                                color: activa ? Colors.white : AppColors.textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                Text('PRIORIDAD', style: AppTypography.sectionLabel),
                const SizedBox(height: 8),
                _selectorPrioridad(tema),
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
                              : Text(_editando ? 'Guardar cambios' : 'Crear tarea',
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

  Widget _campoTituloConAutocompletado() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: widget.tarea?['titulo'] ?? ''),
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return _sugerenciasTitulo.take(5);
        return _sugerenciasTitulo.where((s) => s.toLowerCase().contains(value.text.toLowerCase()));
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _tituloCtrl = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            hintText: 'Ej: Revisar informe financiero',
            prefixIcon: Icon(Icons.edit_note, color: AppColors.gold),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ponle un título a la tarea' : null,
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
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 500),
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

  Widget _botonSelector({required IconData icono, required String texto, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
        ),
        child: Row(
          children: [
            Icon(icono, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Text(texto, style: AppTypography.itemTitle),
          ],
        ),
      ),
    );
  }

  Widget _selectorPrioridad(TareasTheme tema) {
    final opciones = [
      ('alta', 'Alta', tema.prioridadAlta),
      ('media', 'Media', tema.prioridadMedia),
      ('baja', 'Baja', tema.prioridadBaja),
    ];

    return Row(
      children: opciones.map((op) {
        final (valor, etiqueta, color) = op;
        final activa = _prioridad == valor;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _prioridad = valor),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: activa ? color.withValues(alpha: 0.12) : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.xl2),
                border: Border.all(color: activa ? color : AppColors.borderSoft),
              ),
              child: Column(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(height: 6),
                  Text(etiqueta,
                      style: TextStyle(
                        color: activa ? AppColors.textPrimary : AppColors.textTertiary,
                        fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
