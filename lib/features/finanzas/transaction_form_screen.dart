import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/formatters/money_input_formatter.dart';
import '../../core/formatters/category_emoji.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/services/sugerencias_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/home_utils.dart';

class TransactionFormScreen extends StatefulWidget {
  final String tipoInicial; // 'ingreso' o 'gasto'
  final Map<String, dynamic>? movimiento; // si viene, se está editando

  const TransactionFormScreen({
    super.key,
    required this.tipoInicial,
    this.movimiento,
  });

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _imagePicker = ImagePicker();
  final _speech = stt.SpeechToText();
  TextEditingController? _descripcionCtrl;
  XFile? _recibo;
  bool _eliminarRecibo = false;
  bool _escuchando = false;

  late String _tipo;
  DateTime _fecha = DateTime.now();
  int? _categoriaId;
  bool _cargando = true;
  String? _errorCarga;
  bool _guardarUbicacion = false;
  bool _cargandoUbicacion = false;
  String? _errorUbicacion;
  double? _latitud;
  double? _longitud;
  DateTime? _ubicacionCapturadaEn;

  List<Map<String, dynamic>> _categorias = [];
  List<String> _sugerenciasDescripcion = [];

  bool get _editando => widget.movimiento != null;

  @override
  void initState() {
    super.initState();
    _tipo = widget.movimiento?['tipo'] ?? widget.tipoInicial;
    if (widget.movimiento != null) {
      _montoCtrl.text = formatearMontoParaCampo(
        widget.movimiento!['monto'] as num,
      );
      _fecha = DateTime.parse(widget.movimiento!['fecha']);
      _categoriaId = widget.movimiento!['categoria_id'];
      _latitud = (widget.movimiento!['ubicacion_latitud'] as num?)?.toDouble();
      _longitud = (widget.movimiento!['ubicacion_longitud'] as num?)
          ?.toDouble();
      _guardarUbicacion = _latitud != null && _longitud != null;
    }
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final categorias = await supabase
          .from('categorias')
          .select()
          .or(
            'usuario_id.is.null,usuario_id.eq.${supabase.auth.currentUser!.id}',
          )
          .eq('tipo', _tipo)
          .order('nombre');

      final sugerencias = await SugerenciasService.obtener(
        '${_tipo}_descripcion',
      );

      if (mounted) {
        setState(() {
          _categorias = List<Map<String, dynamic>>.from(categorias);
          _sugerenciasDescripcion = sugerencias;
          _categoriaId ??= _categorias.isNotEmpty
              ? _categorias.first['id'] as int
              : null;
          _cargando = false;
          _errorCarga = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudieron cargar las categorías: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _capturarRecibo(ImageSource source) async {
    try {
      final imagen = await _imagePicker.pickImage(
        source: source,
        imageQuality: 78,
        maxWidth: 1800,
      );
      if (imagen != null && mounted) setState(() => _recibo = imagen);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la imagen: $error')),
        );
      }
    }
  }

  Future<void> _dictarDescripcion() async {
    if (_escuchando) {
      await _speech.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    final disponible = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' && mounted) {
          setState(() => _escuchando = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _escuchando = false);
      },
    );
    if (!mounted) return;
    if (!disponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El dictado por voz no está disponible en este dispositivo.',
          ),
        ),
      );
      return;
    }
    setState(() => _escuchando = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: 'es_CO', onDevice: true),
      onResult: (result) {
        final controller = _descripcionCtrl;
        if (controller == null || !mounted) return;
        controller.text = result.recognizedWords;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      },
    );
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

  Future<void> _cambiarUbicacion(bool activar) async {
    if (!activar) {
      setState(() {
        _guardarUbicacion = false;
        _latitud = null;
        _longitud = null;
        _ubicacionCapturadaEn = null;
        _errorUbicacion = null;
      });
      return;
    }

    setState(() {
      _guardarUbicacion = true;
      _cargandoUbicacion = true;
      _errorUbicacion = null;
    });
    try {
      final position = await LocationService.currentPosition();
      if (!mounted) return;
      setState(() {
        _latitud = position.latitude;
        _longitud = position.longitude;
        _ubicacionCapturadaEn = DateTime.now();
        _cargandoUbicacion = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoUbicacion = false;
        _errorUbicacion = error.toString().replaceFirst('Bad state: ', '');
      });
    }
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
    final monto = parseMontoEntrada(_montoCtrl.text) ?? 0;

    try {
      if (_guardarUbicacion && !_editando) {
        final capturedAt = _ubicacionCapturadaEn;
        if (_latitud == null ||
            _longitud == null ||
            capturedAt == null ||
            DateTime.now().difference(capturedAt) >
                const Duration(minutes: 1)) {
          await _cambiarUbicacion(true);
          if (_latitud == null || _longitud == null) {
            throw StateError(
              _errorUbicacion ?? 'No se pudo obtener la ubicación actual.',
            );
          }
        }
      }
      final userId = supabase.auth.currentUser!.id;
      final datos = {
        'tipo': _tipo,
        'monto': monto,
        'categoria_id': _categoriaId,
        'descripcion': descripcion.isEmpty ? null : descripcion,
        'fecha':
            '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
        'ubicacion_latitud': _guardarUbicacion ? _latitud : null,
        'ubicacion_longitud': _guardarUbicacion ? _longitud : null,
      };

      dynamic movimientoGuardado;
      if (_editando) {
        await supabase
            .from('movimientos')
            .update(datos)
            .eq('id', widget.movimiento!['id']);
        movimientoGuardado = widget.movimiento;
      } else {
        movimientoGuardado = await supabase
            .from('movimientos')
            .insert({...datos, 'usuario_id': userId})
            .select('id')
            .single();
      }

      if (_recibo != null) {
        try {
          final movimientoId = movimientoGuardado['id'].toString();
          final contentType = _recibo!.mimeType?.startsWith('image/') == true
              ? _recibo!.mimeType!
              : 'image/jpeg';
          final extension = contentType.split('/').last;
          final path = '$userId/$movimientoId.$extension';
          await supabase.storage
              .from('receipts')
              .uploadBinary(
                path,
                await _recibo!.readAsBytes(),
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: contentType,
                ),
              );
          await supabase
              .from('movimientos')
              .update({'comprobante_path': path})
              .eq('id', movimientoGuardado['id']);
          final pathAnterior =
              widget.movimiento?['comprobante_path'] as String?;
          if (pathAnterior != null && pathAnterior != path) {
            await supabase.storage.from('receipts').remove([pathAnterior]);
          }
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El movimiento se guardó, pero no se pudo adjuntar el recibo.',
                ),
              ),
            );
          }
        }
      } else if (_eliminarRecibo &&
          widget.movimiento?['comprobante_path'] != null) {
        final oldPath = widget.movimiento!['comprobante_path'] as String;
        await supabase.storage.from('receipts').remove([oldPath]);
        await supabase
            .from('movimientos')
            .update({'comprobante_path': null})
            .eq('id', movimientoGuardado['id']);
      }

      if (descripcion.isNotEmpty) {
        await SugerenciasService.registrarUso(
          '${_tipo}_descripcion',
          descripcion,
        );
      }

      if (_tipo == 'gasto' && _categoriaId != null) {
        final nombreCategoria = _categorias.firstWhere(
          (c) => c['id'] == _categoriaId,
          orElse: () => {},
        )['nombre'];
        if (nombreCategoria != null) {
          await NotificationService.revisarPresupuesto(
            categoriaId: _categoriaId!,
            nombreCategoria: nombreCategoria,
          );
        }
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
    final gradienteActivo = esIngreso
        ? finanzas.gradienteBotonIngreso
        : finanzas.gradienteBotonGasto;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(_editando ? 'Editar movimiento' : 'Nuevo movimiento'),
      ),
      body: SafeArea(
        child: _errorCarga != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errorCarga!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _cargarDatos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
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
                            child: _selectorTipo(
                              'Ingreso',
                              'ingreso',
                              finanzas.colorIngreso,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _selectorTipo(
                              'Gasto',
                              'gasto',
                              finanzas.colorGasto,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text('MONTO', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      MoneyTextFormField(
                        controller: _montoCtrl,
                        style: AppTypography.balanceDisplay.copyWith(
                          fontSize: 28,
                          color: colorActivo,
                        ),
                        decoration: const InputDecoration(hintText: '0'),
                        validator: (v) {
                          final n = parseMontoEntrada(v ?? '');
                          if (n == null || n <= 0) {
                            return 'Ingresa un monto válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children:
                            const [10000, 20000, 50000, 100000, 200000, 500000]
                                .map(
                                  (amount) => ActionChip(
                                    avatar: const Icon(Icons.bolt, size: 15),
                                    label: Text(formatearMonto(amount)),
                                    onPressed: () => setState(() {
                                      _montoCtrl.text = formatearMontoParaCampo(
                                        amount,
                                      );
                                      _montoCtrl.selection =
                                          TextSelection.collapsed(
                                            offset: _montoCtrl.text.length,
                                          );
                                    }),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AppColors.goldChipBg,
                                    side: BorderSide(
                                      color: AppColors.goldBorder,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 22),

                      Text('CATEGORÍA', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      _cargando
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categorias.map((c) {
                                final activa = _categoriaId == c['id'];
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _categoriaId = c['id']),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: activa
                                          ? (esIngreso
                                                ? finanzas.chipIngresoBg
                                                : finanzas.chipGastoBg)
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(
                                        finanzas.radioChip,
                                      ),
                                      border: Border.all(
                                        color: activa
                                            ? (esIngreso
                                                  ? finanzas.chipIngresoBorder
                                                  : finanzas.chipGastoBorder)
                                            : AppColors.borderSoft,
                                        width: AppRadii.borderWidth,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          emojiCategoria(
                                            c['nombre'],
                                            tipo: _tipo,
                                          ),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 7),
                                        Text(
                                          c['nombre'],
                                          style: TextStyle(
                                            color: activa
                                                ? colorActivo
                                                : AppColors.textSecondary,
                                            fontWeight: activa
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                      const SizedBox(height: 22),

                      Text(
                        'DESCRIPCIÓN (opcional)',
                        style: AppTypography.sectionLabel,
                      ),
                      const SizedBox(height: 8),
                      _campoDescripcionConAutocompletado(),
                      const SizedBox(height: 12),
                      _campoRecibo(),
                      const SizedBox(height: 22),

                      Text('FECHA', style: AppTypography.sectionLabel),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.xl2),
                        onTap: _elegirFecha,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
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
                              Icon(
                                Icons.calendar_today,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                                style: AppTypography.itemTitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _selectorUbicacion(),
                      const SizedBox(height: 24),

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
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _editando
                                            ? 'Guardar cambios'
                                            : 'Guardar ${esIngreso ? 'ingreso' : 'gasto'}',
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

  Widget _selectorUbicacion() {
    final tieneUbicacion = _latitud != null && _longitud != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.goldChipBg,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: AppColors.goldDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicación en tiempo real',
                      style: AppTypography.itemTitle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Guarda el lugar de este movimiento solo si activas la opción.',
                      style: AppTypography.secondary,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _guardarUbicacion,
                activeTrackColor: AppColors.gold,
                onChanged: _cargandoUbicacion ? null : _cambiarUbicacion,
              ),
            ],
          ),
          if (_cargandoUbicacion) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (_errorUbicacion != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _errorUbicacion!,
                    style: TextStyle(color: AppColors.red, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _cargandoUbicacion
                      ? null
                      : () => _cambiarUbicacion(true),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ] else if (_guardarUbicacion && tieneUbicacion) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ubicación lista para guardar con el movimiento.',
                style: AppTypography.secondary.copyWith(color: AppColors.green),
              ),
            ),
          ],
        ],
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
          border: Border.all(
            color: activo ? color : AppColors.borderSoft,
            width: AppRadii.borderWidth,
          ),
        ),
        child: Center(
          child: Text(
            texto,
            style: TextStyle(
              color: activo ? color : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _campoDescripcionConAutocompletado() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(
        text: widget.movimiento?['descripcion'] ?? '',
      ),
      optionsBuilder: (value) {
        if (value.text.trim().isEmpty) return _sugerenciasDescripcion.take(5);
        return _sugerenciasDescripcion.where(
          (s) => s.toLowerCase().contains(value.text.toLowerCase()),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _descripcionCtrl = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Ej: Almuerzo con el equipo',
            suffixIcon: IconButton(
              tooltip: _escuchando ? 'Detener dictado' : 'Dictar descripción',
              onPressed: _dictarDescripcion,
              icon: Icon(
                _escuchando ? Icons.mic : Icons.mic_none_rounded,
                color: _escuchando ? AppColors.red : AppColors.goldDeep,
              ),
            ),
          ),
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
                    leading: Icon(
                      Icons.history,
                      color: AppColors.gold,
                      size: 18,
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

  Widget _campoRecibo() {
    final existente = widget.movimiento?['comprobante_path'] as String?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.goldDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _recibo != null
                  ? 'Recibo listo para adjuntar'
                  : existente != null && !_eliminarRecibo
                  ? 'Este movimiento ya tiene un recibo'
                  : existente != null
                  ? 'El recibo se eliminará al guardar'
                  : 'Adjunta una foto del recibo',
              style: AppTypography.itemTitle,
            ),
          ),
          if (_recibo != null)
            IconButton(
              tooltip: 'Quitar foto',
              onPressed: () => setState(() => _recibo = null),
              icon: const Icon(Icons.close_rounded),
            )
          else if (existente != null)
            IconButton(
              tooltip: _eliminarRecibo ? 'Conservar recibo' : 'Quitar recibo',
              onPressed: () =>
                  setState(() => _eliminarRecibo = !_eliminarRecibo),
              icon: Icon(
                _eliminarRecibo ? Icons.undo_rounded : Icons.delete_outline,
                color: _eliminarRecibo ? AppColors.goldDeep : AppColors.red,
              ),
            )
          else
            PopupMenuButton<ImageSource>(
              tooltip: 'Añadir recibo',
              onSelected: _capturarRecibo,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: ImageSource.camera,
                  child: Text('Tomar foto'),
                ),
                PopupMenuItem(
                  value: ImageSource.gallery,
                  child: Text('Elegir de galería'),
                ),
              ],
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
        ],
      ),
    );
  }
}
