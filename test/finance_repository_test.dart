import 'package:flutter_test/flutter_test.dart';

import 'package:manage_your_day/core/services/finance_repository.dart';

void main() {
  group('FinanceTotals.fromRpcResponse', () {
    test('parses aggregate values returned by Postgres', () {
      final totals = FinanceTotals.fromRpcResponse([
        {'income_total': 1250, 'expense_total': 300.5},
      ]);

      expect(totals.income, 1250);
      expect(totals.expenses, 300.5);
    });

    test('rejects malformed or incomplete aggregate results', () {
      expect(() => FinanceTotals.fromRpcResponse(null), throwsFormatException);
      expect(() => FinanceTotals.fromRpcResponse([]), throwsFormatException);
      expect(
        () => FinanceTotals.fromRpcResponse([
          {'income_total': 'invalid', 'expense_total': 1},
        ]),
        throwsFormatException,
      );
    });
  });

  group('BudgetSpending.fromRpcResponse', () {
    test('indexes aggregate values by budget id', () {
      final spending = BudgetSpending.fromRpcResponse([
        {'budget_id': 'budget-1', 'spent_amount': 420.25},
        {'budget_id': 'budget-2', 'spent_amount': 0},
      ]);

      expect(spending.byBudgetId, {'budget-1': 420.25, 'budget-2': 0});
    });

    test('rejects malformed rows', () {
      expect(
        () => BudgetSpending.fromRpcResponse([
          {'budget_id': 'budget-1', 'spent_amount': 'invalid'},
        ]),
        throwsFormatException,
      );
    });
  });
}
