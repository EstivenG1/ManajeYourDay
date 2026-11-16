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
import '../../core/services/profile_avatar_service.dart';
import '../legal/centro_ayuda_screen.dart';

class PerfilScreen extends StatefulWidget {
  final Future<void> Function()? onReplayTour;
  final bool soloPlanes;

  const PerfilScreen({super.key, this.onReplayTour, this.soloPlanes = false});

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
  bool get _supportsMercadoPagoCheckout =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

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
  String? _portadaUrl;
  String? _correo;
  String? _errorCarga;
  double _escalaTexto = 1;

  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoFoto = false;
  bool _subiendoPortada = false;
  bool _cargandoPlan = true;
  bool _actualizandoPlan = false;
  bool _iniciandoCheckout = false;
  bool _hasUsedPremiumTrial = false;
  bool _upgradePromotionAvailable = false;
  PlanTier? _plan;
  PlanSubscriptionDetails? _suscripcion;
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
    if (!widget.soloPlanes) {
      _cargarPerfil();
    }
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
    var upgradePromotionAvailable = false;
    try {
      try {
        upgradePromotionAvailable =
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
      final subscription = await PlanService.loadCurrentUserSubscription();
      final hasUsedPremiumTrial = await PlanService.hasUsedPremiumTrial();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _suscripcion = subscription;
        _hasUsedPremiumTrial = hasUsedPremiumTrial;
        _upgradePromotionAvailable = upgradePromotionAvailable;
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

  Future<void> _iniciarCheckout(
    PlanTier plan,
    PlanBillingPeriod period, {
    int trialDays = 0,
  }) async {
    setState(() => _iniciandoCheckout = true);
    try {
      final checkout = await PlanService.startSubscriptionCheckout(
        plan,
        period,
        trialDays: trialDays,
      );
      if (!mounted) {
        await PlanService.cancelCurrentUserSubscription();
        return;
      }
      bool didLaunch;
      try {
        didLaunch = await launchUrl(
          checkout.checkoutUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (error) {
        debugPrint('Unable to open Mercado Pago checkout: $error');
        await _cerrarCheckoutNoAbierto();
        rethrow;
      }
      if (!mounted) return;
      if (!didLaunch) {
        await _cerrarCheckoutNoAbierto();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No se pudo abrir Mercado Pago. Puedes volver a intentarlo.',
                'Could not open Mercado Pago. You can try again.',
              ),
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              'Al terminar o volver de Mercado Pago, actualiza tu plan. Puedes reabrir el checkout si aún no finalizas.',
              'After finishing or returning from Mercado Pago, refresh your plan. You can reopen checkout if you have not completed it.',
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Unable to initiate subscription checkout: $error');
      if (mounted) {
        await _cargarPlan();
        if (!mounted) return;
        final message = error is PlanCheckoutConflictException
            ? appText(
                context,
                'Este checkout ya existe. Ya puedes reabrirlo desde el estado de tu plan.',
                'This checkout already exists. You can reopen it from your plan status.',
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

  Future<void> _cerrarCheckoutNoAbierto() async {
    try {
      await PlanService.cancelCurrentUserSubscription();
      await _cargarPlan();
    } catch (error) {
      debugPrint('Unable to close checkout that did not open: $error');
    }
  }

  Future<void> _mostrarInformacionPlan(PlanTier tier) async {
    final title = appText(
      context,
      'Guía del plan ${tier.label}',
      '${tier.label} plan guide',
    );
    final description = switch (tier) {
      PlanTier.free => appText(
        context,
        'Para organizar tus finanzas y tareas sin pagar. Incluye las herramientas esenciales y límites para empezar.',
        'Organize your finances and tasks for free. Includes essential tools with starter limits.',
      ),
      PlanTier.standard => appText(
        context,
        'Para usar MYD con más capacidad y guardar tus reportes en Excel.',
        'For using MYD with more capacity and saving reports to Excel.',
      ),
      PlanTier.premium => appText(
        context,
        'Para aprovechar MYD al máximo: sin límites de plan en tareas, movimientos y elementos activos, con exportación PDF.',
        'For getting the most out of MYD: no plan limits on tasks, transactions, and active items, plus PDF export.',
      ),
    };
    final benefits = switch (tier) {
      PlanTier.free => [
        appText(context, '50 tareas nuevas por mes', '50 new tasks per month'),
        appText(
          context,
          '100 movimientos nuevos por mes',
          '100 new transactions per month',
        ),
        appText(context, '2 presupuestos activos', '2 active budgets'),
        appText(context, '2 metas activas', '2 active goals'),
        appText(
          context,
          '3 recordatorios financieros activos',
          '3 active financial reminders',
        ),
        appText(context, '3 recibos por mes', '3 receipts per month'),
        appText(
          context,
          'Reportes diarios, semanales y mensuales; exportación CSV.',
          'Daily, weekly, and monthly reports; CSV export.',
        ),
      ],
      PlanTier.standard => [
        appText(
          context,
          '500 tareas nuevas por mes',
          '500 new tasks per month',
        ),
        appText(
          context,
          '1.000 movimientos nuevos por mes',
          '1,000 new transactions per month',
        ),
        appText(context, '10 presupuestos activos', '10 active budgets'),
        appText(context, '10 metas activas', '10 active goals'),
        appText(
          context,
          '25 recordatorios financieros activos',
          '25 active financial reminders',
        ),
        appText(context, '30 recibos por mes', '30 receipts per month'),
        appText(
          context,
          'Reportes y exportación CSV y Excel.',
          'Reports and CSV and Excel export.',
        ),
      ],
      PlanTier.premium => [
        appText(
          context,
          'Tareas sin límite de plan',
          'Tasks with no plan limit',
        ),
        appText(
          context,
          'Movimientos sin límite de plan',
          'Transactions with no plan limit',
        ),
        appText(
          context,
          'Presupuestos, metas y recordatorios activos sin límite de plan',
          'Active budgets, goals, and reminders with no plan limit',
        ),
        appText(context, '100 recibos por mes', '100 receipts per month'),
        appText(
          context,
          'Reportes y exportación CSV, Excel y PDF.',
          'Reports and CSV, Excel, and PDF export.',
        ),
      ],
    };
    final guidance = appText(
      context,
      'Los topes mensuales se cuentan según la fecha de creación o carga; los presupuestos, metas y recordatorios cuentan solo los elementos activos. Al cambiar a un plan menor no se borran tus datos, pero podrías tener que reducir elementos activos para crear otros.',
      'Monthly limits count items by their creation or upload date; budgets, goals, and reminders count only active items. Downgrading does not delete your data, but you may need to reduce active items before creating more.',
    );
    final price = PlanService.priceCopFor(tier, _periodoSeleccionado);
    final billingInterval = appText(
      context,
      _periodoSeleccionado == PlanBillingPeriod.monthly ? 'mes' : 'año',
      _periodoSeleccionado == PlanBillingPeriod.monthly ? 'month' : 'year',
    );
    final priceDescription = price == null
        ? appText(context, 'Gratis', 'Free')
        : '\$${_formatearPrecioCop(price)} COP / $billingInterval';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                priceDescription,
                style: AppTypography.itemTitle.copyWith(color: AppColors.gold),
              ),
              const SizedBox(height: 8),
              Text(description, style: AppTypography.secondary),
              const SizedBox(height: 16),
              Text(
                appText(context, 'Qué incluye', 'What is included'),
                style: AppTypography.itemTitle,
              ),
              const SizedBox(height: 8),
              ...benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                        child: Text(benefit, style: AppTypography.secondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appText(
                  context,
                  'Cómo se cuentan los límites',
                  'How limits work',
                ),
                style: AppTypography.itemTitle,
              ),
              const SizedBox(height: 6),
              Text(guidance, style: AppTypography.secondary),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(appText(context, 'Cerrar', 'Close')),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarGuiaGeneralPlanes() async {
    Widget opcion({
      required IconData icon,
      required String titulo,
      required String descripcion,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.goldDeep),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppTypography.itemTitle),
                  const SizedBox(height: 3),
                  Text(descripcion, style: AppTypography.secondary),
                ],
              ),
            ),
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.workspace_premium_outlined, color: AppColors.goldDeep),
        title: Text(appText(context, 'Guía de Planes MYD', 'MYD plans guide')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appText(
                  context,
                  'Elige según el espacio y las herramientas que necesitas:',
                  'Choose based on the capacity and tools you need:',
                ),
                style: AppTypography.secondary,
              ),
              const SizedBox(height: 18),
              opcion(
                icon: Icons.eco_outlined,
                titulo: appText(context, 'Gratis', 'Free'),
                descripcion: appText(
                  context,
                  'Herramientas esenciales para organizar tareas y finanzas, con exportación CSV.',
                  'Essential tools for organizing tasks and finances, with CSV export.',
                ),
              ),
              opcion(
                icon: Icons.star_outline_rounded,
                titulo: appText(context, 'Estándar', 'Standard'),
                descripcion: appText(
                  context,
                  'Más capacidad para tus registros y exportación de reportes a Excel.',
                  'More capacity for your records and report export to Excel.',
                ),
              ),
              opcion(
                icon: Icons.workspace_premium_rounded,
                titulo: 'Premium',
                descripcion: appText(
                  context,
                  'Mayor capacidad y exportación de reportes a PDF.',
                  'Higher capacity and report export to PDF.',
                ),
              ),
              Text(
                appText(
                  context,
                  'Toca el icono de información de cada plan para consultar sus límites y beneficios. Si cambias a un plan menor, tus datos se conservan; los límites solo pueden restringir la creación de elementos nuevos.',
                  'Tap a plan’s information icon to review its limits and benefits. If you downgrade, your data is kept; limits may only restrict creating new items.',
                ),
                style: AppTypography.secondary,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(appText(context, 'Entendido', 'Got it')),
          ),
        ],
      ),
    );
  }

  Future<void> _continuarCheckout() async {
    final subscription = _suscripcion;
    if (subscription == null || !subscription.canContinueCheckout) return;
    await _iniciarCheckout(
      subscription.plan,
      subscription.billingPeriod,
      trialDays: subscription.trialDays,
    );
  }

  Future<void> _cancelarSuscripcion() async {
    final subscription = _suscripcion;
    if (subscription == null || !subscription.canCancel) return;
    final isPaymentProcessPending = subscription.isPaymentProcessPending;
    final isTrial = subscription.isTrialActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isPaymentProcessPending
              ? appText(
                  context,
                  'Cancelar proceso de pago',
                  'Cancel payment process',
                )
              : isTrial
              ? appText(context, 'Cancelar prueba gratis', 'Cancel free trial')
              : appText(context, 'Cancelar plan', 'Cancel plan'),
        ),
        content: Text(
          appText(
            context,
            isPaymentProcessPending
                ? 'Se cancelará el proceso de pago pendiente del plan ${subscription.plan.label}. Si Mercado Pago sigue abierto, no completes ese proceso. Tu cuenta permanecerá en el plan Gratis.'
                : isTrial
                ? 'Se cancelará tu prueba gratis de Premium y perderás sus beneficios de inmediato. Tu cuenta volverá al plan Gratis y se detendrá el cobro futuro programado.'
                : 'Se cancelará tu plan ${subscription.plan.label} y perderás sus beneficios de inmediato. Tu cuenta volverá al plan Gratis y se detendrán los cobros futuros.',
            isPaymentProcessPending
                ? 'The pending payment process for ${subscription.plan.label} will be canceled. If Mercado Pago is still open, do not complete it. Your account will remain on the Free plan.'
                : isTrial
                ? 'Your Premium free trial will be canceled and you will immediately lose its benefits. Your account will return to the Free plan and the scheduled future charge will stop.'
                : 'Your ${subscription.plan.label} plan will be canceled and you will immediately lose its benefits. Your account will return to the Free plan and future charges will stop.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(appText(context, 'Conservar plan', 'Keep plan')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              isPaymentProcessPending
                  ? appText(context, 'Cancelar proceso', 'Cancel process')
                  : isTrial
                  ? appText(context, 'Cancelar prueba', 'Cancel trial')
                  : appText(context, 'Cancelar plan', 'Cancel plan'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _iniciandoCheckout = true);
    try {
      await PlanService.cancelCurrentUserSubscription();
      await _cargarPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              isPaymentProcessPending
                  ? 'Proceso de pago cancelado. Tu cuenta permanece en el plan Gratis.'
                  : isTrial
                  ? 'Prueba gratis cancelada. Tu cuenta volvió al plan Gratis.'
                  : 'Plan cancelado. Tu cuenta volvió al plan Gratis.',
              isPaymentProcessPending
                  ? 'Payment process canceled. Your account remains on the Free plan.'
                  : isTrial
                  ? 'Free trial canceled. Your account returned to the Free plan.'
                  : 'Plan canceled. Your account returned to the Free plan.',
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Unable to cancel subscription: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No se pudo confirmar la cancelación. Actualiza el estado antes de volver a intentarlo y no inicies otro pago.',
                'Cancellation could not be confirmed. Refresh its status before trying again, and do not start another payment.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _iniciandoCheckout = false);
    }
  }

  Future<void> _mejorarPlanAPremium() async {
    setState(() => _iniciandoCheckout = true);
    try {
      final quote = await PlanService.previewStandardUpgrade();
      if (!mounted) return;
      final amount = _formatearPrecioCop(quote.discountedAmountCop);
      final regularAmount = _formatearPrecioCop(quote.regularAmountCop);
      final billingPeriod = quote.billingPeriod == PlanBillingPeriod.monthly
          ? appText(context, 'mes', 'month')
          : appText(context, 'año', 'year');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            appText(context, 'Mejorar a Premium', 'Upgrade to Premium'),
          ),
          content: Text(
            appText(
              context,
              'Solicitaremos cambiar tu suscripción actual a Premium. El próximo cobro esperado es \$$amount COP por $billingPeriod (50% de descuento); después, \$$regularAmount COP por $billingPeriod. Mercado Pago no garantiza cuándo impactan los cambios de precio: revisa el monto y la fecha en su pantalla antes de confirmar cualquier cobro.',
              'We will request to change your current subscription to Premium. The expected next charge is \$$amount COP per $billingPeriod (50% off); after that, \$$regularAmount COP per $billingPeriod. Mercado Pago does not guarantee when price changes take effect: verify the amount and date on its screen before confirming any charge.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(appText(context, 'Ahora no', 'Not now')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                appText(context, 'Confirmar mejora', 'Confirm upgrade'),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final appliedQuote = await PlanService.upgradeStandardToPremium();
      if (!mounted) return;
      if (appliedQuote.discountedAmountCop != quote.discountedAmountCop ||
          appliedQuote.regularAmountCop != quote.regularAmountCop ||
          appliedQuote.billingPeriod != quote.billingPeriod) {
        await _cargarPlan();
        throw const FormatException('The upgrade amount changed.');
      }

      await _cargarPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              'Premium activado. Próximo cobro: \$$amount COP; después: \$$regularAmount COP por $billingPeriod.',
              'Premium activated. Next charge: \$$amount COP; after that: \$$regularAmount COP per $billingPeriod.',
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('Unable to upgrade subscription: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No se pudo actualizar la suscripción. No inicies otro pago; actualiza el plan o inténtalo más tarde.',
                'Could not update the subscription. Do not start another payment; refresh your plan or try again later.',
              ),
            ),
          ),
        );
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
          .select(
            'nombre,apellido,telefono,ciudad,pais,moneda,idioma,avatar_url,correo',
          )
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

      _avatarUrl = await ProfileAvatarService.resolve(
        data?['avatar_url'] as String?,
      );
      final imagenesPerfil = await supabase.storage
          .from('avatars')
          .list(path: userId);
      if (imagenesPerfil.any((imagen) => imagen.name == 'cover.jpg')) {
        _portadaUrl = await ProfileAvatarService.resolve('$userId/cover.jpg');
      } else {
        _portadaUrl = null;
      }
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

  Future<void> _cambiarPortada() async {
    final archivo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1800,
      maxHeight: 1200,
    );
    if (archivo == null || !mounted) return;

    setState(() => _subiendoPortada = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('No hay una sesión de usuario activa.');
      }
      final ruta = '${user.id}/cover.jpg';
      await supabase.storage
          .from('avatars')
          .uploadBinary(
            ruta,
            await archivo.readAsBytes(),
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      final url = await supabase.storage
          .from('avatars')
          .createSignedUrl(ruta, 3600);
      if (!mounted) return;
      setState(() => _portadaUrl = url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appText(
              context,
              'Foto de portada actualizada.',
              'Cover photo updated.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              appText(
                context,
                'No se pudo actualizar la portada: $error',
                'Could not update the cover photo: $error',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoPortada = false);
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
      final idiomaAnterior = AppSettings.instance.language;
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
      await AppSettings.instance.setRegionalPreferences(
        currency: _moneda,
        language: _idioma,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              idiomaAnterior != _idioma
                  ? appText(
                      context,
                      'Idioma guardado. Cierra y vuelve a abrir MYD para aplicar el cambio.',
                      'Language saved. Close and reopen MYD to apply the change.',
                    )
                  : appText(
                      context,
                      'Perfil actualizado ✅',
                      'Profile updated ✅',
                    ),
            ),
          ),
        );
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
    if (widget.soloPlanes) {
      return Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(appText(context, 'Planes MYD', 'MYD plans')),
          actions: [
            IconButton(
              tooltip: appText(context, 'Guía de planes', 'Plans guide'),
              onPressed: _mostrarGuiaGeneralPlanes,
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(AppRadii.xl2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appText(
                          context,
                          'Elige el plan que va contigo',
                          'Choose the plan that fits you',
                        ),
                        style: AppTypography.screenTitle.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        appText(
                          context,
                          'Compara beneficios, revisa los límites y encuentra el nivel ideal para organizar tu día.',
                          'Compare benefits, review limits, and find the right level to organize your day.',
                        ),
                        style: AppTypography.secondary.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _mostrarGuiaGeneralPlanes,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(
                    appText(
                      context,
                      'Guía de planes y beneficios',
                      'Plans and benefits guide',
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldDeep,
                    side: BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _tarjetaPlan(),
              ],
            ),
          ),
        ),
      );
    }

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
                    _encabezadoPerfil(),

                    const SizedBox(height: 16),

                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        leading: Icon(
                          Icons.manage_accounts_outlined,
                          color: AppColors.goldDeep,
                        ),
                        title: Text(
                          appText(context, 'Datos de usuario', 'User details'),
                          style: AppTypography.itemTitle,
                        ),
                        subtitle: Text(
                          appText(
                            context,
                            'Consulta y edita tu información personal',
                            'View and edit your personal information',
                          ),
                          style: AppTypography.secondary,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _campo(
                                  appText(context, 'Nombre', 'First name'),
                                  _nombreCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _campo(
                                  appText(
                                    context,
                                    'Apellido (opcional)',
                                    'Last name (optional)',
                                  ),
                                  _apellidoCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _campo(
                            appText(context, 'Teléfono', 'Phone'),
                            _telefonoCtrl,
                            tipoTeclado: TextInputType.phone,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _campo(
                                  appText(context, 'Ciudad', 'City'),
                                  _ciudadCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _campo(
                                  appText(context, 'País', 'Country'),
                                  _paisCtrl,
                                ),
                              ),
                            ],
                          ),
                          if ((_correo ?? '').isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.textSecondary,
                              ),
                              title: Text(
                                appText(
                                  context,
                                  'Correo electrónico',
                                  'Email address',
                                ),
                                style: AppTypography.secondary,
                              ),
                              subtitle: Text(
                                _correo!,
                                style: AppTypography.itemTitle,
                              ),
                            ),
                          ],
                        ],
                      ),
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

