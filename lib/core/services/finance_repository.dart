import 'package:supabase_flutter/supabase_flutter.dart';

class FinanceTotals {
  const FinanceTotals({required this.income, required this.expenses});

  final double income;
  final double expenses;

  factory FinanceTotals.fromRpcResponse(Object? response) {
    if (response is! List || response.length != 1 || response.single is! Map) {
      throw const FormatException('Finance totals response is invalid.');
    }

    final row = response.single as Map;
    final income = row['income_total'];
    final expenses = row['expense_total'];
    if (income is! num || expenses is! num) {
      throw const FormatException('Finance totals response is invalid.');
    }

    return FinanceTotals(
      income: income.toDouble(),
      expenses: expenses.toDouble(),
    );
  }
}

class BudgetSpending {
  const BudgetSpending(this.byBudgetId);

  final Map<String, double> byBudgetId;

  factory BudgetSpending.fromRpcResponse(Object? response) {
    if (response is! List) {
      throw const FormatException('Budget spending response is invalid.');
    }

    final totals = <String, double>{};
    for (final item in response) {
      if (item is! Map ||
          item['budget_id'] is! String ||
          item['spent_amount'] is! num) {
        throw const FormatException('Budget spending response is invalid.');
      }
      totals[item['budget_id'] as String] = (item['spent_amount'] as num)
          .toDouble();
    }

    return BudgetSpending(Map.unmodifiable(totals));
  }
}

class FinanceOverview {
  const FinanceOverview({
    required this.recentTransactions,
    required this.totals,
  });

  final List<Map<String, dynamic>> recentTransactions;
  final FinanceTotals totals;
}

class FinanceRepository {
  const FinanceRepository(this._client);

  final SupabaseClient _client;

  Future<FinanceOverview> loadOverview(String userId) async {
    final transactions = await _client
        .from('movimientos')
        .select('*, categorias(nombre, icono)')
        .eq('usuario_id', userId)
        .order('fecha', ascending: false)
        .order('creado_en', ascending: false)
        .limit(50);
    final totalsResponse = await _client.rpc('get_my_finance_totals');

    return FinanceOverview(
      recentTransactions: List<Map<String, dynamic>>.from(transactions),
      totals: FinanceTotals.fromRpcResponse(totalsResponse),
    );
  }

  Future<Map<String, double>> loadBudgetSpending() async {
    final response = await _client.rpc('get_my_budget_spending');
    return BudgetSpending.fromRpcResponse(response).byBudgetId;
  }
}
