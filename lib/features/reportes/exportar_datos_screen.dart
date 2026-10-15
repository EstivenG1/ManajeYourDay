import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/home_utils.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class ExportarDatosScreen extends StatefulWidget {
  const ExportarDatosScreen({super.key});

  @override
  State<ExportarDatosScreen> createState() => _ExportarDatosScreenState();
}

class _ExportarDatosScreenState extends State<ExportarDatosScreen> {
  late DateTime _desde = DateTime(DateTime.now().year, DateTime.now().month, 1);
  late DateTime _hasta = DateTime.now();
  bool _exportando = false;

  String _fechaIso(DateTime fecha) =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha({required bool desde}) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: desde ? _desde : _hasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (fecha == null) return;
    setState(() {
      if (desde) {
        _desde = fecha;
        if (_hasta.isBefore(_desde)) _hasta = _desde;
      } else {
        _hasta = fecha;
        if (_desde.isAfter(_hasta)) _desde = _hasta;
      }
    });
  }

  Future<({List<Map<String, dynamic>> movimientos, List<Map<String, dynamic>> tareas})>
      _cargarDatos() async {
    final userId = supabase.auth.currentUser!.id;
    final movimientos = <Map<String, dynamic>>[];
    final tareas = <Map<String, dynamic>>[];
    const tamano = 500;
    for (var inicio = 0;; inicio += tamano) {
      final pagina = await supabase
          .from('movimientos')
          .select('id, tipo, monto, descripcion, fecha, categorias(nombre)')
          .eq('usuario_id', userId)
          .gte('fecha', _fechaIso(_desde))
          .lte('fecha', _fechaIso(_hasta))
          .order('id')
          .range(inicio, inicio + tamano - 1);
      movimientos.addAll(List<Map<String, dynamic>>.from(pagina));
      if (pagina.length < tamano) break;
    }
    for (var inicio = 0;; inicio += tamano) {
      final pagina = await supabase
          .from('tareas')
          .select('id, titulo, prioridad, estado, fecha_limite')
          .eq('usuario_id', userId)
          .gte('fecha_limite', _desde.toIso8601String())
          .lte('fecha_limite', DateTime(
            _hasta.year,
            _hasta.month,
            _hasta.day,
            23,
            59,
            59,
          ).toIso8601String())
          .order('id')
          .range(inicio, inicio + tamano - 1);
      tareas.addAll(List<Map<String, dynamic>>.from(pagina));
      if (pagina.length < tamano) break;
    }
    return (movimientos: movimientos, tareas: tareas);
  }

  String _escaparCsv(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _compartirCsv(
    List<Map<String, dynamic>> movimientos,
    List<Map<String, dynamic>> tareas,
  ) async {
    final rows = <List<Object?>>[
      ['Tipo', 'Fecha', 'Descripción', 'Categoría', 'Monto', 'Prioridad', 'Estado'],
      ...movimientos.map((item) => [
            item['tipo'],
            item['fecha'],
            item['descripcion'],
            item['categorias']?['nombre'],
            item['monto'],
            '',
            '',
          ]),
      ...tareas.map((item) => [
            'tarea',
            item['fecha_limite'],
            item['titulo'],
            '',
            '',
            item['prioridad'],
            item['estado'],
          ]),
    ];
    final csv = '\uFEFF${rows.map((row) => row.map(_escaparCsv).join(',')).join('\r\n')}';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      name: 'myd-${_fechaIso(_desde)}-${_fechaIso(_hasta)}.csv',
      mimeType: 'text/csv',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: 'Exportación de MYD'),
    );
  }

  Future<void> _compartirPdf(
    List<Map<String, dynamic>> movimientos,
    List<Map<String, dynamic>> tareas,
  ) async {
    var ingresos = 0.0;
    var gastos = 0.0;
    for (final item in movimientos) {
      final monto = (item['monto'] as num).toDouble();
      if (item['tipo'] == 'ingreso') {
        ingresos += monto;
      } else {
        gastos += monto;
      }
    }
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('MYD — Reporte personal'),
          ),
          pw.Text('Periodo: ${_fechaIso(_desde)} a ${_fechaIso(_hasta)}'),
          pw.SizedBox(height: 12),
          pw.Text('Ingresos: ${formatearMonto(ingresos)}'),
          pw.Text('Gastos: ${formatearMonto(gastos)}'),
          pw.Text('Balance: ${formatearMonto(ingresos - gastos)}'),
          pw.Text('Movimientos: ${movimientos.length} · Tareas: ${tareas.length}'),
          pw.SizedBox(height: 18),
          pw.Header(level: 1, child: pw.Text('Movimientos')),
          if (movimientos.isEmpty)
            pw.Text('No hay movimientos en este periodo.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Fecha', 'Tipo', 'Categoría', 'Descripción', 'Monto'],
              data: movimientos
                  .map((item) => [
                        item['fecha']?.toString() ?? '',
                        item['tipo']?.toString() ?? '',
                        item['categorias']?['nombre']?.toString() ?? '',
                        item['descripcion']?.toString() ?? '',
                        formatearMonto(item['monto'] as num),
                      ])
                  .toList(),
            ),
          pw.SizedBox(height: 18),
          pw.Header(level: 1, child: pw.Text('Tareas')),
          if (tareas.isEmpty)
            pw.Text('No hay tareas en este periodo.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Vence', 'Tarea', 'Prioridad', 'Estado'],
              data: tareas
                  .map((item) => [
                        item['fecha_limite']?.toString() ?? '',
                        item['titulo']?.toString() ?? '',
                        item['prioridad']?.toString() ?? '',
                        item['estado']?.toString() ?? '',
                      ])
                  .toList(),
            ),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'myd-${_fechaIso(_desde)}-${_fechaIso(_hasta)}.pdf',
    );
  }

  Future<void> _exportar({required bool pdf}) async {
    setState(() => _exportando = true);
    try {
      final datos = await _cargarDatos();
      if (pdf) {
        await _compartirPdf(datos.movimientos, datos.tareas);
      } else {
        await _compartirCsv(datos.movimientos, datos.tareas);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo exportar: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar datos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('RANGO DE FECHAS', style: AppTypography.sectionLabel),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(desde: true),
            icon: const Icon(Icons.calendar_month),
            label: Text('Desde ${_fechaIso(_desde)}'),
          ),
          OutlinedButton.icon(
            onPressed: () => _elegirFecha(desde: false),
            icon: const Icon(Icons.event),
            label: Text('Hasta ${_fechaIso(_hasta)}'),
          ),
          const SizedBox(height: 14),
          Text(
            'La exportación incluye movimientos registrados y tareas con fecha límite dentro del periodo.',
            style: AppTypography.secondary,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exportando ? null : () => _exportar(pdf: false),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Compartir CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportando ? null : () => _exportar(pdf: true),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Compartir reporte PDF'),
          ),
          if (_exportando) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
