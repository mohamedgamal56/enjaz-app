import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/card_header.dart';
import '../../../../core/widgets/progress_bar.dart';
import '../../../today/presentation/today_screen.dart';
import '../../domain/home_summary_data.dart';

/// HomeTodayCard (UI.md Section 4.2 & Section 9)
/// Full-width card displaying today's task progress and the next task.
class HomeTodayCard extends ConsumerWidget {
  final HomeSummaryData data;

  const HomeTodayCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final completedStr = AppFormatter.formatNumber(data.todayCompletedCount, format: numerals);
    final totalStr = AppFormatter.formatNumber(data.todayTotalCount, format: numerals);

    final progressText = isArabic
        ? '$completedStr من $totalStr تمت'
        : '$completedStr of $totalStr completed';

    void openTodayScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TodayScreen()),
      );
    }

    return AppCard(
      onTap: openTodayScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: isArabic ? 'النهاردة' : 'Today',
            leading: Icon(Icons.today_rounded, size: 20.0, color: colors.accent),
            actionLabel: isArabic ? 'عرض المهام' : 'View tasks',
            onAction: openTodayScreen,
          ),

          // Progress stat & bar
          if (data.todayTotalCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  progressText,
                  style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${AppFormatter.formatNumber((data.todayProgress * 100).toInt(), format: numerals)}%',
                  style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            ProgressBar(progress: data.todayProgress),
            const SizedBox(height: 12.0),
          ],

          // Next Task / Done status / Empty state
          if (data.isAllTodayDone && data.todayTotalCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: colors.done.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 18.0, color: colors.done),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      isArabic ? 'أنجزت كل مهام اليوم! 🎉' : 'All today tasks completed! 🎉',
                      style: AppTypography.caption(context, color: colors.done).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (data.todayTotalCount == 0) ...[
            Text(
              isArabic ? 'لا توجد مهام مجدولة لليوم' : 'No tasks scheduled for today',
              style: AppTypography.caption(context, color: colors.textSecondary),
            ),
          ] else if (data.nextTaskTitle != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 16.0,
                  color: colors.accent,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    data.nextTaskTitle!,
                    style: AppTypography.body(context, color: colors.text).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (data.nextTaskTime != null) ...[
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 12.0, color: colors.textSecondary),
                        const SizedBox(width: 4.0),
                        Text(
                          AppFormatter.formatStringDigits(data.nextTaskTime!, format: numerals),
                          style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
