import 'package:functions_client/functions_client.dart';

import '../supabase/supabase_config.dart';

enum PlanTier {
  free,
  standard,
  premium;

  String get label => switch (this) {
    PlanTier.free => 'Gratis',
    PlanTier.standard => 'Estándar',
    PlanTier.premium => 'Premium',
  };

  static PlanTier fromDatabaseValue(Object? value) {
    return switch (value) {
      'free' => PlanTier.free,
      'standard' => PlanTier.standard,
      'premium' => PlanTier.premium,
      _ => throw FormatException('Unknown subscription plan: $value'),
    };
  }
}

enum PlanResource {
  tasksMonthly('tasks_monthly', 'tareas este mes'),
  transactionsMonthly('transactions_monthly', 'movimientos este mes'),
  activeBudgets('active_budgets', 'presupuestos activos'),
  activeGoals('active_goals', 'metas activas'),
  activeRecurring('active_recurring', 'recordatorios recurrentes activos'),
  receiptsMonthly('receipts_monthly', 'recibos adjuntos este mes');

  const PlanResource(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

enum PlanExportFormat { csv, excel, pdf }

enum PlanBillingPeriod { monthly, annual }

class PlanUpgradeQuote {
  const PlanUpgradeQuote({
    required this.billingPeriod,
    required this.discountedAmountCop,
    required this.regularAmountCop,
  });

  final PlanBillingPeriod billingPeriod;
  final int discountedAmountCop;
  final int regularAmountCop;
}

class PlanCheckout {
  const PlanCheckout({required this.checkoutUri, required this.trialDays});

  final Uri checkoutUri;
  final int trialDays;
}

class PlanLimitException implements Exception {
  const PlanLimitException(this.resource, this.tier);

  final PlanResource resource;
  final PlanTier tier;

  @override
  String toString() =>
      'Alcanzaste el límite de ${resource.label} del plan ${tier.label}. '
      'Puedes cambiar de plan para ampliar el límite.';
}

class PlanCheckoutConflictException implements Exception {
  const PlanCheckoutConflictException();
}

class PlanService {
  PlanService._();

  static Future<PlanTier> loadCurrentUserPlan() async {
    if (supabase.auth.currentUser == null) {
      throw StateError('A signed-in user is required to load a plan.');
    }

    final value = await supabase.rpc('get_my_plan');
    return PlanTier.fromDatabaseValue(value);
  }

  static Future<void> syncCurrentUserSubscription() async {
    if (supabase.auth.currentUser == null) {
      throw StateError('A signed-in user is required to sync a subscription.');
    }

    final response = await supabase.functions.invoke('sync-subscription');
    final data = response.data;
    if (data is! Map ||
        data['status'] is! String ||
        !const {
          'none',
          'checkout_pending',
          'pending',
          'authorized',
          'paused',
          'cancelled',
          'rejected',
          'expired',
        }.contains(data['status'])) {
      throw const FormatException('The subscription sync response is invalid.');
    }
  }

  static Future<PlanUpgradeQuote> previewStandardUpgrade() async {
    if (supabase.auth.currentUser == null) {
      throw StateError('A signed-in user is required to upgrade a plan.');
    }

    final subscription = await supabase
        .from('billing_subscriptions')
        .select('billing_period')
        .eq('plan', 'standard')
        .eq('status', 'authorized')
        .eq('upgrade_in_progress', false)
        .eq('upgrade_discount_pending', false)
        .maybeSingle();
    if (subscription == null) {
      throw StateError('An active Standard subscription is required.');
    }

    final period = switch (subscription['billing_period']) {
      'monthly' => PlanBillingPeriod.monthly,
      'annual' => PlanBillingPeriod.annual,
      _ => throw const FormatException(
        'The subscription billing period is invalid.',
      ),
    };
    return PlanUpgradeQuote(
      billingPeriod: period,
      discountedAmountCop: premiumUpgradeDiscountCopFor(period),
      regularAmountCop: priceCopFor(PlanTier.premium, period)!,
    );
  }

  static Future<PlanUpgradeQuote> upgradeStandardToPremium() async {
    if (supabase.auth.currentUser == null) {
      throw StateError('A signed-in user is required to upgrade a plan.');
    }

    final response = await supabase.functions.invoke('upgrade-subscription');
    final data = response.data;
    if (data is! Map ||
        data['plan'] != 'premium' ||
        (data['billingPeriod'] != 'monthly' &&
            data['billingPeriod'] != 'annual') ||
        data['nextAmountCop'] is! int ||
        data['regularAmountCop'] is! int) {
      throw const FormatException('The upgrade response is invalid.');
    }

    final quote = PlanUpgradeQuote(
      billingPeriod: data['billingPeriod'] == 'annual'
          ? PlanBillingPeriod.annual
          : PlanBillingPeriod.monthly,
      discountedAmountCop: data['nextAmountCop'] as int,
      regularAmountCop: data['regularAmountCop'] as int,
    );
    final expectedRegularAmount = priceCopFor(
      PlanTier.premium,
      quote.billingPeriod,
    );
    if (quote.regularAmountCop != expectedRegularAmount ||
        quote.discountedAmountCop != expectedRegularAmount! ~/ 2) {
      throw const FormatException('The upgrade amount is invalid.');
    }

    return quote;
  }

  static int? limitFor(PlanTier tier, PlanResource resource) {
    return switch ((tier, resource)) {
      (PlanTier.free, PlanResource.tasksMonthly) => 50,
      (PlanTier.standard, PlanResource.tasksMonthly) => 500,
      (PlanTier.premium, PlanResource.tasksMonthly) => null,
      (PlanTier.free, PlanResource.transactionsMonthly) => 100,
      (PlanTier.standard, PlanResource.transactionsMonthly) => 1000,
      (PlanTier.premium, PlanResource.transactionsMonthly) => null,
      (PlanTier.free, PlanResource.activeBudgets) => 2,
      (PlanTier.standard, PlanResource.activeBudgets) => 10,
      (PlanTier.premium, PlanResource.activeBudgets) => null,
      (PlanTier.free, PlanResource.activeGoals) => 2,
      (PlanTier.standard, PlanResource.activeGoals) => 10,
      (PlanTier.premium, PlanResource.activeGoals) => null,
      (PlanTier.free, PlanResource.activeRecurring) => 3,
      (PlanTier.standard, PlanResource.activeRecurring) => 25,
      (PlanTier.premium, PlanResource.activeRecurring) => null,
      (PlanTier.free, PlanResource.receiptsMonthly) => 3,
      (PlanTier.standard, PlanResource.receiptsMonthly) => 30,
      (PlanTier.premium, PlanResource.receiptsMonthly) => 100,
    };
  }

  static bool canExport(PlanTier tier, PlanExportFormat format) {
    return switch (format) {
      PlanExportFormat.csv => true,
      PlanExportFormat.excel => tier != PlanTier.free,
      PlanExportFormat.pdf => tier == PlanTier.premium,
    };
  }

  static int? priceCopFor(PlanTier tier, PlanBillingPeriod period) {
    return switch ((tier, period)) {
      (PlanTier.free, _) => null,
      (PlanTier.standard, PlanBillingPeriod.monthly) => 12900,
      (PlanTier.standard, PlanBillingPeriod.annual) => 129000,
      (PlanTier.premium, PlanBillingPeriod.monthly) => 24900,
      (PlanTier.premium, PlanBillingPeriod.annual) => 249900,
    };
  }

  static int premiumUpgradeDiscountCopFor(PlanBillingPeriod period) {
    final regularAmount = priceCopFor(PlanTier.premium, period);
    if (regularAmount == null) {
      throw StateError('Premium pricing is unavailable.');
    }
    return regularAmount ~/ 2;
  }

  static Future<PlanCheckout> startWebCheckout(
    PlanTier tier,
    PlanBillingPeriod period,
  ) async {
    if (tier == PlanTier.free) {
      throw ArgumentError.value(tier, 'tier', 'Free has no paid checkout.');
    }

    final response = await supabase.functions
        .invoke(
          'start-subscription',
          body: {'plan': tier.name, 'billingPeriod': period.name},
        )
        .catchError((Object error) {
          if (error is FunctionException && error.status == 409) {
            throw const PlanCheckoutConflictException();
          }
          throw error;
        });
    final data = response.data;
    if (data is! Map ||
        data['checkoutUrl'] is! String ||
        (data['trialDays'] != 0 && data['trialDays'] != 7) ||
        (tier != PlanTier.standard && data['trialDays'] != 0)) {
      throw const FormatException('The checkout response is invalid.');
    }

    final checkoutUri = Uri.tryParse(data['checkoutUrl'] as String);
    if (checkoutUri == null ||
        checkoutUri.scheme != 'https' ||
        !(checkoutUri.host == 'mercadopago.com.co' ||
            checkoutUri.host.endsWith('.mercadopago.com.co'))) {
      throw const FormatException('The checkout URL is not trusted.');
    }
    return PlanCheckout(
      checkoutUri: checkoutUri,
      trialDays: data['trialDays'] as int,
    );
  }

  static Future<void> ensureCanCreate(PlanResource resource) async {
    if (supabase.auth.currentUser == null) {
      throw StateError('A signed-in user is required to check plan limits.');
    }

    final allowed = await supabase.rpc(
      'can_create_plan_resource',
      params: {'p_resource': resource.databaseValue},
    );
    if (allowed is! bool) {
      throw const FormatException(
        'The server returned an invalid plan capacity result.',
      );
    }
    if (!allowed) {
      final tier = await loadCurrentUserPlan();
      throw PlanLimitException(resource, tier);
    }
  }

  static String errorMessage(Object error) {
    if (error is PlanLimitException) return error.toString();
    final errorText = error.toString();
    const marker = 'PLAN_LIMIT_REACHED:';
    final markerIndex = errorText.indexOf(marker);
    if (markerIndex < 0) return errorText;

    final resourceValue = errorText
        .substring(markerIndex + marker.length)
        .trim()
        .split(RegExp(r'[\s,}]+'))
        .first;
    final matchingResources = PlanResource.values
        .where((item) => item.databaseValue == resourceValue)
        .toList();
    if (matchingResources.isEmpty) return errorText;

    final resource = matchingResources.first;
    return 'Alcanzaste el límite de ${resource.label} de tu plan. '
        'Puedes cambiar de plan para ampliarlo.';
  }
}
