import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/guided_tour.dart';
import '../../core/services/home_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/sugerencias_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/plan_service.dart';

class TaskFormScreen extends StatefulWidget {
  final Map<String, dynamic>? tarea;
  final bool mostrarGuia;
  const TaskFormScreen({super.key, this.tarea, this.mostrarGuia = false});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloKey = GlobalKey();
  final _descripcionKey = GlobalKey();
  final _fechaHoraKey = GlobalKey();
  final _prioridadKey = GlobalKey();
  final _recurrenciaKey = GlobalKey();
  final _guardarKey = GlobalKey();
  final _descripcionCtrl = TextEditingController();
  final _descripcionFocusNode = FocusNode();
  TextEditingController? _tituloCtrl;

  late DateTime _fecha;
  late TimeOfDay _hora;
  String _prioridad = 'media';
  String _recurrencia = 'ninguna';
  bool _guardando = false;

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
      _recurrencia = tarea['recurrencia'] ?? 'ninguna';
    } else {
      final ahora = DateTime.now();
      _fecha = ahora;
      _hora = TimeOfDay(hour: (ahora.hour + 1) % 24, minute: 0);
    }

    _cargarSugerencias();
    if (widget.mostrarGuia) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarGuia());
    }
  }

  Future<void> _mostrarGuia() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    await mostrarTourGuiado(
      context: context,
      storageKey: 'guided_task_form_v2_$userId',
      force: true,
      steps: [
        TutorialStep(
          title: appText(context, 'Nombre de la tarea', 'Task title'),
          description: appText(
            context,
            'Escribe qué necesitas hacer. Puedes elegir una sugerencia o escribir tu propio título.',
            'Enter what you need to do. Choose a suggestion or write your own title.',
          ),
          icon: Icons.edit_note_rounded,
          color: AppColors.gold,
          target: _tituloKey,
        ),
        TutorialStep(
          title: appText(context, 'Descripción', 'Description'),
          description: appText(
            context,
            'Agrega detalles si los necesitas. Este campo es opcional.',
            'Add details if you need them. This field is optional.',
          ),
          icon: Icons.notes_rounded,
          color: AppColors.gold,
          target: _descripcionKey,
        ),
        TutorialStep(
          title: appText(context, 'Fecha y hora', 'Date and time'),
          description: appText(
            context,
            'Elige cuándo debe completarse y recibirás un recordatorio.',
            'Choose when it is due and you will receive a reminder.',
          ),
          icon: Icons.calendar_month_rounded,
          color: AppColors.gold,
          target: _fechaHoraKey,
        ),
        TutorialStep(
          title: appText(context, 'Prioridad', 'Priority'),
          description: appText(
            context,
            'Marca si la tarea es alta, media o baja para organizar tus pendientes.',
            'Set high, medium, or low priority to organize your tasks.',
          ),
          icon: Icons.flag_outlined,
          color: AppColors.gold,
          target: _prioridadKey,
        ),
        TutorialStep(
          title: appText(context, 'Repetición', 'Repeat'),
          description: appText(
            context,
            'Puedes dejarla sin repetición o programarla cada día, semana o mes.',
            'Leave it as a one-time task, or repeat it daily, weekly, or monthly.',
          ),
          icon: Icons.repeat_rounded,
          color: AppColors.gold,
          target: _recurrenciaKey,
        ),
        TutorialStep(
          title: appText(context, 'Guarda tu tarea', 'Save your task'),
          description: appText(
            context,
            'Cuando termines, presiona Crear tarea.',
            'When you are done, tap Create task.',
          ),
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.gold,
          target: _guardarKey,
          nextLabel: appText(context, 'Terminar guía', 'Finish guide'),
        ),
      ],
    );
  }

  Future<void> _cargarSugerencias() async {
    const sugerenciasIniciales = [
      'Revisar informe financiero',
      'Pagar arriendo',
      'Enviar propuesta al cliente',
      'Hacer ejercicio',
      'Llamar al banco',
      'Estudiar para un examen',
      'Comprar mercado',
      'Organizar pendientes de la semana',
    ];
    var titulos = <String>[];
    var horas = <String>[];
    try {
      titulos = await SugerenciasService.obtener('tarea_titulo');
      horas = await SugerenciasService.obtener('tarea_hora', limite: 6);
    } catch (_) {
      // Las sugerencias iniciales siguen disponibles si no hay conexión.
    }
    if (mounted) {
      setState(() {
        _sugerenciasTitulo = {...titulos, ...sugerenciasIniciales}.toList();
        _sugerenciasHora = horas;
        _guardando = false;
      });
    }
  }

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    _descripcionFocusNode.dispose();
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
    final seleccion = await showTimePicker(
      context: context,
      initialTime: _hora,
    );
    if (seleccion != null) setState(() => _hora = seleccion);
  }

  String _formatearHora(TimeOfDay hora) =>
      '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final titulo = (_tituloCtrl?.text ?? '').trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponle un título a la tarea')),
      );
      return;
    }

    setState(() => _guardando = true);
    final fechaLimite = DateTime(
      _fecha.year,
      _fecha.month,
      _fecha.day,
      _hora.hour,
      _hora.minute,
    );

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final datos = {
        'titulo': titulo,
        'descripcion': _descripcionCtrl.text.trim().isEmpty
            ? null
            : _descripcionCtrl.text.trim(),
        'fecha_limite': fechaLimite.toIso8601String(),
        'prioridad': _prioridad,
        'recurrencia': _recurrencia,
      };

      String tareaId;
      if (_editando) {
        tareaId = widget.tarea!['id'];
        await supabase.from('tareas').update(datos).eq('id', tareaId);
      } else {
        await PlanService.ensureCanCreate(PlanResource.tasksMonthly);
        final insertado = await supabase
            .from('tareas')
            .insert({...datos, 'usuario_id': userId, 'estado': 'pendiente'})
            .select('id')
            .single();
        tareaId = insertado['id'];
      }

      await SugerenciasService.registrarUso('tarea_titulo', titulo);
      await SugerenciasService.registrarUso(
        'tarea_hora',
        _formatearHora(_hora),
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar: ${PlanService.errorMessage(e)}'),
          ),
        );
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
      appBar: AppBar(
        title: Text(
          _editando
              ? appText(context, 'Editar tarea', 'Edit task')
              : appText(context, 'Nueva tarea', 'New task'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  appText(context, 'TÍTULO', 'TITLE'),
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 8),
                _campoTituloConAutocompletado(),
                const SizedBox(height: 20),

                Text(
                  appText(
                    context,
                    'DESCRIPCIÓN (opcional)',
                    'DESCRIPTION (optional)',
                  ),
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: _descripcionKey,
                  controller: _descripcionCtrl,
                  focusNode: _descripcionFocusNode,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Detalles de la tarea...',
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  appText(context, 'FECHA Y HORA LÍMITE', 'DUE DATE AND TIME'),
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 8),
                Row(
                  key: _fechaHoraKey,
                  children: [
                    Expanded(
                      child: _botonSelector(
                        icono: Icons.calendar_today,
                        texto:
                            '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
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
                  Text(
                    appText(
                      context,
                      'Horas que usas seguido:',
                      'Frequently used times:',
                    ),
                    style: AppTypography.secondary.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sugerenciasHora.map((h) {
                      final partes = h.split(':');
                      final activa = _formatearHora(_hora) == h;
                      return GestureDetector(
                        onTap: () => setState(
                          () => _hora = TimeOfDay(
                            hour: int.parse(partes[0]),
                            minute: int.parse(partes[1]),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: activa ? AppColors.gold : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadii.full),
                            border: Border.all(
                              color: activa
                                  ? AppColors.gold
                                  : AppColors.borderSoft,
                            ),
                          ),
                          child: Text(
                            h,
                            style: TextStyle(
                              color: activa
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),

                Text(
                  appText(context, 'PRIORIDAD', 'PRIORITY'),
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 8),
                KeyedSubtree(
                  key: _prioridadKey,
                  child: _selectorPrioridad(tema),
                ),
                const SizedBox(height: 20),
                Text(
                  appText(context, 'REPETICIÓN', 'REPEAT'),
                  style: AppTypography.sectionLabel,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: _recurrenciaKey,
                  initialValue: _recurrencia,
                  items: [
                    DropdownMenuItem(
                      value: 'ninguna',
                      child: Text(
                        appText(context, 'No se repite', 'Does not repeat'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'diaria',
                      child: Text(appText(context, 'Cada día', 'Daily')),
                    ),
                    DropdownMenuItem(
                      value: 'semanal',
                      child: Text(appText(context, 'Cada semana', 'Weekly')),
                    ),
                    DropdownMenuItem(
                      value: 'mensual',
                      child: Text(appText(context, 'Cada mes', 'Monthly')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _recurrencia = value);
                  },
                ),
                if (_recurrencia != 'ninguna') ...[
                  const SizedBox(height: 6),
                  Text(
                    appText(
                      context,
                      'Al completar esta tarea se creará la siguiente ocurrencia.',
                      'Completing this task creates its next occurrence.',
                    ),
                    style: AppTypography.secondary,
                  ),
                ],
                const SizedBox(height: 32),

                SizedBox(
                  key: _guardarKey,
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
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _editando
                                      ? appText(
                                          context,
                                          'Guardar cambios',
                                          'Save changes',
                                        )
                                      : appText(
                                          context,
                                          'Crear tarea',
                                          'Create task',
                                        ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
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
      key: _tituloKey,
      initialValue: TextEditingValue(text: widget.tarea?['titulo'] ?? ''),
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return _sugerenciasTitulo.take(5);
        final consulta = value.text.trim().toLowerCase();
        final coincidencias = _sugerenciasTitulo.where(
          (s) => s.toLowerCase().contains(consulta),
        );
        final alInicio = coincidencias
            .where((s) => s.toLowerCase().startsWith(consulta))
            .toList();
        final enElTexto = coincidencias
            .where((s) => !s.toLowerCase().startsWith(consulta))
            .toList();
        return [...alInicio, ...enElTexto].take(6);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _tituloCtrl = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Ej: Revisar informe financiero',
            prefixIcon: Icon(Icons.edit_note, color: AppColors.gold),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Ponle un título a la tarea'
              : null,
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
                    leading: Text(
                      _emojiSugerencia(opcion),
                      style: const TextStyle(fontSize: 16),
                    ),
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

  String _emojiSugerencia(String titulo) {
    final texto = titulo.toLowerCase();
    if (texto.contains('pagar') || texto.contains('banco')) return '💳';
    if (texto.contains('comprar') || texto.contains('mercado')) return '🛒';
    if (texto.contains('ejercicio') || texto.contains('caminar')) return '🏃';
    if (texto.contains('estudiar') || texto.contains('examen')) return '📚';
    if (texto.contains('llamar')) return '📞';
    if (texto.contains('informe') || texto.contains('propuesta')) return '📝';
    return '✨';
  }

  Widget _botonSelector({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(
            color: AppColors.borderSoft,
            width: AppRadii.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: AppColors.gold, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                texto,
                style: AppTypography.itemTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
                color: activa
                    ? color.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.xl2),
                border: Border.all(
                  color: activa ? color : AppColors.borderSoft,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    etiqueta,
                    style: TextStyle(
                      color: activa
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
