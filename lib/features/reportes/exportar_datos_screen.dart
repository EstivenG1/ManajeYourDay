import 'dart:convert';

import 'package:excel_plus/excel_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
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
  static const _oro = PdfColor(0.79, 0.66, 0.30);
  static const _oroOscuro = PdfColor(0.55, 0.41, 0.08);
  static const _grisClaro = PdfColor(0.96, 0.95, 0.92);

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

  Future<
    ({
      List<Map<String, dynamic>> movimientos,
      List<Map<String, dynamic>> tareas,
    })
  >
  _cargarDatos() async {
    final userId = supabase.auth.currentUser!.id;
    final movimientos = <Map<String, dynamic>>[];
    final tareas = <Map<String, dynamic>>[];
    const tamano = 500;
    for (var inicio = 0; ; inicio += tamano) {
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
    for (var inicio = 0; ; inicio += tamano) {
      final pagina = await supabase
          .from('tareas')
          .select('id, titulo, prioridad, estado, fecha_limite')
          .eq('usuario_id', userId)
          .gte('fecha_limite', _desde.toIso8601String())
          .lte(
            'fecha_limite',
            DateTime(
              _hasta.year,
              _hasta.month,
              _hasta.day,
              23,
              59,
              59,
            ).toIso8601String(),
          )
          .order('id')
          .range(inicio, inicio + tamano - 1);
      tareas.addAll(List<Map<String, dynamic>>.from(pagina));
      if (pagina.length < tamano) break;
    }
    return (movimientos: movimientos, tareas: tareas);
  }

  Future<Uint8List> _cargarLogo() async {
    final asset = await rootBundle.load('assets/icon/icon.png');
    return Uint8List.view(
      asset.buffer,
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
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
      [
        'Tipo',
        'Fecha',
        'Descripción',
        'Categoría',
        'Monto',
        'Prioridad',
        'Estado',
      ],
      ...movimientos.map(
        (item) => [
          item['tipo'],
          item['fecha'],
          item['descripcion'],
          item['categorias']?['nombre'],
          item['monto'],
          '',
          '',
        ],
      ),
      ...tareas.map(
        (item) => [
          'tarea',
          item['fecha_limite'],
          item['titulo'],
          '',
          '',
          item['prioridad'],
          item['estado'],
        ],
      ),
    ];
    final csv =
        '\uFEFF${rows.map((row) => row.map(_escaparCsv).join(',')).join('\r\n')}';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      name: 'myd-${_fechaIso(_desde)}-${_fechaIso(_hasta)}.csv',
      mimeType: 'text/csv',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: 'Exportación de MYD'),
    );
  }

  void _escribirCelda(
    Sheet sheet,
    int columna,
    int fila,
    CellValue valor, {
    CellStyle? estilo,
  }) {
    sheet.updateCell(
      CellIndex.indexByString('${_nombreColumna(columna)}${fila + 1}'),
      valor,
      cellStyle: estilo,
    );
  }

  String _nombreColumna(int indice) {
    var numero = indice + 1;
    var nombre = '';
    while (numero > 0) {
      final resto = (numero - 1) % 26;
      nombre = String.fromCharCode(65 + resto) + nombre;
      numero = (numero - resto - 1) ~/ 26;
    }
    return nombre;
  }

  CellValue _valorExcel(Object? valor) {
    if (valor is int) return IntCellValue(valor);
    if (valor is num) return DoubleCellValue(valor.toDouble());
    return TextCellValue(valor?.toString() ?? '');
  }

  void _configurarHoja({
    required Sheet sheet,
    required String titulo,
    required String periodo,
    required List<String> encabezados,
    required Uint8List logo,
  }) {
    final ultimaLetra = _nombreColumna(encabezados.length - 1);
    final marca = CellStyle(
      bold: true,
      fontSize: 18,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#A8873A'),
      verticalAlign: VerticalAlign.Center,
    );
    final subtitulo = CellStyle(
      italic: true,
      fontColorHex: ExcelColor.fromHexString('#66552D'),
      backgroundColorHex: ExcelColor.fromHexString('#FEF9EC'),
      verticalAlign: VerticalAlign.Center,
    );

    sheet.merge(
      CellIndex.indexByString('B1'),
      CellIndex.indexByString('${ultimaLetra}1'),
      customValue: TextCellValue(titulo),
    );
    sheet.cell(CellIndex.indexByString('B1')).cellStyle = marca;
    sheet.merge(
      CellIndex.indexByString('B2'),
      CellIndex.indexByString('${ultimaLetra}2'),
      customValue: TextCellValue('Periodo: $periodo'),
    );
    sheet.cell(CellIndex.indexByString('B2')).cellStyle = subtitulo;
    sheet.setRowHeight(0, 42);
    sheet.setRowHeight(1, 24);
    sheet.insertImage(
      logo,
      anchor: CellIndex.indexByString('A1'),
      width: 42,
      height: 42,
    );
    for (var columna = 0; columna < encabezados.length; columna++) {
      sheet.setColumnWidth(columna, columna == 0 ? 18 : 22);
    }
  }

  void _agregarTablaExcel(
    Sheet sheet,
    List<String> encabezados,
    List<List<Object?>> filas,
  ) {
    final estiloEncabezado = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#C9A84C'),
      verticalAlign: VerticalAlign.Center,
    );
    final estiloFila = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#FFFCF5'),
      verticalAlign: VerticalAlign.Center,
    );
    final estiloAlterno = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#F7F3E8'),
      verticalAlign: VerticalAlign.Center,
    );
    final estiloMonto = CellStyle(
      numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
      verticalAlign: VerticalAlign.Center,
    );

    for (var columna = 0; columna < encabezados.length; columna++) {
      _escribirCelda(
        sheet,
        columna,
        3,
        TextCellValue(encabezados[columna]),
        estilo: estiloEncabezado,
      );
    }
    for (var indiceFila = 0; indiceFila < filas.length; indiceFila++) {
      final fila = filas[indiceFila];
      for (var columna = 0; columna < encabezados.length; columna++) {
        final esMonto = encabezados[columna] == 'Monto';
        _escribirCelda(
          sheet,
          columna,
          indiceFila + 4,
          _valorExcel(fila[columna]),
          estilo: esMonto
              ? estiloMonto
              : indiceFila.isEven
              ? estiloFila
              : estiloAlterno,
        );
      }
    }
    if (filas.isEmpty) {
      _escribirCelda(
        sheet,
        0,
        4,
        TextCellValue('Sin registros en el periodo seleccionado.'),
      );
    }
  }

  Future<void> _compartirExcel(
    List<Map<String, dynamic>> movimientos,
    List<Map<String, dynamic>> tareas,
  ) async {
    final logo = await _cargarLogo();
    final periodo = '${_fechaIso(_desde)} a ${_fechaIso(_hasta)}';
    final libro = Excel.createExcel();
    libro.rename('Sheet1', 'Resumen');

    final ingresos = movimientos
        .where((item) => item['tipo'] == 'ingreso')
        .fold<double>(
          0,
          (total, item) => total + (item['monto'] as num).toDouble(),
        );
    final gastos = movimientos
        .where((item) => item['tipo'] == 'gasto')
        .fold<double>(
          0,
          (total, item) => total + (item['monto'] as num).toDouble(),
        );
    final resumen = libro['Resumen'];
    _configurarHoja(
      sheet: resumen,
      titulo: 'MYD | Reporte personal',
      periodo: periodo,
      encabezados: const ['Indicador', 'Valor'],
      logo: logo,
    );
    final encabezadoResumen = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#C9A84C'),
    );
    _escribirCelda(
      resumen,
      0,
      3,
      TextCellValue('Indicador'),
      estilo: encabezadoResumen,
    );
    _escribirCelda(
      resumen,
      1,
      3,
      TextCellValue('Valor'),
      estilo: encabezadoResumen,
    );
    final indicadores = [
      ['Ingresos', ingresos],
      ['Gastos', gastos],
      ['Balance', ingresos - gastos],
      ['Movimientos', movimientos.length],
      ['Tareas', tareas.length],
    ];
    for (var i = 0; i < indicadores.length; i++) {
      _escribirCelda(
        resumen,
        0,
        i + 4,
        TextCellValue(indicadores[i][0].toString()),
        estilo: CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FEF9EC'),
        ),
      );
      final valor = indicadores[i][1];
      _escribirCelda(
        resumen,
        1,
        i + 4,
        _valorExcel(valor),
        estilo: CellStyle(
          bold: true,
          numberFormat: NumFormat.custom(formatCode: '#,##0.00'),
        ),
      );
    }
    resumen.setColumnWidth(0, 24);
    resumen.setColumnWidth(1, 22);

    final movimientosSheet = libro['Movimientos'];
    _configurarHoja(
      sheet: movimientosSheet,
      titulo: 'MYD | Movimientos',
      periodo: periodo,
      encabezados: const ['Fecha', 'Tipo', 'Categoría', 'Descripción', 'Monto'],
      logo: logo,
    );
    _agregarTablaExcel(
      movimientosSheet,
      const ['Fecha', 'Tipo', 'Categoría', 'Descripción', 'Monto'],
      movimientos
          .map(
            (item) => [
              item['fecha'],
              item['tipo'],
              item['categorias']?['nombre'],
              item['descripcion'],
              item['monto'],
            ],
          )
          .toList(),
    );
    movimientosSheet.setColumnWidth(3, 40);

    final tareasSheet = libro['Tareas'];
    _configurarHoja(
      sheet: tareasSheet,
      titulo: 'MYD | Tareas',
      periodo: periodo,
      encabezados: const ['Fecha límite', 'Tarea', 'Prioridad', 'Estado'],
      logo: logo,
    );
    _agregarTablaExcel(
      tareasSheet,
      const ['Fecha límite', 'Tarea', 'Prioridad', 'Estado'],
      tareas
          .map(
            (item) => [
              item['fecha_limite'],
              item['titulo'],
              item['prioridad'],
              item['estado'],
            ],
          )
          .toList(),
    );
    tareasSheet.setColumnWidth(1, 42);

    final bytes = libro.save();
    if (bytes == null) {
      throw StateError('No fue posible generar el archivo Excel.');
    }
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'myd-${_fechaIso(_desde)}-${_fechaIso(_hasta)}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: 'Reporte Excel de MYD'),
    );
  }

  pw.Widget _tarjetaResumen(String titulo, String valor) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _grisClaro,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _oro, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titulo.toUpperCase(),
            style: pw.TextStyle(
              color: _oroOscuro,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            valor,
            style: pw.TextStyle(
              color: PdfColors.brown900,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  pw.Widget _tablaPdf({
    required List<String> encabezados,
    required List<List<String>> filas,
  }) {
    if (filas.isEmpty) {
      return pw.Text(
        'No hay registros en este periodo.',
        style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
      );
    }
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas,
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
      ),
      headerDecoration: const pw.BoxDecoration(color: _oroOscuro),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      oddRowDecoration: const pw.BoxDecoration(color: _grisClaro),
    );
  }

  Future<void> _compartirPdf(
    List<Map<String, dynamic>> movimientos,
    List<Map<String, dynamic>> tareas,
  ) async {
    final logo = pw.MemoryImage(await _cargarLogo());
    final ingresos = movimientos
        .where((item) => item['tipo'] == 'ingreso')
        .fold<double>(
          0,
          (total, item) => total + (item['monto'] as num).toDouble(),
        );
    final gastos = movimientos
        .where((item) => item['tipo'] == 'gasto')
        .fold<double>(
          0,
          (total, item) => total + (item['monto'] as num).toDouble(),
        );
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 30, 32, 36),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _oro, width: 1.5)),
          ),
          child: pw.Row(
            children: [
              pw.Image(logo, width: 34, height: 34, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 10),
              pw.Text(
                'MYD  |  MANAGE YOUR DAY',
                style: pw.TextStyle(
                  color: _oroOscuro,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _oro, width: 0.6)),
          ),
          child: pw.Text(
            'Reporte personal · ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Reporte personal',
            style: pw.TextStyle(
              color: PdfColors.brown900,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Periodo: ${_fechaIso(_desde)} a ${_fechaIso(_hasta)}',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              _tarjetaResumen('Ingresos', formatearMonto(ingresos)),
              _tarjetaResumen('Gastos', formatearMonto(gastos)),
              _tarjetaResumen('Balance', formatearMonto(ingresos - gastos)),
            ],
          ),
          pw.SizedBox(height: 9),
          pw.Text(
            '${movimientos.length} movimientos  ·  ${tareas.length} tareas',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Movimientos',
            style: pw.TextStyle(
              color: _oroOscuro,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _tablaPdf(
            encabezados: const [
              'Fecha',
              'Tipo',
              'Categoría',
              'Descripción',
              'Monto',
            ],
            filas: movimientos
                .map(
                  (item) => [
                    item['fecha']?.toString() ?? '',
                    item['tipo']?.toString() ?? '',
                    item['categorias']?['nombre']?.toString() ?? '',
                    item['descripcion']?.toString() ?? '',
                    formatearMonto(item['monto'] as num),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Tareas',
            style: pw.TextStyle(
              color: _oroOscuro,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _tablaPdf(
            encabezados: const ['Vence', 'Tarea', 'Prioridad', 'Estado'],
            filas: tareas
                .map(
                  (item) => [
                    item['fecha_limite']?.toString() ?? '',
                    item['titulo']?.toString() ?? '',
                    item['prioridad']?.toString() ?? '',
                    item['estado']?.toString() ?? '',
                  ],
                )
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

  Future<void> _exportar(String formato) async {
    setState(() => _exportando = true);
    try {
      final datos = await _cargarDatos();
      switch (formato) {
        case 'csv':
          await _compartirCsv(datos.movimientos, datos.tareas);
        case 'excel':
          await _compartirExcel(datos.movimientos, datos.tareas);
        case 'pdf':
          await _compartirPdf(datos.movimientos, datos.tareas);
        default:
          throw ArgumentError.value(
            formato,
            'formato',
            'Formato no compatible',
          );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
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
            onPressed: _exportando ? null : () => _exportar('csv'),
            icon: const Icon(Icons.table_chart_outlined),
            label: const Text('Compartir CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportando ? null : () => _exportar('excel'),
            icon: const Icon(Icons.grid_on_outlined),
            label: const Text('Compartir Excel (.xlsx)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exportando ? null : () => _exportar('pdf'),
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
