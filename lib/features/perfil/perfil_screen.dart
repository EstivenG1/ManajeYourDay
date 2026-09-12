import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:storage_client/storage_client.dart';

import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

const _monedas = [
  'COP',
  'USD',
  'MXN',
  'EUR',
  'ARS',
  'CLP',
  'PEN',
];

const _idiomas = {
  'es': 'Español',
  'en': 'English',
};

class _PerfilScreenState extends State<PerfilScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();

  String _moneda = 'COP';
  String _idioma = 'es';

  String? _avatarUrl;
  String? _correo;
  String? _nombrePlan;

  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay una sesión activa.');
      }

      final userId = user.id;

      final data = await supabase
          .from('perfiles')
          .select('*, planes(nombre)')
          .eq('id', userId)
          .single();

      _nombreCtrl.text = data['nombre'] ?? '';
      _apellidoCtrl.text = data['apellido'] ?? '';
      _telefonoCtrl.text = data['telefono'] ?? '';
      _ciudadCtrl.text = data['ciudad'] ?? '';
      _paisCtrl.text = data['pais'] ?? '';

      _moneda = data['moneda'] ?? 'COP';
      _idioma = data['idioma'] ?? 'es';

      _avatarUrl = data['avatar_url'];
      _correo = data['correo'];

      _nombrePlan = data['planes']?['nombre'] ?? 'Basico';

      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _ciudadCtrl.dispose();
    _paisCtrl.dispose();

    super.dispose();
  }

  // ============================================================
  // CAMBIAR FOTO DE PERFIL
  // ============================================================

  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();

    final archivo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (archivo == null) return;

    if (!mounted) return;

    setState(() {
      _subiendoFoto = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay una sesión de usuario activa.');
      }

      final userId = user.id;

      // readAsBytes() ya devuelve Uint8List.
      final bytes = await archivo.readAsBytes();

      // Ruta de la imagen dentro del bucket.
      final ruta = '$userId/avatar.jpg';

      // Subir o reemplazar la imagen.
      await supabase.storage.from('avatars').uploadBinary(
            ruta,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Obtener URL pública.
      final url = supabase.storage
          .from('avatars')
          .getPublicUrl(ruta);

      // Evitar caché del navegador.
      final urlSinCache =
          '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      // Guardar URL en la tabla perfiles.
      await supabase
          .from('perfiles')
          .update({
            'avatar_url': urlSinCache,
          })
          .eq('id', userId);

      if (!mounted) return;

      setState(() {
        _avatarUrl = urlSinCache;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto de perfil actualizada ✅'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo subir la foto: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _subiendoFoto = false;
        });
      }
    }
  }

  // ============================================================
  // GUARDAR PERFIL
  // ============================================================

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('No hay una sesión activa.');
      }

      final userId = user.id;

      await supabase
          .from('perfiles')
          .update({
            'nombre': _nombreCtrl.text.trim(),
            'apellido': _apellidoCtrl.text.trim().isEmpty
                ? null
                : _apellidoCtrl.text.trim(),
            'telefono': _telefonoCtrl.text.trim(),
            'ciudad': _ciudadCtrl.text.trim().isEmpty
                ? null
                : _ciudadCtrl.text.trim(),
            'pais': _paisCtrl.text.trim().isEmpty
                ? null
                : _paisCtrl.text.trim(),
            'moneda': _moneda,
            'idioma': _idioma,
          })
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado ✅'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  // ============================================================
  // ELIMINAR CUENTA
  // ============================================================

  void _confirmarEliminarCuenta() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Por seguridad, eliminar una cuenta definitivamente requiere '
          'un proceso en el servidor que todavía no está construido '
          '(para evitar borrados accidentales o no autorizados). '
          'Cuando esté listo, desde aquí mismo podrás solicitarlo. '
          'Por ahora, si necesitas eliminar tu cuenta, contacta al '
          'equipo de MYD.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: const Text('Mi perfil'),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Mi perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _avatar(),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  _correo ?? '',
                  style: AppTypography.secondary,
                ),
              ),

              const SizedBox(height: 6),

              Center(
                child: _badgePlan(),
              ),

              const SizedBox(height: 28),

              _seccionTitulo('DATOS PERSONALES'),

              Row(
                children: [
                  Expanded(
                    child: _campo(
                      'Nombre',
                      _nombreCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      'Apellido (opcional)',
                      _apellidoCtrl,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _campo(
                'Teléfono',
                _telefonoCtrl,
                tipoTeclado: TextInputType.phone,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _campo(
                      'Ciudad',
                      _ciudadCtrl,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _campo(
                      'País',
                      _paisCtrl,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              _seccionTitulo('PREFERENCIAS'),

              Row(
                children: [
                  Expanded(
                    child: _selectorMoneda(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _selectorIdioma(),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius:
                        BorderRadius.circular(AppRadii.xl2),
                    boxShadow:
                        AppColors.sombraPremium(AppColors.gold),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(AppRadii.xl2),
                      onTap: _guardando ? null : _guardar,
                      child: Center(
                        child: _guardando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              _seccionTitulo(
                'ZONA DE PELIGRO',
                color: AppColors.red,
              ),

              const SizedBox(height: 8),

              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(
                    color: AppColors.red,
                  ),
                ),
                onPressed: _confirmarEliminarCuenta,
                child: const Text(
                  'Eliminar cuenta',
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatar() {
    return GestureDetector(
      onTap: _subiendoFoto ? null : _cambiarFoto,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.goldChipBg,
            backgroundImage: _avatarUrl != null
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl == null
                ? Text(
                    _nombreCtrl.text.isNotEmpty
                        ? _nombreCtrl.text[0].toUpperCase()
                        : '👤',
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.goldDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),

          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _subiendoFoto
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PLAN
  // ============================================================

  Widget _badgePlan() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.goldChipBg,
        borderRadius:
            BorderRadius.circular(AppRadii.full),
        border: Border.all(
          color: AppColors.goldBorder,
        ),
      ),
      child: Text(
        'Plan ${_nombrePlan ?? "Básico"}',
        style: const TextStyle(
          color: AppColors.goldDeep,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  // ============================================================
  // TITULOS
  // ============================================================

  Widget _seccionTitulo(
    String texto, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Text(
        texto,
        style: AppTypography.sectionLabel.copyWith(
          color: color,
        ),
      ),
    );
  }

  // ============================================================
  // CAMPOS
  // ============================================================

  Widget _campo(
    String etiqueta,
    TextEditingController controller, {
    TextInputType? tipoTeclado,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style:
              AppTypography.secondary.copyWith(
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 4),

        TextField(
          controller: controller,
          keyboardType: tipoTeclado,
        ),
      ],
    );
  }

  // ============================================================
  // MONEDA
  // ============================================================

  Widget _selectorMoneda() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'MONEDA',
          style:
              AppTypography.secondary.copyWith(
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 4),

        DropdownButtonFormField<String>(
          initialValue: _moneda,
          items: _monedas
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(m),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _moneda = v ?? 'COP';
            });
          },
        ),
      ],
    );
  }

  // ============================================================
  // IDIOMA
  // ============================================================

  Widget _selectorIdioma() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'IDIOMA',
          style:
              AppTypography.secondary.copyWith(
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 4),

        DropdownButtonFormField<String>(
          initialValue: _idioma,
          items: _idiomas.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() {
              _idioma = v ?? 'es';
            });
          },
        ),
      ],
    );
  }
}