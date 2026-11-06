import '../../../core/db/app_database.dart';
import 'finance_models.dart';

class FinanceService {
  const FinanceService();

  /// Calculate totals: income, expense, saved, and savings rate
  FinanceTotals calculateTotals(List<Transaction> transactions) {
    int income = 0;
    int expense = 0;

    for (final tx in transactions) {
      if (tx.kind == 'income') {
        income += tx.amountMinor;
      } else if (tx.kind == 'expense') {
        expense += tx.amountMinor;
      }
    }

    final saved = income - expense;
    final double? savingsRate = income > 0 ? (saved / income) : null;

    return FinanceTotals(
      incomeMinor: income,
      expenseMinor: expense,
      savedMinor: saved,
      savingsRate: savingsRate,
    );
  }

  /// Calculate essential vs side shares in amount and percentage
  NatureShare calculateNatureShare(List<Transaction> transactions) {
    int essential = 0;
    int side = 0;

    for (final tx in transactions) {
      if (tx.kind != 'expense') continue;
      if (tx.nature == 'essential') {
        essential += tx.amountMinor;
      } else {
        side += tx.amountMinor;
      }
    }

    final total = essential + side;
    final essentialPct = total > 0 ? (essential / total) * 100 : 0.0;
    final sidePct = total > 0 ? (side / total) * 100 : 0.0;

    return NatureShare(
      essentialMinor: essential,
      sideMinor: side,
      essentialPercent: essentialPct,
      sidePercent: sidePct,
    );
  }

  /// Spending grouped by category, sorted descending by total amount
  List<CategorySpending> calculateCategorySpendings(
    List<Transaction> transactions,
    Map<int, FinanceCategory> categoryMap,
  ) {
    final totals = <int, int>{};
    final counts = <int, int>{};
    int overallExpense = 0;

    for (final tx in transactions) {
      if (tx.kind != 'expense') continue;
      totals[tx.categoryId] = (totals[tx.categoryId] ?? 0) + tx.amountMinor;
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
      overallExpense += tx.amountMinor;
    }

    final result = <CategorySpending>[];
    for (final entry in totals.entries) {
      final cat = categoryMap[entry.key];
      final catNameAr = cat?.nameAr ?? 'أخرى';
      final catNameEn = cat?.nameEn;
      final color = cat?.color ?? 0xFF9E9E9E;
      final icon = cat?.icon ?? 'more_horiz';
      final pct = overallExpense > 0 ? (entry.value / overallExpense) * 100 : 0.0;

      result.add(
        CategorySpending(
          categoryId: entry.key,
          nameAr: catNameAr,
          nameEn: catNameEn,
          color: color,
          icon: icon,
          amountMinor: entry.value,
          percent: pct,
          count: counts[entry.key] ?? 0,
        ),
      );
    }

    result.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return result;
  }

  /// Top 5 categories
  List<CategorySpending> getTopCategories(
    List<Transaction> transactions,
    Map<int, FinanceCategory> categoryMap, {
    int limit = 5,
  }) {
    final all = calculateCategorySpendings(transactions, categoryMap);
    return all.take(limit).toList();
  }

  /// Daily average spending
  int calculateDailyAverage(List<Transaction> transactions, int daysCount) {
    if (daysCount <= 0) return 0;
    int totalExpense = 0;
    for (final tx in transactions) {
      if (tx.kind == 'expense') {
        totalExpense += tx.amountMinor;
      }
    }
    return (totalExpense / daysCount).round();
  }

  /// Comparison with previous period
  PeriodComparison calculatePeriodComparison(
    List<Transaction> currentTxs,
    List<Transaction> previousTxs,
  ) {
    int current = 0;
    for (final tx in currentTxs) {
      if (tx.kind == 'expense') current += tx.amountMinor;
    }

    int previous = 0;
    for (final tx in previousTxs) {
      if (tx.kind == 'expense') previous += tx.amountMinor;
    }

    final diff = current - previous;
    final pct = previous > 0 ? ((current - previous) / previous) * 100 : 0.0;

    return PeriodComparison(
      currentExpenseMinor: current,
      previousExpenseMinor: previous,
      diffMinor: diff,
      percentChange: pct,
    );
  }

