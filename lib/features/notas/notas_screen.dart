import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/home_utils.dart';
import '../../core/services/plan_service.dart';
import '../../core/services/guided_tour.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/theme/app_theme.dart';

enum _NotasLayout { cuadricula, compacta, lista }

class NotasScreen extends StatefulWidget {
  const NotasScreen({super.key, this.active = false});

  final bool active;

  @override
  State<NotasScreen> createState() => _NotasScreenState();
}

class _NotasScreenState extends State<NotasScreen> {
  static const _tamanoPagina = 30;
  static const _colores = <Color>[
    Color(0xFFFFF3C4),
    Color(0xFFFFE1E1),
    Color(0xFFDDF3E4),
    Color(0xFFDCEBFF),
    Color(0xFFEDE1FF),
    Color(0xFFFFE8CC),
    Color(0xFFE8EDF2),
  ];
  static const _emojis = <String>[
    '📝',
    '💼',
    '📞',
    '🎂',
    '🏍️',
    '🍲',
    '🏠',
    '💡',
    '💊',
    '✈️',
    '❤️',
    '🔑',
  ];

  bool _cargando = false;
  bool _cargandoMas = false;
  bool _hayMas = true;
  bool _layoutCargado = false;
  bool _cargaInicialIniciada = false;
  int _cargaVersion = 0;
  String? _error;
  List<Map<String, dynamic>> _notas = [];
  _NotasLayout _layout = _NotasLayout.cuadricula;
  String _filtroCategoria = 'todas';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_cargarSiguientePagina);
    if (widget.active) {
      _cargar();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mostrarGuiaInicial(),
      );
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_cargarSiguientePagina)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotasScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      if (!_cargaInicialIniciada) _cargar();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _mostrarGuiaInicial(),
      );
    }
  }

  Future<void> _mostrarGuiaInicial() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final iniciar = await mostrarGuiaInicial(
      context: context,
      storageKey: 'guided_notes_v2_$userId',
      title: appText(context, 'Hagamos una nota', "Let's make a note"),
      description: appText(
        context,
        'Puedes ponerle un nombre, escribir su información y elegir un emoji y color. ¿Quieres crear una ahora o prefieres hacerlo después?',
        'Give it a title, enter its details, and choose an emoji and color. Would you like to create one now or do it later?',
      ),
      startLabel: appText(context, 'Crear nota ahora', 'Create a note now'),
    );
    if (iniciar && mounted) {
      await _editar(mostrarGuia: true, preguntarConservar: true);
    }
  }

  Future<void> _cargar({bool paginaSiguiente = false}) async {
    if (paginaSiguiente) {
      if (_cargando || _cargandoMas || !_hayMas) return;
    } else if (_cargando) {
      return;
    }
    final offset = paginaSiguiente ? _notas.length : 0;
    final version = paginaSiguiente ? _cargaVersion : ++_cargaVersion;
    final filtro = _filtroCategoria;
    if (!paginaSiguiente) _cargaInicialIniciada = true;
    setState(() {
      if (paginaSiguiente) {
        _cargandoMas = true;
        if (_notas.isEmpty) _cargando = true;
      } else {
        _cargando = _notas.isEmpty;
        _error = null;
        _hayMas = true;
      }
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('A signed-in user is required to load notes.');
      }
      final rows = supabase
          .from('notas')
          .select(
            'id,titulo,contenido,color,emoji,categoria,fijada,orden,actualizado_en',
          )
          .eq('usuario_id', user.id);
      final consulta = filtro == 'todas' ? rows : rows.eq('categoria', filtro);
      final pagina = await consulta
          .order('fijada', ascending: false)
          .order('orden')
          .order('actualizado_en', ascending: false)
          .range(offset, offset + _tamanoPagina - 1);
      _NotasLayout? savedLayout;
      if (!_layoutCargado && !paginaSiguiente) {
        final preferences = await SharedPreferences.getInstance();
        final layoutName = preferences.getString('notes_layout_v1_${user.id}');
        final matchingLayouts = _NotasLayout.values.where(
          (item) => item.name == layoutName,
        );
        if (matchingLayouts.isNotEmpty) savedLayout = matchingLayouts.first;
      }
      if (!mounted || version != _cargaVersion) return;
      setState(() {
        final notasPagina = List<Map<String, dynamic>>.from(pagina);
        if (paginaSiguiente) {
          _notas.addAll(notasPagina);
        } else {
          _notas = notasPagina;
        }
        _hayMas = notasPagina.length == _tamanoPagina;
        if (!_layoutCargado && !paginaSiguiente) {
          _layout = savedLayout ?? _NotasLayout.cuadricula;
          _layoutCargado = true;
        }
        _cargando = false;
        _cargandoMas = false;
      });
    } catch (error) {
      if (!mounted || version != _cargaVersion) return;
      setState(() {
        _cargando = false;
        _cargandoMas = false;
        if (_notas.isEmpty) {
          _error = 'No se pudieron cargar las notas: $error';
        }
      });
      if (_notas.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudieron cargar más notas: $error')),
        );
      }
    }
  }

  Future<void> _filtrarCategoria(String categoria) async {
    if (_filtroCategoria == categoria) return;
    setState(() {
      _filtroCategoria = categoria;
      _notas = [];
      _cargando = false;
      _cargandoMas = false;
      _hayMas = true;
      _error = null;
    });
    await _cargar();
  }

  Future<void> _moverNota(int index, int desplazamiento) async {
    final otroIndex = index + desplazamiento;
    if (otroIndex < 0 || otroIndex >= _notas.length) return;
    final nota = _notas[index];
    final otra = _notas[otroIndex];
    if ((nota['fijada'] as bool? ?? false) !=
        (otra['fijada'] as bool? ?? false)) {
      return;
    }
    try {
      await supabase.rpc(
        'swap_note_order',
        params: {'p_note_id': nota['id'], 'p_other_note_id': otra['id']},
      );
      await _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cambiar el orden de las notas: $error'),
          ),
        );
      }
    }
  }

  Future<void> _alternarFijada(Map<String, dynamic> nota) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'Inicia sesión para fijar notas.',
                'Sign in to pin notes.',
              ),
            ),
          ),
        );
      }
      return;
    }
    final fijada = !(nota['fijada'] as bool? ?? false);
    try {
      final primera = await supabase
          .from('notas')
          .select('orden')
          .eq('usuario_id', user.id)
          .eq('fijada', fijada)
          .neq('id', nota['id'])
          .order('orden')
          .limit(1)
          .maybeSingle();
      final orden = (primera?['orden'] as num?)?.toInt() ?? 0;
      await supabase
          .from('notas')
          .update({'fijada': fijada, 'orden': orden - 1})
          .eq('id', nota['id'])
          .eq('usuario_id', user.id);
      await _cargar();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo fijar la nota: $error')),
        );
      }
    }
  }

  void _cargarSiguientePagina() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      _cargar(paginaSiguiente: true);
    }
  }

  Future<void> _cambiarLayout(_NotasLayout layout) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('A signed-in user is required to save note layout.');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('notes_layout_v1_${user.id}', layout.name);
      if (mounted) setState(() => _layout = layout);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la vista: $error')),
        );
      }
    }
  }

  Future<void> _editar({
    Map<String, dynamic>? nota,
    bool mostrarGuia = false,
    bool preguntarConservar = false,
  }) async {
    final guardada = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _NotaFormPage(
          nota: nota,
          emojis: _emojis,
          colores: _colores,
          mostrarGuia: mostrarGuia,
        ),
      ),
    );
    if (guardada == null || !mounted) return;
    setState(() {
      _notas.removeWhere((item) => item['id'] == guardada['id']);
      if (_filtroCategoria == 'todas' ||
          guardada['categoria'] == _filtroCategoria) {
        _notas.insert(0, guardada);
      }
    });
    await _cargar();
    if (preguntarConservar && mounted) {
      await _preguntarConservar(guardada);
    }
  }

  Future<void> _preguntarConservar(Map<String, dynamic> nota) async {
    final conservar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(appText(context, 'Nota creada', 'Note created')),
        content: Text(
          appText(
            context,
            'Tu nota "${nota['titulo']}" ya está lista. ¿Quieres conservarla?',
            'Your note "${nota['titulo']}" is ready. Would you like to keep it?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(appText(context, 'Eliminarla', 'Delete it')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(appText(context, 'Conservar', 'Keep it')),
          ),
        ],
      ),
    );
    if (conservar == false) await _eliminar(nota, confirmar: false);
  }

  Future<void> _eliminar(
    Map<String, dynamic> nota, {
    bool confirmar = true,
  }) async {
    if (confirmar) {
      final aceptado = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(appText(context, '¿Eliminar nota?', 'Delete note?')),
          content: Text(
            appText(
              context,
              'Se eliminará "${nota['titulo']}".',
              '"${nota['titulo']}" will be deleted.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(appText(context, 'Cancelar', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                appText(context, 'Eliminar', 'Delete'),
                style: TextStyle(color: AppColors.red),
              ),
            ),
          ],
        ),
      );
      if (aceptado != true) return;
    }
    try {
      await supabase.from('notas').delete().eq('id', nota['id']);
      if (!mounted) return;
      setState(() => _notas.removeWhere((item) => item['id'] == nota['id']));
      if (_notas.length < _tamanoPagina && _hayMas) {
        await _cargar(paginaSiguiente: true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la nota: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    appText(
                      context,
                      'Guarda aquí detalles que quieras recordar.',
                      'Keep handy details you want to remember.',
                    ),
                    style: AppTypography.secondary,
                  ),
                ),
                PopupMenuButton<_NotasLayout>(
                  tooltip: appText(context, 'Vista', 'View'),
                  initialValue: _layout,
                  onSelected: _cambiarLayout,
                  itemBuilder: (context) => [
                    _opcionVista(
                      _NotasLayout.cuadricula,
                      Icons.grid_view_rounded,
                      appText(context, 'Cuadrícula', 'Grid'),
                    ),
                    _opcionVista(
                      _NotasLayout.compacta,
                      Icons.view_agenda_outlined,
                      appText(context, 'Compacta', 'Compact'),
                    ),
                    _opcionVista(
                      _NotasLayout.lista,
                      Icons.view_list_rounded,
                      appText(context, 'Lista', 'List'),
                    ),
                  ],
                  icon: Icon(Icons.tune_rounded, color: AppColors.goldDeep),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _filtroChip('todas', 'Todas'),
                _filtroChip('importante', 'Importantes'),
                _filtroChip('informacion', 'Información'),
                _filtroChip('general', 'Generales'),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : _error != null
                ? _estadoError()
                : _notas.isEmpty
                ? _estadoVacio()
                : RefreshIndicator(
                    color: AppColors.gold,
                    onRefresh: _cargar,
                    child: _contenidoNotas(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes-create',
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.white,
        onPressed: () => _editar(),
        icon: const Icon(Icons.add_rounded),
        label: Text(appText(context, 'Nueva nota', 'New note')),
      ),
    );
  }

  Widget _filtroChip(String categoria, String etiqueta) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(appText(context, etiqueta, _categoriaEnIngles(categoria))),
        selected: _filtroCategoria == categoria,
        onSelected: (_) => _filtrarCategoria(categoria),
      ),
    );
  }

  String _categoriaEnIngles(String categoria) => switch (categoria) {
    'todas' => 'All',
    'importante' => 'Important',
    'informacion' => 'Information',
    _ => 'General',
  };

  PopupMenuItem<_NotasLayout> _opcionVista(
    _NotasLayout value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  Widget _contenidoNotas() {
    if (_layout == _NotasLayout.cuadricula) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemCount: _notas.length + (_cargandoMas ? 2 : 0),
        itemBuilder: (context, index) => index >= _notas.length
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _tarjetaNota(_notas[index], index: index),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _notas.length + (_cargandoMas ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => index >= _notas.length
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _tarjetaNota(
              _notas[index],
              index: index,
              compacta: _layout == _NotasLayout.compacta,
              enLista: true,
            ),
    );
  }

  Widget _tarjetaNota(
    Map<String, dynamic> nota, {
    required int index,
    bool compacta = false,
    bool enLista = false,
  }) {
    final color = _colorDesdeHex(nota['color']?.toString()) ?? _colores.first;
    final contenidoCompleto = nota['contenido']?.toString() ?? '';
    final contenido = contenidoCompleto.length > 300
        ? '${contenidoCompleto.substring(0, 300)}…'
        : contenidoCompleto;
    final titulo = nota['titulo']?.toString() ?? '';
    final emoji = nota['emoji']?.toString() ?? '📝';
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        onTap: () => _editar(nota: nota),
        child: Padding(
          padding: EdgeInsets.all(compacta ? 12 : 16),
          child: enLista
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _textoNota(
                        titulo,
                        contenido,
                        compacta,
                        nota['categoria']?.toString() ?? 'general',
                      ),
                    ),
                    if (nota['fijada'] as bool? ?? false)
                      Icon(
                        Icons.push_pin_rounded,
                        size: 18,
                        color: AppColors.goldDeep,
                      ),
                    _menuNota(nota, index),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const Spacer(),
                        if (nota['fijada'] as bool? ?? false)
                          Icon(
                            Icons.push_pin_rounded,
                            size: 18,
                            color: AppColors.goldDeep,
                          ),
                        _menuNota(nota, index),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _textoNota(
                        titulo,
                        contenido,
                        compacta,
                        nota['categoria']?.toString() ?? 'general',
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _textoNota(
    String titulo,
    String contenido,
    bool compacta,
    String categoria,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          maxLines: compacta ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.itemTitle.copyWith(fontSize: compacta ? 14 : 16),
        ),
        const SizedBox(height: 3),
        Text(
          appText(
            context,
            switch (categoria) {
              'importante' => 'Importante',
              'informacion' => 'Información',
              _ => 'General',
            },
            switch (categoria) {
              'importante' => 'Important',
              'informacion' => 'Information',
              _ => 'General',
            },
          ),
          style: AppTypography.secondary.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 6),
        Text(
          contenido,
          maxLines: compacta ? 2 : 5,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.secondary,
        ),
      ],
    );
  }

  Widget _menuNota(Map<String, dynamic> nota, int index) {
    final fijada = nota['fijada'] as bool? ?? false;
    final puedeMoverArriba =
        index > 0 && (_notas[index - 1]['fijada'] as bool? ?? false) == fijada;
    final puedeMoverAbajo =
        index < _notas.length - 1 &&
        (_notas[index + 1]['fijada'] as bool? ?? false) == fijada;
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 140),
      onSelected: (value) {
        if (value == 'edit') _editar(nota: nota);
        if (value == 'delete') _eliminar(nota);
        if (value == 'pin') _alternarFijada(nota);
        if (value == 'up') _moverNota(index, -1);
        if (value == 'down') _moverNota(index, 1);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Text(appText(context, 'Editar', 'Edit')),
        ),
        PopupMenuItem(
          value: 'pin',
          child: Text(
            appText(
              context,
              fijada ? 'Dejar de fijar' : 'Fijar arriba',
              fijada ? 'Unpin' : 'Pin to top',
            ),
          ),
        ),
        PopupMenuItem(
          value: 'up',
          enabled: puedeMoverArriba,
          child: Text(appText(context, 'Mover hacia arriba', 'Move up')),
        ),
        PopupMenuItem(
          value: 'down',
          enabled: puedeMoverAbajo,
          child: Text(appText(context, 'Mover hacia abajo', 'Move down')),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(appText(context, 'Eliminar', 'Delete')),
        ),
      ],
      icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
    );
  }

  Widget _estadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗒️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              appText(
                context,
                'Tus ideas, siempre a mano',
                'Your notes, handy',
              ),
              style: AppTypography.itemTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              appText(
                context,
                'Crea una nota para guardar teléfonos, cumpleaños, ideas o recordatorios.',
                'Create a note for phone numbers, birthdays, ideas, or reminders.',
              ),
              style: AppTypography.secondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: Text(appText(context, 'Reintentar', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotaFormPage extends StatelessWidget {
  const _NotaFormPage({
    required this.nota,
    required this.emojis,
    required this.colores,
    required this.mostrarGuia,
  });

  final Map<String, dynamic>? nota;
  final List<String> emojis;
  final List<Color> colores;
  final bool mostrarGuia;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
          appText(
            context,
            nota == null ? 'Nueva nota' : 'Editar nota',
            nota == null ? 'New note' : 'Edit note',
          ),
        ),
      ),
      body: _NotaForm(
        nota: nota,
        emojis: emojis,
        colores: colores,
        mostrarGuia: mostrarGuia,
      ),
    );
  }
}

