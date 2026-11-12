import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/card_header.dart';
import '../../../../core/widgets/mini_ring.dart';
import '../../../habits/presentation/add_habit_sheet.dart';
import '../../../habits/presentation/habits_screen.dart';
import '../../domain/home_summary_data.dart';

/// HomeHabitsCard (UI.md Section 4.2 & Section 9)
/// Displays daily habit completion ring and streak count.
class HomeHabitsCard extends ConsumerWidget {
  final HomeSummaryData data;

  const HomeHabitsCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final numerals = ref.watch(numeralsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    void openHabitsScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HabitsScreen()),
      );
    }

    final double progress = data.habitsTotalScheduledCount > 0
        ? (data.habitsCompletedCount / data.habitsTotalScheduledCount)
        : 0.0;

    final completedStr = AppFormatter.formatNumber(data.habitsCompletedCount, format: numerals);
    final totalStr = AppFormatter.formatNumber(data.habitsTotalScheduledCount, format: numerals);
    final streakStr = AppFormatter.formatNumber(data.habitsStreak, format: numerals);

    return AppCard(
      onTap: openHabitsScreen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CardHeader(
            title: isArabic ? 'العادات' : 'Habits',
            leading: Icon(Icons.repeat_rounded, size: 18.0, color: colors.accent),
          ),

          if (!data.hasHabits) ...[
            Text(
              isArabic ? 'لم تضف عادات بعد' : 'No habits created yet',
              style: AppTypography.caption(context, color: colors.textSecondary),
            ),
            const SizedBox(height: 8.0),
            InkWell(
              onTap: () => AddHabitSheet.show(context),
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 16.0, color: colors.accent),
                    const SizedBox(width: 4.0),
                    Text(
                      isArabic ? 'إضافة عادة' : 'Add habit',
                      style: AppTypography.caption(context, color: colors.accent).copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                MiniRing(
                  progress: progress,
                  size: 42.0,
                  strokeWidth: 3.5,
                  progressColor: colors.accent,
                  child: Text(
                    completedStr,
                    style: AppTypography.caption(context, color: colors.text).copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArabic ? '$completedStr من $totalStr اليوم' : '$completedStr of $totalStr today',
                        style: AppTypography.caption(context, color: colors.text).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (data.habitsStreak > 0) ...[
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department_rounded, size: 14.0, color: colors.warningText),
                            const SizedBox(width: 2.0),
                            Expanded(
                              child: Text(
                                isArabic ? 'سلسلة $streakStr أيام' : '$streakStr-day streak',
                                style: AppTypography.caption(context, color: colors.textSecondary).copyWith(
                                  fontSize: 11.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