  /// Spending by weekday (1: Mon, 2: Tue, ..., 7: Sun)
  Map<int, int> calculateWeekdaySpending(List<Transaction> transactions) {
    final map = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final tx in transactions) {
      if (tx.kind != 'expense') continue;
      try {
        final d = DateTime.parse(tx.localDate);
        map[d.weekday] = (map[d.weekday] ?? 0) + tx.amountMinor;
      } catch (_) {}
    }
    return map;
  }

  /// Top 5 single biggest expenses
  List<Transaction> getTopSingleExpenses(
    List<Transaction> transactions, {
    int limit = 5,
  }) {
    final expenses = transactions.where((t) => t.kind == 'expense').toList();
    expenses.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return expenses.take(limit).toList();
  }

  /// Small recurring spending (categories with >= minCount entries and avg <= maxAvgMinor)
  List<SmallRecurringItem> findSmallRecurringSpending(
    List<Transaction> transactions,
    Map<int, FinanceCategory> categoryMap, {
    int minCount = 10,
    int maxAvgMinor = 6000, // 60 EGP
  }) {
    final catTotals = <int, int>{};
    final catCounts = <int, int>{};

    for (final tx in transactions) {
      if (tx.kind != 'expense') continue;
      catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amountMinor;
      catCounts[tx.categoryId] = (catCounts[tx.categoryId] ?? 0) + 1;
    }

    final results = <SmallRecurringItem>[];
    for (final entry in catCounts.entries) {
      if (entry.value >= minCount) {
        final total = catTotals[entry.key] ?? 0;
        final avg = (total / entry.value).round();
        if (avg <= maxAvgMinor) {
          final cat = categoryMap[entry.key];
          results.add(
            SmallRecurringItem(
              categoryId: entry.key,
              categoryNameAr: cat?.nameAr ?? 'أخرى',
              totalAmountMinor: total,
              averageAmountMinor: avg,
              count: entry.value,
            ),
          );
        }
      }
    }

    results.sort((a, b) => b.totalAmountMinor.compareTo(a.totalAmountMinor));
    return results;
  }

  /// Calculate obligations metrics: late count, due soon, on-time rate
  ObligationsMetrics calculateObligationsMetrics(
    List<ObligationInstance> instances,
    String todayDate,
  ) {
    int lateCount = 0;
    int lateAmount = 0;
    int dueSoonCount = 0;
    int dueSoonAmount = 0;
    int totalDueOrPaid = 0;
    int onTimeCount = 0;

    DateTime? today;
    try {
      today = DateTime.parse(todayDate);
    } catch (_) {}

    final soonLimit = today != null ? today.add(const Duration(days: 7)) : null;

    for (final inst in instances) {
      final isPending = inst.status == 'pending';
      final isLate = isPending && inst.dueDate.compareTo(todayDate) < 0;

      if (isLate) {
        lateCount++;
        lateAmount += inst.amountMinor;
      } else if (isPending && today != null && soonLimit != null) {
        try {
          final due = DateTime.parse(inst.dueDate);
          if (due.isAfter(today.subtract(const Duration(seconds: 1))) && due.isBefore(soonLimit.add(const Duration(days: 1)))) {
            dueSoonCount++;
            dueSoonAmount += inst.amountMinor;
          }
        } catch (_) {}
      }

      // On-time payment calculation:
      // An instance counts if it is paid or if its due date has arrived/passed.
      if (inst.status == 'paid') {
        totalDueOrPaid++;
        // Paid on or before due date
        if (inst.paidAt != null) {
          final paidDate = DateTime.fromMillisecondsSinceEpoch(inst.paidAt!);
          final paidDateStr = "${paidDate.year}-${paidDate.month.toString().padLeft(2, '0')}-${paidDate.day.toString().padLeft(2, '0')}";
          if (paidDateStr.compareTo(inst.dueDate) <= 0) {
            onTimeCount++;
          }
        } else {
          onTimeCount++;
        }
      } else if (isLate) {
        totalDueOrPaid++;
      }
    }

    final onTimeRate = totalDueOrPaid > 0 ? (onTimeCount / totalDueOrPaid) * 100 : 100.0;

    return ObligationsMetrics(
      lateCount: lateCount,
      lateAmountMinor: lateAmount,
      dueSoonCount: dueSoonCount,
      dueSoonAmountMinor: dueSoonAmount,
      onTimeRate: onTimeRate,
    );
  }

  /// Wishlist estimate: total of wanted & planned items and estimate of months to save for them
  ({int totalWantedPlannedMinor, double? estimatedMonths}) calculateWishlistEstimate(
    List<WishlistItem> items,
    int avgMonthlySavingsMinor,
  ) {
    int total = 0;
    for (final item in items) {
      if (item.status == 'wanted' || item.status == 'planned') {
        total += item.estimatedPriceMinor;
      }
    }

    double? months;
    if (avgMonthlySavingsMinor > 0 && total > 0) {
      months = total / avgMonthlySavingsMinor;
    }

    return (totalWantedPlannedMinor: total, estimatedMonths: months);
  }

  /// Generate obligation instances for the next N months
  List<({String dueDate, int amountMinor})> generateInstancesDates({
    required String frequency,
    required String startDate,
    String? endDate,
    int? dueDay,
    String? dueDate,
    required int amountMinor,
    int? installmentsTotal,
    required DateTime fromDate,
    int monthsAhead = 3,
  }) {
    final results = <({String dueDate, int amountMinor})>[];
    final start = DateTime.tryParse(startDate) ?? fromDate;
    final end = endDate != null ? DateTime.tryParse(endDate) : null;
    final targetMaxDate = DateTime(fromDate.year, fromDate.month + monthsAhead, fromDate.day);

    if (frequency == 'once') {
      final date = dueDate ?? startDate;
      results.add((dueDate: date, amountMinor: amountMinor));
      return results;
    }

    if (frequency == 'monthly') {
      final targetDay = dueDay ?? start.day;
      int generated = 0;
      var curMonth = DateTime(fromDate.year, fromDate.month, 1);

      while (curMonth.isBefore(targetMaxDate)) {
        if (installmentsTotal != null && generated >= installmentsTotal) break;

        final daysInMonth = DateTime(curMonth.year, curMonth.month + 1, 0).day;
        final day = targetDay.clamp(1, daysInMonth);
        final instDate = DateTime(curMonth.year, curMonth.month, day);

        if (!instDate.isBefore(DateTime(start.year, start.month, start.day))) {
          if (end == null || !instDate.isAfter(end)) {
            final dateStr = "${instDate.year}-${instDate.month.toString().padLeft(2, '0')}-${instDate.day.toString().padLeft(2, '0')}";
            results.add((dueDate: dateStr, amountMinor: amountMinor));
            generated++;
          }
        }
        curMonth = DateTime(curMonth.year, curMonth.month + 1, 1);
      }
    } else if (frequency == 'weekly') {
      var cur = start;
      int generated = 0;
      while (cur.isBefore(targetMaxDate)) {
        if (installmentsTotal != null && generated >= installmentsTotal) break;
        if (!cur.isBefore(DateTime(fromDate.year, fromDate.month, fromDate.day))) {
          if (end == null || !cur.isAfter(end)) {
            final dateStr = "${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}";
            results.add((dueDate: dateStr, amountMinor: amountMinor));
            generated++;
          }
        }
        cur = cur.add(const Duration(days: 7));
      }
    } else if (frequency == 'yearly') {
      var year = fromDate.year;
      final targetDay = dueDay ?? start.day;
      for (int i = 0; i < 2; i++) {
        final daysInMonth = DateTime(year + i, start.month + 1, 0).day;
        final day = targetDay.clamp(1, daysInMonth);
        final instDate = DateTime(year + i, start.month, day);
        if (!instDate.isBefore(DateTime(start.year, start.month, start.day))) {
          if (end == null || !instDate.isAfter(end)) {
            final dateStr = "${instDate.year}-${instDate.month.toString().padLeft(2, '0')}-${instDate.day.toString().padLeft(2, '0')}";
            results.add((dueDate: dateStr, amountMinor: amountMinor));
          }
        }
      }
    }

    return results;
  }
}
