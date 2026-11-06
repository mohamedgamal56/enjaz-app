import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/finance_service.dart';
import 'finance_icon_helper.dart';

class FinanceStatsSection extends ConsumerWidget {
  final DateTime referenceDate;

  const FinanceStatsSection({super.key, required this.referenceDate});

  static const _service = FinanceService();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final isMasked = ref.watch(financeMaskedProvider);
    final db = ref.watch(databaseProvider);

    final startOfMonth = DateTime(referenceDate.year, referenceDate.month, 1);
    final daysInMonth = DateTime(referenceDate.year, referenceDate.month + 1, 0).day;
    final endOfMonth = DateTime(referenceDate.year, referenceDate.month, daysInMonth);

    final startDateStr = "${startOfMonth.year}-${startOfMonth.month.toString().padLeft(2, '0')}-01";
    final endDateStr = "${endOfMonth.year}-${endOfMonth.month.toString().padLeft(2, '0')}-${daysInMonth.toString().padLeft(2, '0')}";

    return FutureBuilder(
      future: Future.wait([
        db.getTransactionsForRange(startDateStr, endDateStr),
        db.getAllFinanceCategories(),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
        }

        final txs = snapshot.data![0] as List<Transaction>;
        final categories = snapshot.data![1] as List<FinanceCategory>;
        final catMap = {for (final c in categories) c.id: c};

        final totals = _service.calculateTotals(txs);
        final natureShare = _service.calculateNatureShare(txs);
        final topCats = _service.getTopCategories(txs, catMap, limit: 5);

        // Group daily expenses for line chart
        final dailyExpenses = <int, int>{}; // day (1..31) -> minor
        for (int d = 1; d <= daysInMonth; d++) {
          dailyExpenses[d] = 0;
        }
        for (final tx in txs) {
          if (tx.kind == 'expense') {
            final day = int.tryParse(tx.localDate.split('-').last) ?? 1;
            dailyExpenses[day] = (dailyExpenses[day] ?? 0) + tx.amountMinor;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Essential vs Side Donut Chart
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'توزيع المصروفات (ضروري / كمالي)' : 'Essential vs Side Spending',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 3,
                                centerSpaceRadius: 36,
                                sections: [
                                  PieChartSectionData(
                                    color: Colors.blue,
                                    value: natureShare.essentialPercent > 0 ? natureShare.essentialPercent : 0.1,
                                    title: '${natureShare.essentialPercent.toStringAsFixed(0)}%',
                                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    radius: 35,
                                  ),
                                  PieChartSectionData(
                                    color: Colors.orange,
                                    value: natureShare.sidePercent > 0 ? natureShare.sidePercent : 0.1,
                                    title: '${natureShare.sidePercent.toStringAsFixed(0)}%',
                                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    radius: 35,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legendRow(
                                color: Colors.blue,
                                label: isArabic ? 'ضروري' : 'Essential',
                                amountMinor: natureShare.essentialMinor,
                                isMasked: isMasked,
                                numeralsFormat: numeralsFormat,
                                isArabic: isArabic,
                              ),
                              const SizedBox(height: 8),
                              _legendRow(
                                color: Colors.orange,
                                label: isArabic ? 'كمالي' : 'Side',
                                amountMinor: natureShare.sideMinor,
                                isMasked: isMasked,
                                numeralsFormat: numeralsFormat,
                                isArabic: isArabic,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Spending by Top Categories
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'الإنفاق حسب التصنيف' : 'Spending by Category',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    if (topCats.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(isArabic ? 'لا توجد بيانات إنفاق لهذا الشهر' : 'No spending data'),
                        ),
                      )
                    else
                      ...topCats.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(FinanceIconHelper.getIcon(cat.icon), size: 16, color: Color(cat.color)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isArabic ? cat.nameAr : (cat.nameEn ?? cat.nameAr),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${cat.percent.toStringAsFixed(1)}% • ${MoneyFormatter.formatWithCurrency(cat.amountMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: (cat.percent / 100).clamp(0.0, 1.0),
                                backgroundColor: Color(cat.color).withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation(Color(cat.color)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Daily Spending Line Chart
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مسار الإنفاق اليومي على مدار الشهر' : 'Daily Spending Over Time',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 5,
                                getTitlesWidget: (val, meta) {
                                  if (val % 5 == 0 && val > 0 && val <= daysInMonth) {
                                    return Text('${val.toInt()}', style: const TextStyle(fontSize: 10));
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: dailyExpenses.entries
                                  .map((e) => FlSpot(e.key.toDouble(), (e.value / 100).toDouble()))
                                  .toList(),
                              isCurved: true,
                              color: Colors.red,
                              barWidth: 2.5,
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.red.withValues(alpha: 0.15),
                              ),
                              dotData: const FlDotData(show: false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Income vs Expenses Comparison Bar
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'مقارنة الدخل بالمصروفات' : 'Income vs Expenses',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isArabic ? 'الدخل' : 'Income', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                MoneyFormatter.formatWithCurrency(totals.incomeMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isArabic ? 'المصروفات' : 'Expenses', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                MoneyFormatter.formatWithCurrency(totals.expenseMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isArabic ? 'نسبة الادخار' : 'Savings Rate', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                totals.savingsRate != null ? '${(totals.savingsRate! * 100).toStringAsFixed(1)}%' : 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required int amountMinor,
    required bool isMasked,
    required NumeralsFormat numeralsFormat,
    required bool isArabic,
  }) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text(
              MoneyFormatter.formatWithCurrency(amountMinor, currency: isArabic ? 'ج.م' : 'EGP', masked: isMasked, format: numeralsFormat, showDecimals: false),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
