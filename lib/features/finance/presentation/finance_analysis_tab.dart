import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/finance_service.dart';
import 'finance_icon_helper.dart';

class FinanceAnalysisTab extends ConsumerWidget {
  final String currentYearMonth; // "YYYY-MM"

  const FinanceAnalysisTab({super.key, required this.currentYearMonth});

  static const _service = FinanceService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final db = ref.watch(databaseProvider);

    // Calculate start and end date for current and previous month
    final parts = currentYearMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    final curStart = "$currentYearMonth-01";
    final daysInCurMonth = DateTime(year, month + 1, 0).day;
    final curEnd = "$currentYearMonth-${daysInCurMonth.toString().padLeft(2, '0')}";

    final prevDate = DateTime(year, month - 1, 1);
    final prevYearMonth = "${prevDate.year}-${prevDate.month.toString().padLeft(2, '0')}";
    final daysInPrevMonth = DateTime(prevDate.year, prevDate.month + 1, 0).day;
    final prevStart = "$prevYearMonth-01";
    final prevEnd = "$prevYearMonth-${daysInPrevMonth.toString().padLeft(2, '0')}";

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return FutureBuilder(
      future: Future.wait([
        db.getTransactionsForRange(curStart, curEnd),
        db.getTransactionsForRange(prevStart, prevEnd),
        db.getAllFinanceCategories(),
        db.getObligationInstancesForRange(curStart, curEnd),
        db.getAllWishlistItems(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final curTxs = snapshot.data![0] as List<Transaction>;
        final prevTxs = snapshot.data![1] as List<Transaction>;
        final categories = snapshot.data![2] as List<FinanceCategory>;
        final instances = snapshot.data![3] as List<ObligationInstance>;
        final wishlist = snapshot.data![4] as List<WishlistItem>;

        final catMap = {for (final c in categories) c.id: c};

        final totals = _service.calculateTotals(curTxs);
        final natureShare = _service.calculateNatureShare(curTxs);
        final topCats = _service.getTopCategories(curTxs, catMap, limit: 5);
        final dailyAvg = _service.calculateDailyAverage(curTxs, daysInCurMonth);
        final comparison = _service.calculatePeriodComparison(curTxs, prevTxs);
        final weekdayMap = _service.calculateWeekdaySpending(curTxs);
        final topExpenses = _service.getTopSingleExpenses(curTxs, limit: 5);
        final smallRecurring = _service.findSmallRecurringSpending(curTxs, catMap, minCount: 10, maxAvgMinor: 6000);
        final obMetrics = _service.calculateObligationsMetrics(instances, todayStr);
        final wishlistEstimate = _service.calculateWishlistEstimate(
          wishlist,
          totals.savedMinor > 0 ? totals.savedMinor : 0,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            // 1. Totals & Savings Rate Card
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricColumn(
                          context,
                          title: isArabic ? 'إجمالي الدخل' : 'Total Income',
                          valueMinor: totals.incomeMinor,
                          color: Colors.green,
                          isMasked: isMasked,
                          format: numeralsFormat,
                        ),
                        Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                        _metricColumn(
                          context,
                          title: isArabic ? 'إجمالي المصروفات' : 'Total Expenses',
                          valueMinor: totals.expenseMinor,
                          color: Colors.red,
                          isMasked: isMasked,
                          format: numeralsFormat,
                        ),
                        Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                        _metricColumn(
                          context,
                          title: isArabic ? 'صافي الادخار' : 'Net Saved',
                          valueMinor: totals.savedMinor,
                          color: totals.savedMinor >= 0 ? Colors.teal : Colors.orange,
                          isMasked: isMasked,
                          format: numeralsFormat,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'معدل الادخار لهذا الشهر:' : 'Monthly Savings Rate:',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          totals.savingsRate != null
                              ? '${(totals.savingsRate! * 100).toStringAsFixed(1)}%'
                              : (isArabic ? 'غير متاح' : 'N/A'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: totals.savingsRate != null && totals.savingsRate! > 0 ? Colors.teal : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Essential vs Side Spending Share
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'توزيع المصروفات (ضروري مقابل كمالي)' : 'Essential vs Side Share',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (natureShare.essentialPercent * 10).round().clamp(1, 1000),
                            child: Container(height: 14, color: Colors.blue),
                          ),
                          Expanded(
                            flex: (natureShare.sidePercent * 10).round().clamp(1, 1000),
                            child: Container(height: 14, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              '${isArabic ? 'ضروري:' : 'Essential:'} ${MoneyFormatter.formatWithCurrency(natureShare.essentialMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat)} (${natureShare.essentialPercent.toStringAsFixed(1)}%)',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              '${isArabic ? 'كمالي:' : 'Side:'} ${MoneyFormatter.formatWithCurrency(natureShare.sideMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat)} (${natureShare.sidePercent.toStringAsFixed(1)}%)',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. Top 5 Categories & Daily Average
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabic ? 'أعلى 5 تصنيفات إنفاقاً' : 'Top 5 Categories',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${isArabic ? 'متوسط يومي:' : 'Daily avg:'} ${MoneyFormatter.formatWithCurrency(dailyAvg, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat)}',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (topCats.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(isArabic ? 'لا توجد مصروفات مسجلة' : 'No expenses recorded', style: theme.textTheme.bodySmall),
                      )
                    else
                      ...topCats.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(cat.color).withValues(alpha: 0.15),
                                child: Icon(FinanceIconHelper.getIcon(cat.icon), size: 14, color: Color(cat.color)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  isArabic ? cat.nameAr : (cat.nameEn ?? cat.nameAr),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Text(
                                '${cat.percent.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                MoneyFormatter.formatWithCurrency(cat.amountMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 4. Period Comparison
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (comparison.diffMinor <= 0 ? Colors.green : Colors.red).withValues(alpha: 0.15),
                  child: Icon(
                    comparison.diffMinor <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                    color: comparison.diffMinor <= 0 ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(
                  isArabic ? 'المقارنة بالشهر السابق' : 'Comparison with Last Month',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  comparison.previousExpenseMinor > 0
                      ? (isArabic
                          ? '${comparison.diffMinor > 0 ? 'زيادة' : 'انخفاض'} بنسبة ${comparison.percentChange.abs().toStringAsFixed(1)}% عن الشهر السابق'
                          : '${comparison.percentChange.abs().toStringAsFixed(1)}% ${comparison.diffMinor > 0 ? 'increase' : 'decrease'} vs last month')
                      : (isArabic ? 'الشهر السابق لا يحتوي على مصروفات للمقارنة' : 'No expenses in previous month'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Spending by Weekday (الإنفاق حسب أيام الأسبوع)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_view_week_rounded, size: 20, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text(
                              isArabic ? 'الإنفاق حسب أيام الأسبوع' : 'Spending by Weekday',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (weekdayMap.values.any((v) => v > 0)) ...[
                          Builder(builder: (ctx) {
                            final maxEntry = weekdayMap.entries.reduce((a, b) => a.value >= b.value ? a : b);
                            final dayNames = isArabic
                                ? {6: 'السبت', 7: 'الأحد', 1: 'الإثنين', 2: 'الثلاثاء', 3: 'الأربعاء', 4: 'الخميس', 5: 'الجمعة'}
                                : {6: 'Sat', 7: 'Sun', 1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri'};
                            return Text(
                              '${isArabic ? 'الأعلى:' : 'Peak:'} ${dayNames[maxEntry.key]}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!weekdayMap.values.any((v) => v > 0))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          isArabic ? 'لا توجد مصروفات مسجلة' : 'No expenses recorded',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      Builder(builder: (ctx) {
                        final totalExpense = weekdayMap.values.fold<int>(0, (sum, val) => sum + val);
                        final maxVal = weekdayMap.values.fold<int>(0, (m, v) => v > m ? v : m);
                        final weekDays = [
                          (6, isArabic ? 'السبت' : 'Sat'),
                          (7, isArabic ? 'الأحد' : 'Sun'),
                          (1, isArabic ? 'الإثنين' : 'Mon'),
                          (2, isArabic ? 'الثلاثاء' : 'Tue'),
                          (3, isArabic ? 'الأربعاء' : 'Wed'),
                          (4, isArabic ? 'الخميس' : 'Thu'),
                          (5, isArabic ? 'الجمعة' : 'Fri'),
                        ];

                        return Column(
                          children: weekDays.map((wd) {
                            final amount = weekdayMap[wd.$1] ?? 0;
                            final ratio = maxVal > 0 ? (amount / maxVal).clamp(0.0, 1.0) : 0.0;
                            final pct = totalExpense > 0 ? ((amount / totalExpense) * 100).round() : 0;
                            final isPeak = amount > 0 && amount == maxVal;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      wd.$2,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isPeak ? FontWeight.bold : FontWeight.w500,
                                        color: isPeak ? Colors.indigo : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ratio,
                                        minHeight: 8,
                                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                        color: isPeak ? Colors.indigo : Colors.blue.shade300,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 35,
                                    child: Text(
                                      '$pct%',
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 70),
                                    child: Text(
                                      MoneyFormatter.formatWithCurrency(
                                        amount,
                                        currency: isArabic ? 'ج.م' : 'EGP',
                                        masked: isMasked,
                                        format: numeralsFormat,
                                        showDecimals: false,
                                      ),
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isPeak ? FontWeight.bold : FontWeight.w600,
                                        color: isPeak ? Colors.indigo : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 6. Top 5 Single Biggest Expenses (أكبر 5 مصروفات فردية)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, size: 20, color: Colors.deepOrange),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'أكبر 5 مصروفات فردية' : 'Top 5 Single Expenses',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topExpenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          isArabic ? 'لا توجد مصروفات مسجلة' : 'No expenses recorded',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    else
                      ...topExpenses.map((tx) {
                        final cat = catMap[tx.categoryId];
                        final catName = isArabic ? (cat?.nameAr ?? 'أخرى') : (cat?.nameEn ?? cat?.nameAr ?? 'Other');
                        final color = Color(cat?.color ?? 0xFF9E9E9E);
                        final iconData = FinanceIconHelper.getIcon(cat?.icon ?? 'more_horiz');
                        final title = (tx.note != null && tx.note!.trim().isNotEmpty) ? tx.note!.trim() : catName;
                        final isEssential = tx.nature == 'essential';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: color.withValues(alpha: 0.15),
                                child: Icon(iconData, size: 16, color: color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          tx.localDate,
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: (isEssential ? Colors.blue : Colors.orange).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isEssential ? (isArabic ? 'ضروري' : 'Essential') : (isArabic ? 'كمالي' : 'Side'),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: isEssential ? Colors.blue.shade700 : Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                MoneyFormatter.formatWithCurrency(
                                  tx.amountMinor,
                                  currency: isArabic ? 'ج.م' : 'EGP',
                                  masked: isMasked,
                                  format: numeralsFormat,
                                  showDecimals: false,
                                ),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5. Small Recurring Spending (مصروفات صغيرة متكررة)
            if (smallRecurring.isNotEmpty) ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text(
                            isArabic ? 'مصروفات صغيرة متكررة (تسريب الميزانية)' : 'Small Recurring Spending',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic
                            ? 'تصنيفات تكررت 10 مرات فأكثر بمتوسط مبالغ صغيرة في الشهر:'
                            : 'Categories repeated 10+ times with small average amounts:',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 10),
                      ...smallRecurring.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item.categoryNameAr} (${item.count} مرة)',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${isArabic ? 'إجمالي:' : 'Total:'} ${MoneyFormatter.formatWithCurrency(item.totalAmountMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 6. Obligations Metrics
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'التزام السداد للأقساط والفواتير' : 'Obligations Performance',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${obMetrics.onTimeRate.toStringAsFixed(1)}%',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: obMetrics.onTimeRate >= 80 ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(isArabic ? 'نسبة السداد بالموعد' : 'On-time Rate', style: theme.textTheme.bodySmall),
                          ],
                        ),
                        Container(width: 1, height: 36, color: theme.colorScheme.outlineVariant),
                        Column(
                          children: [
                            Text(
                              '${obMetrics.lateCount}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: obMetrics.lateCount > 0 ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(isArabic ? 'دفعات متأخرة' : 'Late Payments', style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _metricColumn(
    BuildContext context, {
    required String title,
    required int valueMinor,
    required Color color,
    required bool isMasked,
    required NumeralsFormat format,
  }) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final formatted = MoneyFormatter.formatWithCurrency(
      valueMinor,
      currency: isArabic ? 'ج.م' : 'EGP',
      masked: isMasked,
      format: format,
      showDecimals: false,
    );

    return Column(
      children: [
        Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 4),
        Text(
          formatted,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
