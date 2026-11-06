import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/timeline_models.dart';
import '../domain/timeline_provider.dart';

class TimelineMonthView extends ConsumerWidget {
  final DateTime referenceDate;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<DateTime> onMonthChanged;

  const TimelineMonthView({
    super.key,
    required this.referenceDate,
    required this.onSelectDay,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);
    final aggregator = ref.watch(timelineAggregatorProvider);

    final year = referenceDate.year;
    final month = referenceDate.month;

    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final lastDay = DateTime(year, month, daysInMonth, 23, 59, 59, 999);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Weekday headers starting Saturday
    final weekDayNames = isAr
        ? ['سبت', 'أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة']
        : ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    // Saturday offset for first day of month (Sat=6 => offset 0)
    final firstWeekday = firstDay.weekday;
    final leadEmptyDays = (firstWeekday % 7 + 1) % 7;

    return FutureBuilder<(Map<String, Set<TimelineModule>>, TimelineOverviewSummary)>(
      future: () async {
        final dots = await aggregator.getModuleDotsForMonth(year, month);
        final summary = await aggregator.getOverviewSummary(firstDay, lastDay);
        return (dots, summary);
      }(),
      builder: (context, snapshot) {
        final dotsMap = snapshot.data?.$1 ?? <String, Set<TimelineModule>>{};
        final summary = snapshot.data?.$2;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. Month Grid Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Weekday headers row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: weekDayNames.map((d) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 16),

                    // Calendar days grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leadEmptyDays + daysInMonth,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (ctx, index) {
                        if (index < leadEmptyDays) {
                          return const SizedBox.shrink();
                        }

                        final dayNum = index - leadEmptyDays + 1;
                        final currentDayDate = DateTime(year, month, dayNum);
                        final dateStr = DateFormat('yyyy-MM-dd').format(currentDayDate);
                        final isToday = dateStr == todayStr;
                        final isSelected = currentDayDate.year == referenceDate.year &&
                            currentDayDate.month == referenceDate.month &&
                            currentDayDate.day == referenceDate.day;

                        final modules = dotsMap[dateStr] ?? <TimelineModule>{};

                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onSelectDay(currentDayDate),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                                  : (isToday ? theme.colorScheme.surfaceContainerHighest : null),
                              borderRadius: BorderRadius.circular(8),
                              border: isToday
                                  ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppFormatter.formatStringDigits('$dayNum', format: numerals),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? theme.colorScheme.primary : colors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Module colored dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: modules.take(4).map((m) {
                                    return Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: m.color,
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Month Overview Summary Card
            if (summary != null) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'ملخص الشهر' : 'Month Summary',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildSummaryRow(
                            icon: Icons.task_alt_rounded,
                            color: Colors.blue,
                            label: isAr
                                ? 'المهام المنجزة: ${summary.tasksDoneCount}'
                                : 'Tasks completed: ${summary.tasksDoneCount}',
                            numerals: numerals,
                          ),
                          _buildSummaryRow(
                            icon: Icons.repeat_rounded,
                            color: Colors.teal,
                            label: isAr
                                ? 'الالتزام بالعادات: ${summary.habitsCompletionRate.toStringAsFixed(0)}%'
                                : 'Habits rate: ${summary.habitsCompletionRate.toStringAsFixed(0)}%',
                            numerals: numerals,
                          ),
                          if (summary.totalExpensesMinor > 0)
                            _buildSummaryRow(
                              icon: Icons.account_balance_wallet_rounded,
                              color: Colors.redAccent,
                              label: isAr
                                  ? 'إجمالي المصروفات: ${MoneyFormatter.formatMinorWithCurrency(summary.totalExpensesMinor)}'
                                  : 'Expenses: ${MoneyFormatter.formatMinorWithCurrency(summary.totalExpensesMinor)}',
                              numerals: numerals,
                            ),
                          if (summary.topSpendingCategory != null)
                            _buildSummaryRow(
                              icon: Icons.pie_chart_rounded,
                              color: Colors.purple,
                              label: isAr
                                  ? 'أعلى إنفاق: ${summary.topSpendingCategory}'
                                  : 'Top spending: ${summary.topSpendingCategory}',
                              numerals: numerals,
                            ),
                          _buildSummaryRow(
                            icon: Icons.note_alt_rounded,
                            color: Colors.orange,
                            label: isAr
                                ? 'الملاحظات: ${summary.notesCount}'
                                : 'Notes: ${summary.notesCount}',
                            numerals: numerals,
                          ),
                          _buildSummaryRow(
                            icon: Icons.favorite_rounded,
                            color: Colors.redAccent,
                            label: isAr
                                ? 'الفحوصات الطبية: ${summary.healthItemsDoneCount}'
                                : 'Health checkups: ${summary.healthItemsDoneCount}',
                            numerals: numerals,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color color,
    required String label,
    required NumeralsFormat numerals,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          AppFormatter.formatStringDigits(label, format: numerals),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }
}