                    const SizedBox(height: 6),
                    Text(
                      appText(
                        context,
                        'El cambio de idioma se aplicará cuando cierres y vuelvas a abrir MYD.',
                        'The language change will apply after you close and reopen MYD.',
                      ),
                      style: AppTypography.secondary.copyWith(fontSize: 11),
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
                        try {
                          if (value) {
                            final granted =
                                await NotificationService.solicitarPermisos();
                            if (!granted) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    appText(
                                      context,
                                      'Activa el permiso de notificaciones en la configuración del dispositivo para recibir recordatorios.',
                                      'Enable notification permission in your device settings to receive reminders.',
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }
                            await AppSettings.instance.setNotificationsEnabled(
                              true,
                            );
                            await NotificationService.restaurarRecordatorios();
                          } else {
                            await AppSettings.instance.setNotificationsEnabled(
                              false,
                            );
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
    final subscription = _suscripcion;
    final isTrialActive = subscription?.isTrialActive ?? false;
    final planColor = switch (plan) {
      PlanTier.free => AppColors.green,
      PlanTier.standard => AppColors.goldDeep,
      PlanTier.premium => const Color(0xFF7C3AED),
      null => AppColors.gold,
    };
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
                        style: AppTypography.itemTitle.copyWith(
                          color: planColor,
                        ),
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
                  if (subscription != null &&
                      (subscription.isCheckoutPending ||
                          subscription.isPaymentPending ||
                          subscription.status == 'paused'))
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.goldSoftBg,
                        borderRadius: BorderRadius.circular(AppRadii.xl2),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            appText(
                              context,
                              subscription.isCheckoutPending
                                  ? 'Proceso de pago pendiente del plan ${subscription.plan.label}'
                                  : subscription.status == 'paused'
                                  ? 'Suscripción ${subscription.plan.label} pausada'
                                  : 'Tienes un proceso de pago pendiente del plan ${subscription.plan.label}',
                              subscription.isCheckoutPending
                                  ? 'Payment process pending for the ${subscription.plan.label} plan'
                                  : subscription.status == 'paused'
                                  ? '${subscription.plan.label} subscription is paused'
                                  : 'You have a pending payment process for the ${subscription.plan.label} plan',
                            ),
                            style: AppTypography.itemTitle.copyWith(
                              color: AppColors.goldDeep,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subscription.isCheckoutPending
                                ? appText(
                                    context,
                                    'Puedes continuar este proceso cuando quieras. Se conservará el mismo plan y no se creará otra solicitud.',
                                    'You can resume this process whenever you want. The same plan will be kept and no new request will be created.',
                                  )
                                : subscription.status == 'paused'
                                ? appText(
                                    context,
                                    'Esta suscripción está pausada. Cancélala desde MYD para volver a elegir un plan.',
                                    'This subscription is paused. Cancel it from MYD before choosing another plan.',
                                  )
                                : appText(
                                    context,
                                    'Abre Mercado Pago para continuar o revisar el pago. Si sales, podrás volver a entrar desde aquí.',
                                    'Open Mercado Pago to continue or review payment. If you leave, you can reopen it here.',
                                  ),
                            style: AppTypography.secondary,
                          ),
                          const SizedBox(height: 8),
                          if (subscription.canContinueCheckout)
                            FilledButton.icon(
                              onPressed: _iniciandoCheckout
                                  ? null
                                  : _continuarCheckout,
                              icon: Icon(
                                subscription.isCheckoutPending
                                    ? Icons.hourglass_top_rounded
                                    : Icons.open_in_new_rounded,
                              ),
                              label: Text(
                                appText(
                                  context,
                                  subscription.isPaymentPending
                                      ? 'Continuar pago'
                                      : 'Reabrir checkout',
                                  subscription.isPaymentPending
                                      ? 'Continue payment'
                                      : 'Reopen checkout',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (subscription != null && subscription.canCancel)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _iniciandoCheckout
                            ? null
                            : _cancelarSuscripcion,
                        icon: Icon(Icons.cancel_outlined, color: AppColors.red),
                        label: Text(
                          subscription.isPaymentProcessPending
                              ? appText(
                                  context,
                                  'Cancelar proceso de pago (${subscription.plan.label})',
                                  'Cancel payment process (${subscription.plan.label})',
                                )
                              : subscription.isTrialActive
                              ? appText(
                                  context,
                                  'Cancelar prueba gratis de Premium',
                                  'Cancel Premium free trial',
                                )
                              : appText(
                                  context,
                                  'Cancelar plan ${subscription.plan.label} ahora',
                                  'Cancel ${subscription.plan.label} plan now',
                                ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.red),
                        ),
                      ),
                    ),
                  if (isTrialActive)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        appText(
                          context,
                          'Prueba gratis de ${subscription!.trialDays} días activa.',
                          '${subscription.trialDays}-day free trial is active.',
                        ),
                        style: AppTypography.secondary.copyWith(
                          color: AppColors.green,
                        ),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _tarjetaPruebaPremium(plan, subscription),
                  ),
                  if (kIsWeb &&
                      plan != PlanTier.free &&
                      subscription?.status == 'authorized')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        appText(
                          context,
                          plan == PlanTier.standard
                              ? 'Tu suscripción Estándar está activa. Puedes probar la mejora a Premium con 50% de descuento en el próximo cobro; verifica siempre el monto y la fecha en Mercado Pago.'
                              : 'Tu suscripción Premium está activa. Puedes cancelarla ahora desde MYD.',
                          plan == PlanTier.standard
                              ? 'Your Standard subscription is active. You can test the Premium upgrade with 50% off the next charge; always verify the amount and date in Mercado Pago.'
                              : 'Your Premium subscription is active. You can cancel it now from MYD.',
                        ),
                        style: AppTypography.secondary,
                      ),
                    ),
                  if (!_supportsMercadoPagoCheckout)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        appText(
                          context,
                          'La compra con Mercado Pago está disponible en MYD web y en la APK distribuida directamente.',
                          'Mercado Pago purchases are available on MYD web and the directly distributed APK.',
                        ),
                        style: AppTypography.secondary,
                      ),
                    ),
                  if (_supportsMercadoPagoCheckout) ...[
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
    final subscription = _suscripcion;
    final hasUnresolvedSubscription =
        subscription != null &&
        (subscription.isCheckoutPending ||
            subscription.isPaymentPending ||
            subscription.status == 'paused');
    final isCurrent = tier == planActual;
    final isPremiumUpgrade =
        planActual == PlanTier.standard && tier == PlanTier.premium;
    final isUnavailablePremiumUpgrade =
        isPremiumUpgrade && !_upgradePromotionAvailable;
    final tierColor = switch (tier) {
      PlanTier.free => AppColors.green,
      PlanTier.standard => AppColors.goldDeep,
      PlanTier.premium => const Color(0xFF7C3AED),
    };
    final tierBackground = tier == PlanTier.free
        ? AppColors.surface
        : Color.alphaBlend(
            tierColor.withValues(alpha: 0.08),
            AppColors.surface,
          );
    final tierBorder = switch (tier) {
      PlanTier.free => AppColors.borderSoft,
      PlanTier.standard => tierColor.withValues(alpha: 0.65),
      PlanTier.premium => tierColor,
    };
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
      color: tierBackground,
      elevation: tier == PlanTier.premium ? 2 : 0,
      shadowColor: tierColor.withValues(alpha: 0.24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        side: BorderSide(
          color: tierBorder,
          width: tier == PlanTier.premium
              ? 2
              : tier == PlanTier.standard
              ? 1.5
              : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: tier == PlanTier.premium ? 20 : 17,
                  backgroundColor: tierColor.withValues(alpha: 0.13),
                  child: Icon(
                    switch (tier) {
                      PlanTier.free => Icons.eco_outlined,
                      PlanTier.standard => Icons.star_outline_rounded,
                      PlanTier.premium => Icons.workspace_premium_rounded,
                    },
                    size: tier == PlanTier.premium ? 23 : 19,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(switch (tier) {
                    PlanTier.free => tier.label,
                    PlanTier.standard => appText(
                      context,
                      'Estándar ⭐',
                      'Standard ⭐',
                    ),
                    PlanTier.premium => appText(
                      context,
                      'Premium ✨',
                      'Premium ✨',
                    ),
                  }, style: AppTypography.itemTitle.copyWith(color: tierColor)),
                ),
                IconButton(
                  tooltip: appText(
                    context,
                    'Información del plan ${tier.label}',
                    '${tier.label} plan information',
                  ),
                  onPressed: () => _mostrarInformacionPlan(tier),
                  icon: const Icon(Icons.info_outline_rounded),
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
            if (tier == PlanTier.standard)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    appText(
                      context,
                      '⭐ Más espacio para tus planes y finanzas',
                      '⭐ More room for your plans and finances',
                    ),
                    style: AppTypography.secondary.copyWith(
                      color: tierColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (tier == PlanTier.premium)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tierColor,
                      const Color(0xFF9F67E8),
                      const Color(0xFF6D28D9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Text(
                  appText(
                    context,
                    '👑 EXPERIENCIA COMPLETA  ✨  💎',
                    '👑 THE COMPLETE EXPERIENCE  ✨  💎',
                  ),
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
            if (tier != PlanTier.free && isUnavailablePremiumUpgrade)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  appText(
                    context,
                    'La mejora con descuento estará disponible después de validar los cobros reales.',
                    'The discounted upgrade will be available after real-payment validation.',
                  ),
                  style: AppTypography.secondary,
                ),
              ),
            if (tier != PlanTier.free && !isUnavailablePremiumUpgrade)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton(
                  onPressed:
                      isCurrent ||
                          (planActual != PlanTier.free && !isPremiumUpgrade) ||
                          (hasUnresolvedSubscription && !isPremiumUpgrade) ||
                          !(isPremiumUpgrade
                              ? kIsWeb
                              : _supportsMercadoPagoCheckout) ||
                          _iniciandoCheckout
                      ? null
                      : isPremiumUpgrade
                      ? _mejorarPlanAPremium
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
                              : isPremiumUpgrade
                              ? appText(
                                  context,
                                  'Mejorar con 50% en el próximo cobro',
                                  'Upgrade with 50% off the next charge',
                                )
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

  Widget _tarjetaPruebaPremium(
    PlanTier planActual,
    PlanSubscriptionDetails? subscription,
  ) {
    final hasUnresolvedSubscription =
        subscription != null &&
        (subscription.isCheckoutPending ||
            subscription.isPaymentPending ||
            subscription.status == 'paused');
    final price = _formatearPrecioCop(
      PlanService.priceCopFor(PlanTier.premium, PlanBillingPeriod.monthly)!,
    );
    final eligible =
        planActual == PlanTier.free &&
        !_hasUsedPremiumTrial &&
        !hasUnresolvedSubscription &&
        _supportsMercadoPagoCheckout &&
        !_iniciandoCheckout;

    return Card(
      color: AppColors.goldChipBg,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appText(
                      context,
                      'Premium gratis por 7 días',
                      'Premium free for 7 days',
                    ),
                    style: AppTypography.itemTitle,
                  ),
                ),
                Icon(Icons.star_rounded, color: AppColors.gold),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              appText(
                context,
                'Luego \$$price COP / mes',
                'Then \$$price COP / month',
              ),
              style: AppTypography.itemTitle,
            ),
            const SizedBox(height: 8),
            Text(
              appText(
                context,
                'Sin cobro durante los primeros 7 días. Mercado Pago solicitará un medio de pago para iniciar el cobro mensual al terminar la prueba. Cancela antes desde MYD para evitar el siguiente cobro. Disponible una sola vez por cuenta.',
                'No charge during the first 7 days. Mercado Pago will request a payment method to start the monthly charge after the trial. Cancel beforehand from MYD to avoid the next charge. Available once per account.',
              ),
              style: AppTypography.secondary,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: eligible
                  ? () => _iniciarCheckout(
                      PlanTier.premium,
                      PlanBillingPeriod.monthly,
                      trialDays: 7,
                    )
                  : null,
              icon: _iniciandoCheckout
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.card_giftcard_rounded),
              label: Text(
                _hasUsedPremiumTrial
                    ? appText(
                        context,
                        'Prueba gratis ya utilizada',
                        'Free trial already used',
                      )
                    : planActual != PlanTier.free
                    ? appText(
                        context,
                        'Disponible en el plan Gratis',
                        'Available on the Free plan',
                      )
                    : appText(
                        context,
                        'Probar Premium por 7 días',
                        'Try Premium for 7 days',
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

  Widget _encabezadoPerfil() {
    return Column(
      children: [
        SizedBox(
          height: 194,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 154,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xl2),
                  child: Material(
                    color: AppColors.goldSoftBg,
                    child: InkWell(
                      onTap: _subiendoPortada ? null : _cambiarPortada,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_portadaUrl case final String url)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fondoPortada(),
                            )
                          else
                            _fondoPortada(),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.overlayDark,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.full,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_subiendoPortada)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.photo_camera_outlined,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  const SizedBox(width: 6),
                                  Text(
                                    appText(
                                      context,
                                      _portadaUrl == null
                                          ? 'Agregar portada'
                                          : 'Cambiar portada',
                                      _portadaUrl == null
                                          ? 'Add cover'
                                          : 'Change cover',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.sombraPremium(
                        Colors.black,
                        blur: 12,
                        dy: 3,
                      ),
                    ),
                    child: _avatar(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fondoPortada() {
    return Container(
      decoration: BoxDecoration(gradient: AppColors.goldGradient),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white.withValues(alpha: 0.8),
        size: 42,
      ),
    );
  }

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
