import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../domain/timeline_models.dart';
import '../domain/timeline_provider.dart';

class TimelineYearView extends ConsumerWidget {
  final int year;
  final ValueChanged<int> onSelectMonth;

  const TimelineYearView({
    super.key,
    required this.year,
    required this.onSelectMonth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);
    final aggregator = ref.watch(timelineAggregatorProvider);

    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59, 999);

    final monthNames = isAr
        ? [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];

    return FutureBuilder<(Map<int, int>, TimelineOverviewSummary)>(
      future: () async {
        final density = await aggregator.getYearActivityDensity(year);
        final summary = await aggregator.getOverviewSummary(startOfYear, endOfYear);
        return (density, summary);
      }(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.accent),
          );
        }

        final density = snapshot.data?.$1 ?? <int, int>{};
        final summary = snapshot.data?.$2;

        // Find max count to scale opacity
        int maxCount = 1;
        for (final c in density.values) {
          if (c > maxCount) maxCount = c;
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. 12 Month Tiles Grid
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'كثافة النشاط خلال العام' : 'Activity Density Heatmap',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.3,
                      ),
                      itemBuilder: (ctx, idx) {
                        final monthNum = idx + 1;
                        final count = density[monthNum] ?? 0;
                        final ratio = count / maxCount.toDouble();

                        // Shading tint
                        final primaryColor = theme.colorScheme.primary;
                        final tileColor = count > 0
                            ? primaryColor.withValues(alpha: 0.12 + (ratio * 0.75))
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

                        final textColor = count > 0 && ratio > 0.5
                            ? Colors.white
                            : (count > 0 ? primaryColor : colors.textMuted);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSelectMonth(monthNum),
                          child: Container(
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: count > 0 ? 0.3 : 0.1),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  monthNames[idx],
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  count > 0
                                      ? AppFormatter.formatStringDigits(
                                          isAr ? '$count نشاط' : '$count items',
                                          format: numerals,
                                        )
                                      : (isAr ? 'لا يوجد' : 'None'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
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

            // 2. Year Summary Card
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
                        isAr ? 'ملخص إنجاز العام' : 'Year Progress Summary',
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