class _NotaForm extends StatefulWidget {
  const _NotaForm({
    required this.nota,
    required this.emojis,
    required this.colores,
    required this.mostrarGuia,
  });

  final Map<String, dynamic>? nota;
  final List<String> emojis;
  final List<Color> colores;
  final bool mostrarGuia;

  @override
  State<_NotaForm> createState() => _NotaFormState();
}

class _NotaFormState extends State<_NotaForm> {
  final _formKey = GlobalKey<FormState>();
  final _tituloKey = GlobalKey();
  final _contenidoKey = GlobalKey();
  final _emojiKey = GlobalKey();
  final _colorKey = GlobalKey();
  final _guardarKey = GlobalKey();
  late final TextEditingController _titulo;
  late final TextEditingController _contenido;
  late final TextEditingController _emojiPersonalizado;
  late Color _color;
  late String _emoji;
  late String _categoria;
  late bool _fijada;
  bool _guardando = false;

  bool get _editando => widget.nota != null;

  @override
  void initState() {
    super.initState();
    _titulo = TextEditingController(text: widget.nota?['titulo']?.toString());
    _contenido = TextEditingController(
      text: widget.nota?['contenido']?.toString(),
    );
    _emoji = widget.nota?['emoji']?.toString() ?? '📝';
    _categoria = widget.nota?['categoria']?.toString() ?? 'general';
    _fijada = widget.nota?['fijada'] as bool? ?? false;
    _emojiPersonalizado = TextEditingController(
      text: widget.emojis.contains(_emoji) ? '' : _emoji,
    );
    _color =
        _colorDesdeHex(widget.nota?['color']?.toString()) ??
        widget.colores.first;
    if (widget.mostrarGuia) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarGuia());
    }
  }

  Future<void> _mostrarGuia() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !mounted) return;
    await mostrarTourGuiado(
      context: context,
      storageKey: 'guided_note_form_v2_$userId',
      force: true,
      steps: [
        TutorialStep(
          title: appText(context, 'Nombre de la nota', 'Note title'),
          description: appText(
            context,
            'Escribe aquí el nombre que te ayudará a reconocerla.',
            'Enter a title here to help you recognize the note.',
          ),
          icon: Icons.title_rounded,
          color: AppColors.gold,
          target: _tituloKey,
        ),
        TutorialStep(
          title: appText(context, 'Información', 'Information'),
          description: appText(
            context,
            'Escribe aquí el dato o recordatorio que quieres guardar.',
            'Enter the detail or reminder you want to save here.',
          ),
          icon: Icons.notes_rounded,
          color: AppColors.gold,
          target: _contenidoKey,
        ),
        TutorialStep(
          title: appText(context, 'Emoji característico', 'Choose an emoji'),
          description: appText(
            context,
            'Elige un emoji para identificar la nota. También puedes escribir uno propio.',
            'Choose an emoji to identify the note, or enter your own.',
          ),
          icon: Icons.emoji_emotions_outlined,
          color: AppColors.gold,
          target: _emojiKey,
        ),
        TutorialStep(
          title: appText(context, 'Color de la nota', 'Note color'),
          description: appText(
            context,
            'Elige el color que te ayude a encontrarla más fácilmente.',
            'Choose a color that makes the note easier to find.',
          ),
          icon: Icons.palette_outlined,
          color: AppColors.gold,
          target: _colorKey,
        ),
        TutorialStep(
          title: appText(context, 'Guarda tu nota', 'Save your note'),
          description: appText(
            context,
            'Cuando termines, dale a Guardar nota.',
            'When you are done, tap Save note.',
          ),
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.gold,
          target: _guardarKey,
          nextLabel: appText(context, 'Terminar guía', 'Finish guide'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titulo.dispose();
    _contenido.dispose();
    _emojiPersonalizado.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required to save a note.');
    }
    setState(() => _guardando = true);
    try {
      final datos = {
        'titulo': _titulo.text.trim(),
        'contenido': _contenido.text.trim(),
        'color': _hexDesdeColor(_color),
        'emoji': _emojiPersonalizado.text.trim().isEmpty
            ? _emoji
            : _emojiPersonalizado.text.trim(),
        'categoria': _categoria,
        'fijada': _fijada,
      };
      final cambiaGrupo =
          !_editando || (widget.nota!['fijada'] as bool? ?? false) != _fijada;
      if (cambiaGrupo) {
        final userId = user.id;
        var consulta = supabase
            .from('notas')
            .select('orden')
            .eq('usuario_id', userId)
            .eq('fijada', _fijada);
        if (_editando) {
          consulta = consulta.neq('id', widget.nota!['id']);
        }
        final primera = await consulta.order('orden').limit(1).maybeSingle();
        datos['orden'] = ((primera?['orden'] as num?)?.toInt() ?? 0) - 1;
      }
      if (!_editando) {
        await PlanService.ensureCanCreate(PlanResource.notesTotal);
      }
      final respuesta = _editando
          ? await supabase
                .from('notas')
                .update(datos)
                .eq('id', widget.nota!['id'])
                .select(
                  'id,titulo,contenido,color,emoji,categoria,fijada,orden,actualizado_en',
                )
                .single()
          : await supabase
                .from('notas')
                .insert({...datos, 'usuario_id': user.id})
                .select(
                  'id,titulo,contenido,color,emoji,categoria,fijada,orden,actualizado_en',
                )
                .single();
      if (mounted) {
        Navigator.pop(context, Map<String, dynamic>.from(respuesta));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar la nota: ${PlanService.errorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: _tituloKey,
                controller: _titulo,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: appText(
                    context,
                    'Nombre de la nota',
                    'Note title',
                  ),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return appText(
                      context,
                      'Escribe un nombre.',
                      'Enter a title.',
                    );
                  }
                  return value.length > 80
                      ? appText(
                          context,
                          'El nombre no puede superar 80 caracteres.',
                          'The title cannot exceed 80 characters.',
                        )
                      : null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: _contenidoKey,
                controller: _contenido,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: appText(context, 'Información', 'Information'),
                  alignLabelWithHint: true,
                  hintText: appText(
                    context,
                    'Teléfono, idea, fecha importante...',
                    'Phone number, idea, important date...',
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return appText(
                      context,
                      'Escribe la información de la nota.',
                      'Enter the note information.',
                    );
                  }
                  return value.length > 5000
                      ? appText(
                          context,
                          'La información no puede superar 5000 caracteres.',
                          'The information cannot exceed 5000 characters.',
                        )
                      : null;
                },
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: InputDecoration(
                  labelText: appText(context, 'Categoría', 'Category'),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'importante',
                    child: Text(appText(context, 'Importante', 'Important')),
                  ),
                  DropdownMenuItem(
                    value: 'informacion',
                    child: Text(appText(context, 'Información', 'Information')),
                  ),
                  DropdownMenuItem(
                    value: 'general',
                    child: Text(appText(context, 'General', 'General')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _categoria = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(appText(context, 'Fijar arriba', 'Pin to top')),
                subtitle: Text(
                  appText(
                    context,
                    'Las notas fijadas aparecen antes que las demás.',
                    'Pinned notes appear before other notes.',
                  ),
                ),
                value: _fijada,
                onChanged: (value) => setState(() => _fijada = value),
              ),
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  'Evita guardar contraseñas u otros datos de acceso: Notas no es una bóveda de seguridad.',
                  'Avoid storing passwords or other login details: Notes is not a secure vault.',
                ),
                style: AppTypography.secondary.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                appText(context, 'EMOJI', 'EMOJI'),
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _emojiPersonalizado,
                builder: (context, emojiValue, _) => Wrap(
                  key: _emojiKey,
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.emojis.map((emoji) {
                    final seleccionado =
                        _emoji == emoji && emojiValue.text.isEmpty;
                    return ChoiceChip(
                      label: Text(emoji, style: const TextStyle(fontSize: 19)),
                      selected: seleccionado,
                      onSelected: (_) => setState(() {
                        _emoji = emoji;
                        _emojiPersonalizado.clear();
                      }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emojiPersonalizado,
                maxLength: 32,
                decoration: InputDecoration(
                  labelText: appText(
                    context,
                    'O escribe tu emoji',
                    'Or enter your own emoji',
                  ),
                  counterText: '',
                  prefixIcon: const Icon(Icons.emoji_emotions_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                appText(context, 'COLOR DE LA NOTA', 'NOTE COLOR'),
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: 8),
              Wrap(
                key: _colorKey,
                spacing: 12,
                children: widget.colores.map((color) {
                  final seleccionado = color == _color;
                  return InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: seleccionado
                              ? AppColors.textPrimary
                              : AppColors.borderSoft,
                          width: seleccionado ? 2 : 1,
                        ),
                      ),
                      child: seleccionado
                          ? const Icon(Icons.check, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: _guardarKey,
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  appText(
                    context,
                    _editando ? 'Guardar cambios' : 'Guardar nota',
                    _editando ? 'Save changes' : 'Save note',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color? _colorDesdeHex(String? value) {
  if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
    return null;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}

String _hexDesdeColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
