import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/plan_service.dart';
import '../legal/centro_ayuda_screen.dart';

class PerfilScreen extends StatefulWidget {
  final Future<void> Function()? onReplayTour;

  const PerfilScreen({super.key, this.onReplayTour});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

const _monedas = ['COP', 'USD', 'MXN', 'EUR', 'ARS', 'CLP', 'PEN'];

const _idiomas = {'es': 'Español', 'en': 'English'};

String? _textoMetadata(Map<String, dynamic> metadata, String key) {
  final value = metadata[key];
  return value is String ? value : null;
}

class _PerfilScreenState extends State<PerfilScreen>
    with WidgetsBindingObserver {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _paisCtrl = TextEditingController();

  String _moneda = 'COP';
  String _idioma = 'es';
  bool _modoOscuro = AppSettings.instance.isDark;
  bool _altoContraste = AppSettings.instance.highContrast;

  String? _avatarUrl;
  String? _correo;
  String? _errorCarga;
  double _escalaTexto = 1;

  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _cargandoPlan = true;
  bool _actualizandoPlan = false;
  bool _iniciandoCheckout = false;
  PlanTier? _plan;
  PlanBillingPeriod _periodoSeleccionado = PlanBillingPeriod.monthly;
  String? _errorPlan;
  String? _errorSincronizacionPlan;

  void _mostrarReinicioRequerido() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          appText(
            context,
            'Cambio guardado. Cierra y vuelve a abrir la app para aplicarlo sin ralentizarla.',
            'Change saved. Close and reopen the app to apply it without slowing it down.',
          ),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarPerfil();
    _cargarPlan();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_actualizandoPlan) {
      _cargarPlan();
    }
  }

  Future<void> _cargarPlan() async {
    if (_actualizandoPlan) return;
    _actualizandoPlan = true;
    setState(() {
      _cargandoPlan = true;
      _errorPlan = null;
      _errorSincronizacionPlan = null;
    });
    String? syncError;
    try {
      try {
        await PlanService.syncCurrentUserSubscription();
      } catch (error) {
        debugPrint('Unable to sync Mercado Pago subscription: $error');
        if (!mounted) return;
        syncError = appText(
          context,
          'No se pudo verificar el pago con Mercado Pago. Intenta actualizar de nuevo.',
          'Could not verify the Mercado Pago payment. Try refreshing again.',
        );
      }
      if (!mounted) return;
      final plan = await PlanService.loadCurrentUserPlan();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _cargandoPlan = false;
        _errorSincronizacionPlan = syncError;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorPlan = 'No se pudo consultar tu plan: $error';
        _cargandoPlan = false;
      });
    } finally {
      _actualizandoPlan = false;
    }
  }

  Future<void> _iniciarCheckout(PlanTier plan, PlanBillingPeriod period) async {
    setState(() => _iniciandoCheckout = true);
    try {
      final checkoutUri = await PlanService.startWebCheckout(plan, period);
      if (!mounted) return;
      final opened = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            appText(context, 'Continuar al pago', 'Continue to payment'),
          ),
          content: Text(
            appText(
              context,
              'Mercado Pago abrirá el pago seguro. El plan se activa cuando Supabase confirme la suscripción; volver a esta pantalla no confirma un pago.',
              'Mercado Pago will open the secure checkout. Your plan activates after Supabase confirms the subscription; returning to this screen does not confirm payment.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(appText(context, 'Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final didLaunch = await launchUrl(
                    checkoutUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, didLaunch);
                  }
                } catch (error) {
                  debugPrint('Unable to open Mercado Pago checkout: $error');
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, false);
                  }
                }
              },
              child: Text(
                appText(context, 'Abrir Mercado Pago', 'Open Mercado Pago'),
              ),
            ),
          ],
        ),
      );
      if (opened == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'Al finalizar, vuelve aquí y actualiza el plan.',
                'After checkout, return here and refresh the plan.',
              ),
            ),
          ),
        );
      } else if (opened == false && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No se pudo abrir Mercado Pago.',
                'Could not open Mercado Pago.',
              ),
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Unable to initiate subscription checkout: $error');
      if (mounted) {
        final message = error is PlanCheckoutConflictException
            ? appText(
                context,
                'Hay un pago o una suscripción pendiente. Actualiza el plan o elige el mismo plan para continuar el pago.',
                'A payment or subscription is pending. Refresh your plan or choose the same plan to continue checkout.',
              )
            : appText(
                context,
                'No se pudo iniciar el pago. Inténtalo de nuevo más tarde.',
                'Could not start checkout. Please try again later.',
              );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _iniciandoCheckout = false);
    }
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
          .select()
          .eq('id', userId)
          .maybeSingle();

      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final nombreMetadata =
          _textoMetadata(metadata, 'nombre') ??
          _textoMetadata(metadata, 'full_name') ??
          _textoMetadata(metadata, 'name');
      final nombreCuenta = nombreMetadata is String && nombreMetadata.isNotEmpty
          ? nombreMetadata
          : (user.email?.split('@').first ?? '');

      _nombreCtrl.text = data?['nombre'] as String? ?? nombreCuenta;
      _apellidoCtrl.text =
          data?['apellido'] as String? ??
          _textoMetadata(metadata, 'apellido') ??
          '';
      _telefonoCtrl.text =
          data?['telefono'] as String? ??
          _textoMetadata(metadata, 'telefono') ??
          '';
      _ciudadCtrl.text = data?['ciudad'] as String? ?? '';
      _paisCtrl.text = data?['pais'] as String? ?? '';

      _moneda = data?['moneda'] as String? ?? AppSettings.instance.currency;
      _idioma = data?['idioma'] as String? ?? AppSettings.instance.language;

      final avatarRegistrado = data?['avatar_url'] as String?;
      _avatarUrl = avatarRegistrado == null
          ? null
          : await supabase.storage
                .from('avatars')
                .createSignedUrl('$userId/avatar.jpg', 3600);
      _correo = data?['correo'] as String? ?? user.email;

      _escalaTexto = AppSettings.instance.textScale;
      await AppSettings.instance.setRegionalPreferences(
        currency: _moneda,
        language: _idioma,
      );

      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _errorCarga = 'No se pudo cargar tu perfil: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            ruta,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final url = await supabase.storage
          .from('avatars')
          .createSignedUrl(ruta, 3600);

      // Guardar URL en la tabla perfiles.
      await supabase
          .from('perfiles')
          .upsert(
            _datosPerfilParaGuardar(user, avatarUrl: ruta),
            onConflict: 'id',
          );
      await AppSettings.instance.setRegionalPreferences(
        currency: _moneda,
        language: _idioma,
      );

      if (!mounted) return;

      setState(() {
        _avatarUrl = url;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada ✅')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo subir la foto: $e')));
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

      await supabase
          .from('perfiles')
          .upsert(
            _datosPerfilParaGuardar(user, avatarUrl: _avatarUrl),
            onConflict: 'id',
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Perfil actualizado ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Map<String, dynamic> _datosPerfilParaGuardar(User user, {String? avatarUrl}) {
    return {
      'id': user.id,
      'correo': user.email,
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim().isEmpty
          ? null
          : _apellidoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'ciudad': _ciudadCtrl.text.trim().isEmpty
          ? null
          : _ciudadCtrl.text.trim(),
      'pais': _paisCtrl.text.trim().isEmpty ? null : _paisCtrl.text.trim(),
      'moneda': _moneda,
      'idioma': _idioma,
      'avatar_url': avatarUrl == null ? null : '${user.id}/avatar.jpg',
    };
  }

  // ============================================================
  // ELIMINAR CUENTA
  // ============================================================

  Future<void> _confirmarEliminarCuenta() async {
    final confirmacionCtrl = TextEditingController();
    final confirmada = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción es permanente y eliminará tu cuenta y los datos '
          'asociados. Escribe ELIMINAR para confirmar.',
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: confirmacionCtrl,
              decoration: const InputDecoration(hintText: 'ELIMINAR'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              confirmacionCtrl.text.trim() == 'ELIMINAR',
            ),
            child: const Text('Eliminar definitivamente'),
          ),
        ],
      ),
    );
    final frase = confirmacionCtrl.text.trim();
    confirmacionCtrl.dispose();
    if (confirmada != true || frase != 'ELIMINAR') {
      if (confirmada == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe ELIMINAR para confirmar.')),
        );
      }
      return;
    }

    try {
      setState(() => _guardando = true);
      await supabase.functions.invoke('delete-account');
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu cuenta fue eliminada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
          title: Text(appText(context, 'Mi perfil', 'My profile')),
        ),
        body: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(appText(context, 'Mi perfil', 'My profile'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _errorCarga != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorCarga!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _cargarPerfil,
                      child: Text(appText(context, 'Reintentar', 'Retry')),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _avatar()),

                    const SizedBox(height: 8),

                    Center(
                      child: Text(
                        _correo ?? '',
                        style: AppTypography.secondary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      appText(
                        context,
                        'Consulta el nivel y los límites de tu cuenta.',
                        'See your account plan and limits.',
                      ),
                      textAlign: TextAlign.center,
                      style: AppTypography.secondary,
                    ),

                    const SizedBox(height: 12),
                    _tarjetaPlan(),
                    const SizedBox(height: 28),

                    _seccionTitulo(
                      appText(context, 'DATOS PERSONALES', 'PERSONAL DETAILS'),
                    ),

                    Row(
                      children: [
                        Expanded(child: _campo('Nombre', _nombreCtrl)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _campo('Apellido (opcional)', _apellidoCtrl),
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
                        Expanded(child: _campo('Ciudad', _ciudadCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _campo('País', _paisCtrl)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    _seccionTitulo(
                      appText(context, 'AYUDA Y LEGAL', 'HELP AND LEGAL'),
                    ),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.help_outline_rounded,
                          color: AppColors.gold,
                        ),
                        title: Text(
                          appText(context, 'Centro de ayuda', 'Help center'),
                          style: AppTypography.itemTitle,
                        ),
                        subtitle: Text(
                          appText(
                            context,
                            'Guías de funciones, recorrido y documentos legales',
                            'Feature guides, app tour, and legal documents',
                          ),
                          style: AppTypography.secondary,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CentroAyudaScreen(
                              onReplayTour: widget.onReplayTour,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _seccionTitulo(
                      appText(context, 'PREFERENCIAS', 'PREFERENCES'),
                    ),

                    Row(
                      children: [
                        Expanded(child: _selectorMoneda()),
                        const SizedBox(width: 12),
                        Expanded(child: _selectorIdioma()),
                      ],
                    ),

                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(appText(context, 'Modo oscuro', 'Dark mode')),
                      subtitle: Text(
                        appText(
                          context,
                          'Usar una apariencia oscura en la app',
                          'Use a dark appearance',
                        ),
                      ),
                      value: _modoOscuro,
                      onChanged: (value) async {
                        setState(() => _modoOscuro = value);
                        await AppSettings.instance.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                        if (mounted) _mostrarReinicioRequerido();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        appText(context, 'Alto contraste', 'High contrast'),
                      ),
                      subtitle: Text(
                        appText(
                          context,
                          'Aumentar el contraste de textos y bordes',
                          'Increase text and border contrast',
                        ),
                      ),
                      value: _altoContraste,
                      onChanged: (value) async {
                        setState(() => _altoContraste = value);
                        await AppSettings.instance.setHighContrast(value);
                        if (mounted) _mostrarReinicioRequerido();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        appText(context, 'Notificaciones', 'Notifications'),
                      ),
                      subtitle: Text(
                        appText(
                          context,
                          'Recordatorios de tareas, metas y pagos',
                          'Task, goal, and bill reminders',
                        ),
                      ),
                      value: AppSettings.instance.notificationsEnabled,
                      onChanged: (value) async {
                        await AppSettings.instance.setNotificationsEnabled(
                          value,
                        );
                        try {
                          if (value) {
                            await NotificationService.solicitarPermisos();
                            await NotificationService.restaurarRecordatorios();
                          } else {
                            await NotificationService.cancelarTodas();
                          }
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                appText(
                                  context,
                                  'No se pudieron actualizar los recordatorios. Inténtalo de nuevo.',
                                  'Could not update reminders. Please try again.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${appText(context, 'Tamaño del texto', 'Text size')}: '
                            '${(_escalaTexto * 100).round()}%',
                            style: AppTypography.itemTitle,
                          ),
                          Slider(
                            value: _escalaTexto,
                            min: 0.85,
                            max: 1.4,
                            divisions: 11,
                            label: '${(_escalaTexto * 100).round()}%',
                            onChanged: (value) {
                              setState(() => _escalaTexto = value);
                              AppSettings.instance.setTextScale(value);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      height: 52,
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
                      appText(context, 'ZONA DE PELIGRO', 'DANGER ZONE'),
                      color: AppColors.red,
                    ),

                    const SizedBox(height: 8),

                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: BorderSide(color: AppColors.red),
                      ),
                      onPressed: _confirmarEliminarCuenta,
                      child: Text(
                        appText(context, 'Eliminar cuenta', 'Delete account'),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _tarjetaPlan() {
    final plan = _plan;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _cargandoPlan
            ? const Center(child: CircularProgressIndicator())
            : _errorPlan != null
            ? Column(
                children: [
                  Text(_errorPlan!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _cargarPlan,
                    child: Text(appText(context, 'Reintentar', 'Retry')),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(
                        '${appText(context, 'Plan actual', 'Current plan')}: ${plan!.label}',
                        style: AppTypography.itemTitle,
                      ),
                    ],
                  ),
                  if (_errorSincronizacionPlan != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorSincronizacionPlan!,
                        style: AppTypography.secondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  ...PlanResource.values.map((resource) {
                    final limit = PlanService.limitFor(plan, resource);
                    final limitText = switch (limit) {
                      null => appText(
                        context,
                        'Sin límite del plan',
                        'No plan limit',
                      ),
                      _ => '${appText(context, 'Hasta', 'Up to')} $limit',
                    };
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              resource.label,
                              style: AppTypography.secondary,
                            ),
                          ),
                          Text(limitText, style: AppTypography.secondary),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    appText(
                      context,
                      'Los límites mensuales se reinician cada mes. Los datos existentes no se eliminan al cambiar de plan.',
                      'Monthly limits reset each month. Existing data is not deleted when changing plans.',
                    ),
                    style: AppTypography.secondary,
                  ),
                  const Divider(height: 28),
                  Text(
                    appText(context, 'Compara los planes', 'Compare plans'),
                    style: AppTypography.itemTitle,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PlanBillingPeriod>(
                    segments: [
                      ButtonSegment(
                        value: PlanBillingPeriod.monthly,
                        label: Text(appText(context, 'Mensual', 'Monthly')),
                      ),
                      ButtonSegment(
                        value: PlanBillingPeriod.annual,
                        label: Text(appText(context, 'Anual', 'Annual')),
                      ),
                    ],
                    selected: {_periodoSeleccionado},
                    onSelectionChanged: (selection) {
                      setState(() => _periodoSeleccionado = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  ...PlanTier.values.map(
                    (tier) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _tarjetaOfertaPlan(tier, plan),
                    ),
                  ),
                  if (kIsWeb && plan != PlanTier.free)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        appText(
                          context,
                          'Ya tienes una suscripción activa. La renovación y cancelación todavía no se pueden administrar desde MYD.',
                          'You already have an active subscription. Renewal and cancellation are not yet available in MYD.',
                        ),
                        style: AppTypography.secondary,
                      ),
                    ),
                  if (!kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        appText(
                          context,
                          'La compra está disponible en la versión web de MYD.',
                          'Purchases are available in the MYD web app.',
                        ),
                        style: AppTypography.secondary,
                      ),
                    ),
                  if (kIsWeb) ...[
                    TextButton.icon(
                      onPressed: _cargandoPlan ? null : _cargarPlan,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        appText(context, 'Actualizar plan', 'Refresh plan'),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _tarjetaOfertaPlan(PlanTier tier, PlanTier planActual) {
    final isCurrent = tier == planActual;
    final price = PlanService.priceCopFor(tier, _periodoSeleccionado);
    final priceLabel = price == null
        ? appText(context, 'Gratis', 'Free')
        : '\$${_formatearPrecioCop(price)} COP / '
              '${_periodoSeleccionado == PlanBillingPeriod.monthly ? appText(context, 'mes', 'month') : appText(context, 'año', 'year')}';
    final features = switch (tier) {
      PlanTier.free => [
        appText(
          context,
          'Hasta 50 tareas nuevas al mes',
          'Up to 50 new tasks per month',
        ),
        appText(
          context,
          'Hasta 100 movimientos al mes',
          'Up to 100 transactions per month',
        ),
        appText(
          context,
          '2 presupuestos y 2 metas activas',
          '2 active budgets and 2 active goals',
        ),
        appText(
          context,
          'Reportes y exportación CSV',
          'Reports and CSV export',
        ),
      ],
      PlanTier.standard => [
        appText(
          context,
          'Hasta 500 tareas y 1.000 movimientos al mes',
          'Up to 500 tasks and 1,000 transactions per month',
        ),
        appText(
          context,
          'Hasta 10 presupuestos y 10 metas activas',
          'Up to 10 active budgets and 10 active goals',
        ),
        appText(
          context,
          '25 recordatorios y 30 recibos al mes',
          '25 reminders and 30 receipts per month',
        ),
        appText(context, 'Exportación CSV y Excel', 'CSV and Excel export'),
      ],
      PlanTier.premium => [
        appText(
          context,
          'Tareas, movimientos, presupuestos y metas sin límite del plan',
          'Tasks, transactions, budgets, and goals with no plan limit',
        ),
        appText(
          context,
          'Hasta 100 recibos al mes',
          'Up to 100 receipts per month',
        ),
        appText(
          context,
          'Exportación CSV, Excel y PDF',
          'CSV, Excel, and PDF export',
        ),
      ],
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tier.label, style: AppTypography.itemTitle),
                ),
                if (isCurrent)
                  Chip(
                    label: Text(
                      appText(context, 'Plan actual', 'Current plan'),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(priceLabel, style: AppTypography.itemTitle),
            const SizedBox(height: 8),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(feature, style: AppTypography.secondary),
                    ),
                  ],
                ),
              ),
            ),
            if (tier != PlanTier.free)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton(
                  onPressed:
                      isCurrent ||
                          planActual != PlanTier.free ||
                          !kIsWeb ||
                          _iniciandoCheckout
                      ? null
                      : () => _iniciarCheckout(tier, _periodoSeleccionado),
                  child: _iniciandoCheckout && !isCurrent
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isCurrent
                              ? appText(context, 'Plan activo', 'Active plan')
                              : appText(
                                  context,
                                  'Elegir ${tier.label}',
                                  'Choose ${tier.label}',
                                ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatearPrecioCop(int amount) {
    final digits = amount.toString();
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(digits[index]);
    }
    return grouped.toString();
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
                    style: TextStyle(
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
              decoration: BoxDecoration(
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
                  : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TITULOS
  // ============================================================

  Widget _seccionTitulo(String texto, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: AppTypography.sectionLabel.copyWith(color: color),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTypography.secondary.copyWith(fontSize: 11)),

        const SizedBox(height: 4),

        TextField(controller: controller, keyboardType: tipoTeclado),
      ],
    );
  }

  // ============================================================
  // MONEDA
  // ============================================================

  Widget _selectorMoneda() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MONEDA', style: AppTypography.secondary.copyWith(fontSize: 11)),

        const SizedBox(height: 4),

        DropdownButtonFormField<String>(
          initialValue: _moneda,
          items: _monedas
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IDIOMA', style: AppTypography.secondary.copyWith(fontSize: 11)),

        const SizedBox(height: 4),

        DropdownButtonFormField<String>(
          initialValue: _idioma,
          items: _idiomas.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
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
