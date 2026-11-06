import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../timeline/domain/timeline_models.dart';
import '../../timeline/domain/timeline_provider.dart';
import '../domain/stats_service.dart';

class OverviewStatsSection extends ConsumerWidget {
  final StatsDateRange range;
  final DateTime referenceDate;

  const OverviewStatsSection({
    super.key,
    required this.range,
    required this.referenceDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);
    final aggregator = ref.watch(timelineAggregatorProvider);

    return FutureBuilder<TimelineOverviewSummary>(
      future: aggregator.getOverviewSummary(range.start, range.end),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(color: colors.accent)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${snapshot.error}',
              style: TextStyle(color: colors.stopped),
            ),
          );
        }

        final summary = snapshot.data ?? const TimelineOverviewSummary();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                // 1. Tasks Done
                _buildOverviewCard(
                  context,
                  icon: Icons.task_alt_rounded,
                  iconColor: Colors.blue,
                  title: isAr ? 'المهام المنجزة' : 'Tasks Done',
                  value: AppFormatter.formatStringDigits('${summary.tasksDoneCount}', format: numerals),
                  subtitle: isAr ? 'مهمة منجزة في الفترة' : 'tasks in period',
                ),

                // 2. Habits Completion Rate
                _buildOverviewCard(
                  context,
                  icon: Icons.repeat_rounded,
                  iconColor: Colors.teal,
                  title: isAr ? 'الالتزام بالعادات' : 'Habit Completion',
                  value: AppFormatter.formatStringDigits(
                    '${summary.habitsCompletionRate.toStringAsFixed(0)}%',
                    format: numerals,
                  ),
                  subtitle: AppFormatter.formatStringDigits(
                    isAr ? '${summary.habitsLoggedCount} مرات تسجيل' : '${summary.habitsLoggedCount} logs',
                    format: numerals,
                  ),
                ),

                // 3. Top Spending Category / Total Expenses
                _buildOverviewCard(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: Colors.green,
                  title: isAr ? 'المصروفات' : 'Spending',
                  value: AppFormatter.formatStringDigits(
                    MoneyFormatter.formatMinorWithCurrency(summary.totalExpensesMinor),
                    format: numerals,
                  ),
                  subtitle: summary.topSpendingCategory != null
                      ? (isAr ? 'الأعلى: ${summary.topSpendingCategory}' : 'Top: ${summary.topSpendingCategory}')
                      : (isAr ? 'لا توجد مصروفات' : 'No expenses'),
                ),

                // 4. Notes Written
                _buildOverviewCard(
                  context,
                  icon: Icons.note_alt_rounded,
                  iconColor: Colors.orange,
                  title: isAr ? 'الملاحظات' : 'Notes',
                  value: AppFormatter.formatStringDigits('${summary.notesCount}', format: numerals),
                  subtitle: isAr ? 'ملاحظة مدونة' : 'notes recorded',
                ),

                // 5. Goal Progress
                _buildOverviewCard(
                  context,
                  icon: Icons.flag_rounded,
                  iconColor: Colors.indigo,
                  title: isAr ? 'إنجاز الأهداف' : 'Goal Progress',
                  value: AppFormatter.formatStringDigits(
                    '${summary.goalProgressAvg.toStringAsFixed(0)}%',
                    format: numerals,
                  ),
                  subtitle: isAr ? 'متوسط تقدم الأهداف' : 'average goal progress',
                ),

                // 6. Health Items Done
                _buildOverviewCard(
                  context,
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.redAccent,
                  title: isAr ? 'الصحة والعلاج' : 'Health Checkups',
                  value: AppFormatter.formatStringDigits(
                    '${summary.healthItemsDoneCount}',
                    format: numerals,
                  ),
                  subtitle: isAr ? 'فحص وموعد منجز' : 'checkups completed',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Summary banner for total income vs expenses
            if (summary.totalIncomeMinor > 0 || summary.totalExpensesMinor > 0) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            isAr ? 'إجمالي الدخل' : 'Total Income',
                            style: TextStyle(fontSize: 12, color: colors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatter.formatStringDigits(
                              MoneyFormatter.formatMinorWithCurrency(summary.totalIncomeMinor),
                              format: numerals,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      Container(height: 30, width: 1, color: colors.border),
                      Column(
                        children: [
                          Text(
                            isAr ? 'صافي الادخار' : 'Net Savings',
                            style: TextStyle(fontSize: 12, color: colors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppFormatter.formatStringDigits(
                              MoneyFormatter.formatMinorWithCurrency(
                                summary.totalIncomeMinor - summary.totalExpensesMinor,
                              ),
                              format: numerals,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (summary.totalIncomeMinor - summary.totalExpensesMinor) >= 0
                                  ? Colors.green
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
