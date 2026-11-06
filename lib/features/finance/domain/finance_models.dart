class FinanceTotals {
  final int incomeMinor;
  final int expenseMinor;
  final int savedMinor;
  final double? savingsRate; // null means "غير متاح" (income == 0)

  const FinanceTotals({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.savedMinor,
    required this.savingsRate,
  });
}

class NatureShare {
  final int essentialMinor;
  final int sideMinor;
  final double essentialPercent;
  final double sidePercent;

  const NatureShare({
    required this.essentialMinor,
    required this.sideMinor,
    required this.essentialPercent,
    required this.sidePercent,
  });
}

class CategorySpending {
  final int categoryId;
  final String nameAr;
  final String? nameEn;
  final int color;
  final String? icon;
  final int amountMinor;
  final double percent;
  final int count;

  const CategorySpending({
    required this.categoryId,
    required this.nameAr,
    this.nameEn,
    required this.color,
    this.icon,
    required this.amountMinor,
    required this.percent,
    required this.count,
  });
}

class PeriodComparison {
  final int currentExpenseMinor;
  final int previousExpenseMinor;
  final int diffMinor;
  final double percentChange;

  const PeriodComparison({
    required this.currentExpenseMinor,
    required this.previousExpenseMinor,
    required this.diffMinor,
    required this.percentChange,
  });
}

class SmallRecurringItem {
  final int categoryId;
  final String categoryNameAr;
  final int totalAmountMinor;
  final int averageAmountMinor;
  final int count;

  const SmallRecurringItem({
    required this.categoryId,
    required this.categoryNameAr,
    required this.totalAmountMinor,
    required this.averageAmountMinor,
    required this.count,
  });
}

class ObligationsMetrics {
  final int lateCount;
  final int lateAmountMinor;
  final int dueSoonCount;
  final int dueSoonAmountMinor;
  final double onTimeRate; // 0.0 - 100.0

  const ObligationsMetrics({
    required this.lateCount,
    required this.lateAmountMinor,
    required this.dueSoonCount,
    required this.dueSoonAmountMinor,
    required this.onTimeRate,
  });
}
