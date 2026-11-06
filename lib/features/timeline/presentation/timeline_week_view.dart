import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../domain/timeline_models.dart';
import '../domain/timeline_provider.dart';

class TimelineWeekView extends ConsumerWidget {
  final DateTime referenceDate;
  final ValueChanged<DateTime> onSelectDay;

  const TimelineWeekView({
    super.key,
    required this.referenceDate,
    required this.onSelectDay,
  });

  /// Computes the Saturday that starts the week containing referenceDate
  DateTime _getWeekStart(DateTime ref) {
    final satOffset = (ref.weekday % 7 + 1) % 7;
    return DateTime(ref.year, ref.month, ref.day).subtract(Duration(days: satOffset));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);
    final aggregator = ref.watch(timelineAggregatorProvider);

    final weekStart = _getWeekStart(referenceDate);
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    return FutureBuilder<TimelineOverviewSummary>(
      future: aggregator.getOverviewSummary(weekStart, weekEnd),
      builder: (context, snapshot) {
        final summary = snapshot.data;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. Week Summary Card
            if (summary != null) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'ملخص إنجاز الأسبوع' : 'Weekly Progress Summary',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetric(
                            context,
                            icon: Icons.task_alt_rounded,
                            color: Colors.blue,
                            title: isAr ? 'المهام' : 'Tasks',
                            value: AppFormatter.formatStringDigits('${summary.tasksDoneCount}', format: numerals),
                          ),
                          _buildMetric(
                            context,
                            icon: Icons.repeat_rounded,
                            color: Colors.teal,
                            title: isAr ? 'العادات' : 'Habits',
                            value: AppFormatter.formatStringDigits(
                              '${summary.habitsCompletionRate.toStringAsFixed(0)}%',
                              format: numerals,
                            ),
                          ),
                          _buildMetric(
                            context,
                            icon: Icons.note_alt_rounded,
                            color: Colors.orange,
                            title: isAr ? 'الملاحظات' : 'Notes',
                            value: AppFormatter.formatStringDigits('${summary.notesCount}', format: numerals),
                          ),
                          _buildMetric(
                            context,
                            icon: Icons.favorite_rounded,
                            color: Colors.redAccent,
                            title: isAr ? 'الصحة' : 'Health',
                            value: AppFormatter.formatStringDigits('${summary.healthItemsDoneCount}', format: numerals),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 2. The 7 Week Day Cards
            ...weekDays.map((day) {
              final dayStr = DateFormat('yyyy-MM-dd').format(day);
              final isToday = dayStr == todayStr;
              final dayName = isAr
                  ? DateFormat('EEEE', 'ar').format(day)
                  : DateFormat('EEEE', 'en').format(day);
              final dateLabel = AppFormatter.formatStringDigits(
                DateFormat('d MMM', isAr ? 'ar' : 'en').format(day),
                format: numerals,
              );

              return Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isToday ? theme.colorScheme.primary : colors.border.withValues(alpha: 0.5),
                    width: isToday ? 2 : 1,
                  ),
                ),
                child: FutureBuilder<(List<TimelineEntry>, TimelineDaySummary)>(
                  future: aggregator.getTimelineForDay(day),
                  builder: (ctx, snap) {
                    final daySummary = snap.data?.$2;
                    final totalEntries = snap.data?.$1.length ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      onTap: () => onSelectDay(day),
                      leading: CircleAvatar(
                        backgroundColor: isToday
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          AppFormatter.formatStringDigits('${day.day}', format: numerals),
                          style: TextStyle(
                            color: isToday ? Colors.white : colors.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            dayName,
                            style: TextStyle(
                              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                              color: isToday ? theme.colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          if (isToday) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAr ? 'اليوم' : 'Today',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: daySummary != null && !daySummary.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  if (daySummary.tasksDoneCount > 0)
                                    _buildDotCount(Colors.blue, daySummary.tasksDoneCount, numerals),
                                  if (daySummary.habitsDoneCount > 0)
                                    _buildDotCount(Colors.teal, daySummary.habitsDoneCount, numerals),
                                  if (daySummary.expensesMinor > 0)
                                    _buildDotCount(Colors.redAccent, 1, numerals, isMoney: true),
                                  if (daySummary.notesCount > 0)
                                    _buildDotCount(Colors.orange, daySummary.notesCount, numerals),
                                  if (daySummary.ideasCount > 0)
                                    _buildDotCount(Colors.purple, daySummary.ideasCount, numerals),
                                ],
                              ),
                            )
                          : Text(
                              totalEntries > 0
                                  ? (isAr ? '$totalEntries أحداث' : '$totalEntries events')
                                  : (isAr ? 'لا توجد أنشطة' : 'No activities'),
                              style: TextStyle(fontSize: 11, color: colors.textMuted),
                            ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: AppColors.of(context).textMuted),
        ),
      ],
    );
  }

  Widget _buildDotCount(Color color, int count, NumeralsFormat numerals, {bool isMoney = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 2),
          if (!isMoney)
            Text(
              AppFormatter.formatStringDigits('$count', format: numerals),
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
