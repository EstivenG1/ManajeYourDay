import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/historial_service.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

enum _Periodo { dias7, dias30, todo }

class _HistorialScreenState extends State<HistorialScreen> {
  bool _cargando = true;
  List<HistorialItem> _items = [];
  FiltroHistorial _filtro = FiltroHistorial.todo;
  _Periodo _periodo = _Periodo.dias30;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final hoy = DateTime.now();
    final desde = switch (_periodo) {
      _Periodo.dias7 => hoy.subtract(const Duration(days: 7)),
      _Periodo.dias30 => hoy.subtract(const Duration(days: 30)),
      _Periodo.todo => DateTime(2020),
    };
    try {
      final items = await HistorialService.cargar(desde: desde);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      // deja _items como estaba
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _tituloGrupo(DateTime fecha) {
    final hoy = DateTime.now();
    final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
    final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final diferencia = soloHoy.difference(soloFecha).inDays;

    if (diferencia == 0) return 'Hoy';
    if (diferencia == 1) return 'Ayer';

    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${fecha.day} de ${meses[fecha.month - 1]}';
  }

  ({IconData icono, Color color}) _estiloItem(TipoHistorial tipo) {
    switch (tipo) {
      case TipoHistorial.ingreso:
        return (icono: Icons.arrow_downward, color: AppColors.green);
      case TipoHistorial.gasto:
        return (icono: Icons.arrow_upward, color: AppColors.red);
      case TipoHistorial.tareaCreada:
        return (icono: Icons.add_task, color: AppColors.textTertiary);
      case TipoHistorial.tareaCompletada:
        return (icono: Icons.check_circle, color: AppColors.green);
      case TipoHistorial.aporte:
        return (icono: Icons.savings, color: AppColors.gold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _items.where((i) => HistorialService.coincideFiltro(i, _filtro)).toList();

    // Agrupar por día conservando el orden (ya vienen ordenados desc)
    final grupos = <String, List<HistorialItem>>{};
    for (final item in filtrados) {
      final clave = _tituloGrupo(item.fecha);
      grupos.putIfAbsent(clave, () => []).add(item);
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Historial de actividad')),
      body: Column(
        children: [
          _barraFiltros(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : filtrados.isEmpty
                    ? _estadoVacio()
                    : RefreshIndicator(
                        color: AppColors.gold,
                        onRefresh: _cargar,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: grupos.entries.map((entrada) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entrada.key.toUpperCase(), style: AppTypography.sectionLabel),
                                  const SizedBox(height: 10),
                                  ...entrada.value.map(_tarjetaItem),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _barraFiltros() {
    Widget chipFiltro(String texto, FiltroHistorial valor) {
      final activo = _filtro == valor;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: activo,
          onSelected: (_) => setState(() => _filtro = valor),
          selectedColor: AppColors.gold,
          backgroundColor: AppColors.surface,
          labelStyle: TextStyle(
            color: activo ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
          side: BorderSide(color: activo ? AppColors.gold : AppColors.borderSoft),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                chipFiltro('Todo', FiltroHistorial.todo),
                chipFiltro('Finanzas', FiltroHistorial.finanzas),
                chipFiltro('Tareas', FiltroHistorial.tareas),
                chipFiltro('Metas', FiltroHistorial.metas),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Periodo:', style: AppTypography.secondary),
              const SizedBox(width: 8),
              DropdownButton<_Periodo>(
                value: _periodo,
                underline: const SizedBox(),
                style: AppTypography.itemTitle,
                items: const [
                  DropdownMenuItem(value: _Periodo.dias7, child: Text('Últimos 7 días')),
                  DropdownMenuItem(value: _Periodo.dias30, child: Text('Últimos 30 días')),
                  DropdownMenuItem(value: _Periodo.todo, child: Text('Todo')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _periodo = v);
                  _cargar();
                },
              ),
            ],
          ),
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
            const Text('🗂️', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 12),
            Text('No hay actividad en este periodo.', textAlign: TextAlign.center, style: AppTypography.secondary),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaItem(HistorialItem item) {
    final estilo = _estiloItem(item.tipo);
    final hora = '${item.fecha.hour.toString().padLeft(2, '0')}:${item.fecha.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft, width: AppRadii.borderWidth),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: estilo.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            alignment: Alignment.center,
            child: Icon(estilo.icono, color: estilo.color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.titulo, style: AppTypography.itemTitle, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.subtitulo,
                    style: AppTypography.secondary.copyWith(fontSize: 11.5), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(hora, style: AppTypography.secondary.copyWith(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}
