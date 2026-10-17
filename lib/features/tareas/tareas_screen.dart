import 'package:flutter/material.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/notification_service.dart';
import 'task_form_screen.dart';

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

enum _Filtro { todas, pendientes, completadas }

class _TareasScreenState extends State<TareasScreen> {
  final _buscarCtrl = TextEditingController();
  bool _cargando = true;
  String? _errorCarga;
  List<Map<String, dynamic>> _tareas = [];
  _Filtro _filtro = _Filtro.pendientes;
  String? _prioridadFiltro;
  DateTime? _fechaFiltro;
  bool _priorizarPorUrgencia = true;

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('tareas')
          .select()
          .eq('usuario_id', userId)
          .order('fecha_limite', ascending: true);
      if (mounted) {
        setState(() {
          _tareas = List<Map<String, dynamic>>.from(data);
          _cargando = false;
          _errorCarga = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudieron cargar tus tareas: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _tareasFiltradas {
    final filtradas = _tareas.where((tarea) {
      final estadoCoincide = switch (_filtro) {
        _Filtro.pendientes => tarea['estado'] == 'pendiente',
        _Filtro.completadas => tarea['estado'] == 'completada',
        _Filtro.todas => true,
      };
      final textoCoincide =
          _buscarCtrl.text.trim().isEmpty ||
          (tarea['titulo'] as String).toLowerCase().contains(
            _buscarCtrl.text.trim().toLowerCase(),
          );
      final prioridadCoincide =
          _prioridadFiltro == null || tarea['prioridad'] == _prioridadFiltro;
      final fecha = DateTime.tryParse(tarea['fecha_limite']?.toString() ?? '');
      final fechaCoincide =
          _fechaFiltro == null ||
          (fecha != null &&
              fecha.year == _fechaFiltro!.year &&
              fecha.month == _fechaFiltro!.month &&
              fecha.day == _fechaFiltro!.day);
      return estadoCoincide &&
          textoCoincide &&
          prioridadCoincide &&
          fechaCoincide;
    }).toList();

    return _priorizarPorUrgencia
        ? ordenarTareasPorUrgencia(filtradas)
        : filtradas;
  }

  Future<void> _alternarEstado(Map<String, dynamic> tarea) async {
    final nuevoEstado = tarea['estado'] == 'completada'
        ? 'pendiente'
        : 'completada';
    final estadoAnterior = tarea['estado'];
    final completadoAnterior = tarea['completado_en'];
    setState(() {
      tarea['estado'] = nuevoEstado;
      tarea['completado_en'] = nuevoEstado == 'completada'
          ? DateTime.now().toIso8601String()
          : null;
    });
    try {
      await supabase
          .from('tareas')
          .update({
            'estado': nuevoEstado,
            'completado_en': tarea['completado_en'],
          })
          .eq('id', tarea['id']);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        tarea['estado'] = estadoAnterior;
        tarea['completado_en'] = completadoAnterior;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la tarea: $error')),
      );
      return;
    }

    try {
      if (nuevoEstado == 'completada') {
        await NotificationService.cancelarRecordatorioTarea(tarea['id']);
        await _crearSiguienteTareaRecurrente(tarea);
      } else {
        final fechaLimite = DateTime.parse(tarea['fecha_limite']);
        await NotificationService.programarRecordatorioTarea(
          tareaId: tarea['id'],
          titulo: tarea['titulo'],
          fechaLimite: fechaLimite,
        );
      }
      _cargarTareas();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado == 'completada'
                  ? 'La tarea se completó, pero no se pudo programar su siguiente repetición: $error'
                  : 'La tarea se actualizó, pero no se pudo programar el recordatorio: $error',
            ),
          ),
        );
      }
      _cargarTareas();
    }
  }

  Future<void> _crearSiguienteTareaRecurrente(
    Map<String, dynamic> tarea,
  ) async {
    final recurrencia = tarea['recurrencia'] as String? ?? 'ninguna';
    if (recurrencia == 'ninguna') return;

    final existente = await supabase
        .from('tareas')
        .select('id')
        .eq('recurrencia_padre_id', tarea['id'])
        .maybeSingle();
    if (existente != null) return;

    final anterior = DateTime.parse(tarea['fecha_limite']);
    DateTime siguiente;
    switch (recurrencia) {
      case 'diaria':
        siguiente = anterior.add(const Duration(days: 1));
      case 'semanal':
        siguiente = anterior.add(const Duration(days: 7));
      case 'mensual':
        siguiente = _sumarMes(anterior);
      default:
        return;
    }
    final ahora = DateTime.now();
    while (!siguiente.isAfter(ahora)) {
      switch (recurrencia) {
        case 'diaria':
          siguiente = siguiente.add(const Duration(days: 1));
        case 'semanal':
          siguiente = siguiente.add(const Duration(days: 7));
        case 'mensual':
          siguiente = _sumarMes(siguiente);
        default:
          return;
      }
    }

    final usuarioId = supabase.auth.currentUser!.id;
    final nueva = await supabase
        .from('tareas')
        .insert({
          'usuario_id': usuarioId,
          'titulo': tarea['titulo'],
          'descripcion': tarea['descripcion'],
          'fecha_limite': siguiente.toIso8601String(),
          'prioridad': tarea['prioridad'],
          'estado': 'pendiente',
          'recurrencia': recurrencia,
          'recurrencia_padre_id': tarea['id'],
        })
        .select('id')
        .single();
    await NotificationService.programarRecordatorioTarea(
      tareaId: nueva['id'],
      titulo: tarea['titulo'],
      fechaLimite: siguiente,
    );
  }

  DateTime _sumarMes(DateTime fecha) {
    final primerDiaMesSiguiente = DateTime(fecha.year, fecha.month + 1, 1);
    final ultimoDiaMesSiguiente = DateTime(
      primerDiaMesSiguiente.year,
      primerDiaMesSiguiente.month + 1,
      0,
    );
    final dia = fecha.day < ultimoDiaMesSiguiente.day
        ? fecha.day
        : ultimoDiaMesSiguiente.day;
    return DateTime(
      primerDiaMesSiguiente.year,
      primerDiaMesSiguiente.month,
      dia,
      fecha.hour,
      fecha.minute,
    );
  }

  Future<void> _eliminarTarea(Map<String, dynamic> tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text('"${tarea['titulo']}" se eliminará permanentemente.'),
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
      await supabase.from('tareas').delete().eq('id', tarea['id']);
      await NotificationService.cancelarRecordatorioTarea(tarea['id']);
      _cargarTareas();
    }
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? tarea}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TaskFormScreen(tarea: tarea)),
    );
    if (resultado == true) _cargarTareas();
  }

  Future<void> _filtrarPorFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaFiltro ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      helpText: 'Ver tareas de una fecha',
    );
    if (seleccion != null) setState(() => _fechaFiltro = seleccion);
  }

  Future<void> _abrirModoEnfoque() async {
    final tareas = ordenarTareasPorUrgencia(
      _tareasFiltradas.isNotEmpty ? _tareasFiltradas : _tareas,
    ).take(3).toList();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_center_focus, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('Modo enfoque', style: AppTypography.sectionLabel),
              ],
            ),
            const SizedBox(height: 12),
            if (tareas.isEmpty)
              Text(
                'No hay tareas activas para este bloque.',
                style: AppTypography.secondary,
              )
            else ...[
              ...tareas.map((tarea) {
                final prioridad = (tarea['prioridad'] ?? 'media').toString();
                final fecha =
                    DateTime.tryParse(
                      tarea['fecha_limite']?.toString() ?? '',
                    ) ??
                    DateTime.now();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.goldSoftBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: prioridad == 'alta'
                            ? AppColors.red
                            : prioridad == 'media'
                            ? AppColors.gold
                            : AppColors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tarea['titulo'] ?? 'Tarea sin título',
                              style: AppTypography.itemTitle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${prioridad.toUpperCase()} • ${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}',
                              style: AppTypography.secondary.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _errorCarga != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorCarga!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _cargarTareas,
                      icon: const Icon(Icons.refresh),
                      label: Text(appText(context, 'Reintentar', 'Retry')),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargarTareas,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _buscarCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: appText(
                          context,
                          'Buscar tareas',
                          'Search tasks',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _buscarCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                onPressed: () {
                                  _buscarCtrl.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ),
                  _barraFiltros(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _prioridadFiltro,
                            decoration: InputDecoration(
                              labelText: appText(
                                context,
                                'Prioridad',
                                'Priority',
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(appText(context, 'Todas', 'All')),
                              ),
                              DropdownMenuItem(
                                value: 'alta',
                                child: Text(appText(context, 'Alta', 'High')),
                              ),
                              DropdownMenuItem(
                                value: 'media',
                                child: Text(
                                  appText(context, 'Media', 'Medium'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'baja',
                                child: Text(appText(context, 'Baja', 'Low')),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _prioridadFiltro = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _filtrarPorFecha,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            _fechaFiltro == null
                                ? appText(context, 'Fecha', 'Date')
                                : '${_fechaFiltro!.day}/${_fechaFiltro!.month}',
                          ),
                        ),
                        if (_fechaFiltro != null)
                          IconButton(
                            tooltip: 'Quitar filtro de fecha',
                            onPressed: () =>
                                setState(() => _fechaFiltro = null),
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(
                              _priorizarPorUrgencia
                                  ? appText(context, 'Prioridad', 'Priority')
                                  : appText(context, 'Fecha', 'Date'),
                            ),
                            selected: _priorizarPorUrgencia,
                            onSelected: (_) => setState(
                              () => _priorizarPorUrgencia =
                                  !_priorizarPorUrgencia,
                            ),
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: _priorizarPorUrgencia
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            side: BorderSide(
                              color: _priorizarPorUrgencia
                                  ? AppColors.gold
                                  : AppColors.borderSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _abrirModoEnfoque,
                          icon: const Icon(Icons.filter_center_focus),
                          label: const Text('Enfoque'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _tareasFiltradas.isEmpty
                        ? _estadoVacio()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: _tareasFiltradas.length,
                            itemBuilder: (context, i) =>
                                _tarjetaTarea(_tareasFiltradas[i]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _barraFiltros() {
    Widget chip(String label, _Filtro valor) {
      final activo = _filtro == valor;
      return ChoiceChip(
        label: Text(label),
        selected: activo,
        onSelected: (_) => setState(() => _filtro = valor),
        selectedColor: AppColors.gold,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          color: activo ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: activo ? AppColors.gold : AppColors.borderSoft),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(appText(context, 'Pendientes', 'Pending'), _Filtro.pendientes),
          chip(
            appText(context, 'Completadas', 'Completed'),
            _Filtro.completadas,
          ),
          chip(appText(context, 'Todas', 'All'), _Filtro.todas),
        ],
      ),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            Text(
              _filtro == _Filtro.completadas
                  ? appText(
                      context,
                      'Aún no completas ninguna tarea.',
                      'You have not completed any tasks yet.',
                    )
                  : appText(
                      context,
                      'No tienes tareas por aquí.\nToca + para crear una.',
                      'No tasks here yet.\nTap + to create one.',
                    ),
              textAlign: TextAlign.center,
              style: AppTypography.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaTarea(Map<String, dynamic> tarea) {
    final tema = Theme.of(context).extension<TareasTheme>()!;
    final coloresPrioridad = {
      'alta': tema.prioridadAlta,
      'media': tema.prioridadMedia,
      'baja': tema.prioridadBaja,
    };
    final completada = tarea['estado'] == 'completada';
    final color =
        coloresPrioridad[tarea['prioridad']] ?? AppColors.textTertiary;
    final fecha = DateTime.parse(tarea['fecha_limite']);
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(tema.radioTarjeta),
        border: Border.all(
          color: AppColors.borderSoft,
          width: AppRadii.borderWidth,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _alternarEstado(tarea),
            child: Icon(
              completada ? Icons.check_circle : Icons.radio_button_unchecked,
              color: completada ? AppColors.green : color,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _abrirFormulario(tarea: tarea),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea['titulo'] ?? '',
                    style: AppTypography.itemTitle.copyWith(
                      color: completada
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      decoration: completada
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 13,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fechaTexto,
                        style: AppTypography.secondary.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (tarea['prioridad'] ?? '').toString().toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: AppColors.textTertiary,
              size: 20,
            ),
            onPressed: () => _eliminarTarea(tarea),
          ),
        ],
      ),
    );
  }
}
