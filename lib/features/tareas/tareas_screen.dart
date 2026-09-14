import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/notification_service.dart';
import 'task_form_screen.dart';

class TareasScreen extends StatefulWidget {
  const TareasScreen({super.key});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

enum _Filtro { todas, pendientes, completadas }

class _TareasScreenState extends State<TareasScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _tareas = [];
  _Filtro _filtro = _Filtro.pendientes;

  @override
  void initState() {
    super.initState();
    _cargarTareas();
  }

  Future<void> _cargarTareas() async {
    setState(() => _cargando = true);
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
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Map<String, dynamic>> get _tareasFiltradas {
    switch (_filtro) {
      case _Filtro.pendientes:
        return _tareas.where((t) => t['estado'] == 'pendiente').toList();
      case _Filtro.completadas:
        return _tareas.where((t) => t['estado'] == 'completada').toList();
      case _Filtro.todas:
        return _tareas;
    }
  }

  Future<void> _alternarEstado(Map<String, dynamic> tarea) async {
    final nuevoEstado = tarea['estado'] == 'completada' ? 'pendiente' : 'completada';
    setState(() {
      tarea['estado'] = nuevoEstado;
      tarea['completado_en'] = nuevoEstado == 'completada' ? DateTime.now().toIso8601String() : null;
    });
    await supabase.from('tareas').update({
      'estado': nuevoEstado,
      'completado_en': tarea['completado_en'],
    }).eq('id', tarea['id']);

    if (nuevoEstado == 'completada') {
      // Ya no hace falta recordarle una tarea que ya completó.
      await NotificationService.cancelarRecordatorioTarea(tarea['id']);
    } else {
      // Se marcó de nuevo como pendiente: si la fecha límite sigue en
      // el futuro, se vuelve a programar el recordatorio.
      final fechaLimite = DateTime.parse(tarea['fecha_limite']);
      await NotificationService.programarRecordatorioTarea(
        tareaId: tarea['id'],
        titulo: tarea['titulo'],
        fechaLimite: fechaLimite,
      );
    }
  }

  Future<void> _eliminarTarea(Map<String, dynamic> tarea) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tarea?'),
        content: Text('"${tarea['titulo']}" se eliminará permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              onRefresh: _cargarTareas,
              child: Column(
                children: [
                  _barraFiltros(),
                  Expanded(
                    child: _tareasFiltradas.isEmpty
                        ? _estadoVacio()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: _tareasFiltradas.length,
                            itemBuilder: (context, i) => _tarjetaTarea(_tareasFiltradas[i]),
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
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          chip('Pendientes', _Filtro.pendientes),
          chip('Completadas', _Filtro.completadas),
          chip('Todas', _Filtro.todas),
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
                  ? 'Aún no completas ninguna tarea.'
                  : 'No tienes tareas por aquí.\nToca + para crear una.',
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
    final color = coloresPrioridad[tarea['prioridad']] ?? AppColors.textTertiary;
    final fecha = DateTime.parse(tarea['fecha_limite']);
    final fechaTexto =
        '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(tema.radioTarjeta),
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
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
                      color: completada ? AppColors.textTertiary : AppColors.textPrimary,
                      decoration: completada ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(fechaTexto, style: AppTypography.secondary.copyWith(color: AppColors.textTertiary, fontSize: 12)),
                      const SizedBox(width: 10),
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text((tarea['prioridad'] ?? '').toString().toUpperCase(),
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textTertiary, size: 20),
            onPressed: () => _eliminarTarea(tarea),
          ),
        ],
      ),
    );
  }
}
