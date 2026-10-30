import 'package:flutter_test/flutter_test.dart';

import '../lib/core/services/plan_service.dart';

void main() {
  group('PlanTier.fromDatabaseValue', () {
    test('parses each supported plan', () {
      expect(PlanTier.fromDatabaseValue('free'), PlanTier.free);
      expect(PlanTier.fromDatabaseValue('standard'), PlanTier.standard);
      expect(PlanTier.fromDatabaseValue('premium'), PlanTier.premium);
    });

    test('rejects unknown values instead of granting a fallback plan', () {
      expect(
        () => PlanTier.fromDatabaseValue('administrator'),
        throwsFormatException,
      );
      expect(() => PlanTier.fromDatabaseValue(null), throwsFormatException);
    });
  });

  group('PlanService.limitFor', () {
    test('keeps useful free access and increases paid plan capacity', () {
      expect(
        PlanService.limitFor(PlanTier.free, PlanResource.tasksMonthly),
        50,
      );
      expect(
        PlanService.limitFor(PlanTier.free, PlanResource.transactionsMonthly),
        100,
      );
      expect(
        PlanService.limitFor(PlanTier.free, PlanResource.activeBudgets),
        2,
      );
      expect(PlanService.limitFor(PlanTier.free, PlanResource.activeGoals), 2);
      expect(
        PlanService.limitFor(PlanTier.free, PlanResource.activeRecurring),
        3,
      );
      expect(
        PlanService.limitFor(PlanTier.free, PlanResource.receiptsMonthly),
        3,
      );

      expect(
        PlanService.limitFor(PlanTier.standard, PlanResource.tasksMonthly),
        greaterThan(
          PlanService.limitFor(PlanTier.free, PlanResource.tasksMonthly)!,
        ),
      );
      expect(
        PlanService.limitFor(
          PlanTier.premium,
          PlanResource.transactionsMonthly,
        ),
        isNull,
      );
      expect(
        PlanService.limitFor(PlanTier.premium, PlanResource.receiptsMonthly),
        100,
      );
    });
  });

  group('PlanService.canExport', () {
    test('keeps CSV available on every plan', () {
      for (final tier in PlanTier.values) {
        expect(PlanService.canExport(tier, PlanExportFormat.csv), isTrue);
      }
    });

    test('requires Standard for Excel and Premium for PDF', () {
      expect(
        PlanService.canExport(PlanTier.free, PlanExportFormat.excel),
        isFalse,
      );
      expect(
        PlanService.canExport(PlanTier.standard, PlanExportFormat.excel),
        isTrue,
      );
      expect(
        PlanService.canExport(PlanTier.premium, PlanExportFormat.excel),
        isTrue,
      );
      expect(
        PlanService.canExport(PlanTier.free, PlanExportFormat.pdf),
        isFalse,
      );
      expect(
        PlanService.canExport(PlanTier.standard, PlanExportFormat.pdf),
        isFalse,
      );
      expect(
        PlanService.canExport(PlanTier.premium, PlanExportFormat.pdf),
        isTrue,
      );
    });
  });

  group('PlanService.priceCopFor', () {
    test('matches the published monthly and annual prices', () {
      expect(
        PlanService.priceCopFor(PlanTier.standard, PlanBillingPeriod.monthly),
        12900,
      );
      expect(
        PlanService.priceCopFor(PlanTier.standard, PlanBillingPeriod.annual),
        129000,
      );
      expect(
        PlanService.priceCopFor(PlanTier.premium, PlanBillingPeriod.monthly),
        24900,
      );
      expect(
        PlanService.priceCopFor(PlanTier.premium, PlanBillingPeriod.annual),
        249900,
      );
      expect(
        PlanService.priceCopFor(PlanTier.free, PlanBillingPeriod.monthly),
        isNull,
      );
    });
  });

  group('PlanService.errorMessage', () {
    test('turns the database limit error into a helpful message', () {
      expect(
        PlanService.errorMessage(Exception('PLAN_LIMIT_REACHED:active_goals')),
        contains('metas activas'),
      );
    });
  });
}
