import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../stats/domain/stats_service.dart';
import '../domain/habits_service.dart';
import 'habit_icon_helper.dart';
import 'habit_details_screen.dart';

class HabitsStatsSection extends ConsumerWidget {
  final StatsDateRange range;

  const HabitsStatsSection({
    super.key,
    required this.range,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final colors = AppColors.of(context);

    final startStr = HabitsService.formatDate(range.start);
    final endStr = HabitsService.formatDate(range.end);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        db.getAllActiveHabits(),
        db.getAllHabitLogsForRange(startStr, endStr),
        db.getAllHabitItemLogsForRange(startStr, endStr),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: colors.accent));
        }

        final habits = snapshot.data![0] as List<Habit>;
        final allLogs = snapshot.data![1] as List<HabitLog>;
        final allItemLogs = snapshot.data![2] as List<HabitItemLog>;

        if (habits.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.repeat_rounded, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'لا توجد عادات نشطة بعد' : 'No active habits yet',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          );
        }

        // Group logs by habit
        final logsByHabit = <int, List<HabitLog>>{};
        for (final l in allLogs) {
          logsByHabit.putIfAbsent(l.habitId, () => []).add(l);
        }

        // Group item logs by habit
        final itemLogsByHabit = <int, List<HabitItemLog>>{};
        for (final il in allItemLogs) {
          itemLogsByHabit.putIfAbsent(il.habitId, () => []).add(il);
        }

        return FutureBuilder<Map<int, List<HabitItem>>>(
          future: _loadAllHabitItems(db, habits),
          builder: (context, itemsSnapshot) {
            final habitItemsMap = itemsSnapshot.data ?? {};

            // Calculate metrics per habit
            final habitStats = <int, _HabitCalculatedStat>{};
            Habit? mostConsistentHabit;
            double highestRate = -1;
            Habit? mostMissedHabit;
            int maxMissed = -1;

            for (final habit in habits) {
              final hLogs = logsByHabit[habit.id] ?? [];
              final hItemLogs = itemLogsByHabit[habit.id] ?? [];
              final hItems = habitItemsMap[habit.id] ?? [];

              final completionMap = <String, bool>{};

              // Group by date
              final dailySums = <String, double>{};
              for (final l in hLogs) {
                dailySums[l.logDate] = (dailySums[l.logDate] ?? 0.0) + l.value;
              }

              final dailyItemSets = <String, Set<int>>{};
              for (final il in hItemLogs) {
                dailyItemSets.putIfAbsent(il.logDate, () => <int>{}).add(il.itemId);
              }

              final allDates = {...dailySums.keys, ...dailyItemSets.keys};
              for (final d in allDates) {
                completionMap[d] = HabitsService.isDayCompleted(
                  type: habit.type,
                  dailyTarget: habit.dailyTarget,
                  totalLoggedValue: dailySums[d] ?? 0.0,
                  totalChecklistItems: hItems.length,
                  doneChecklistItems: dailyItemSets[d]?.length ?? 0,
                );
              }

              final (curStreak, bestStreak) = HabitsService.calculateStreaks(
                scheduleDays: habit.scheduleDays,
                completionMap: completionMap,
                today: DateTime.now(),
              );

              final rate = HabitsService.calculateCompletionRate(
                scheduleDays: habit.scheduleDays,
                completionMap: completionMap,
                start: range.start,
                end: range.end,
              );

              final missed = HabitsService.countMissedDays(
                scheduleDays: habit.scheduleDays,
                completionMap: completionMap,
                start: range.start,
                end: range.end,
              );

              habitStats[habit.id] = _HabitCalculatedStat(
                completionRate: rate,
                currentStreak: curStreak,
                bestStreak: bestStreak,
                missedDays: missed,
                completionMap: completionMap,
              );

              if (rate > highestRate) {
                highestRate = rate;
                mostConsistentHabit = habit;
              }

              if (missed > maxMissed) {
                maxMissed = missed;
                mostMissedHabit = habit;
              }
            }

            // Find count habit for daily trend line chart (e.g. coffee)
            final countHabit = habits.firstWhere(
              (h) => h.type == 'count',
              orElse: () => habits.first,
            );
            final countLogs = logsByHabit[countHabit.id] ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Insights Cards: Most Consistent & Most Missed
                Row(
                  children: [
                    if (mostConsistentHabit != null)
                      Expanded(
                        child: Card(
                          elevation: 1,
                          color: Colors.green.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.green, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic ? 'الأكثر التزاماً' : 'Most Consistent',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic ? mostConsistentHabit.nameAr : (mostConsistentHabit.nameEn ?? mostConsistentHabit.nameAr),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '${highestRate.toInt()}% ${isArabic ? 'إنجاز' : 'rate'}',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (mostMissedHabit != null && maxMissed > 0)
                      Expanded(
                        child: Card(
                          elevation: 1,
                          color: Colors.orange.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      isArabic ? 'الأكثر تفويتاً' : 'Most Missed',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isArabic ? mostMissedHabit.nameAr : (mostMissedHabit.nameEn ?? mostMissedHabit.nameAr),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  '$maxMissed ${isArabic ? 'أيام فائتة' : 'missed days'}',
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Line Chart for Count Habit (e.g. coffee per day)
                if (countHabit.type == 'count') ...[
                  _buildDailyCountChartCard(context, countHabit, countLogs, range, isArabic),
                  const SizedBox(height: 16),
                ],

                // Habits List with Completion Bars & Streaks
                Text(
                  isArabic ? 'نسب الالتزام وسلاسل العادات' : 'Habit Completion & Streaks',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...habits.map((habit) {
                  final stat = habitStats[habit.id];
                  if (stat == null) return const SizedBox();

                  final habitColor = Color(int.parse((habit.color ?? '#1976D2').replaceFirst('#', '0xFF')));

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HabitDetailsScreen(habitId: habit.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: habitColor.withValues(alpha: 0.15),
                                  child: Icon(HabitIconHelper.getIcon(habit.icon), color: habitColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isArabic ? habit.nameAr : (habit.nameEn ?? habit.nameAr),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: habitColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${stat.completionRate.toInt()}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: habitColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (stat.completionRate / 100).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                color: habitColor,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Streaks row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isArabic
                                      ? 'السلسلة الحالية: ${stat.currentStreak} يوم 🔥'
                                      : 'Streak: ${stat.currentStreak} days 🔥',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                ),
                                Text(
                                  isArabic
                                      ? 'أطول سلسلة: ${stat.bestStreak} يوم 🏆'
                                      : 'Best: ${stat.bestStreak} days 🏆',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<int, List<HabitItem>>> _loadAllHabitItems(AppDatabase db, List<Habit> habits) async {
    final map = <int, List<HabitItem>>{};
    for (final h in habits) {
      if (h.type == 'checklist') {
        map[h.id] = await db.getHabitItems(h.id);
      }
    }
    return map;
  }

  Widget _buildDailyCountChartCard(
    BuildContext context,
    Habit habit,
    List<HabitLog> logs,
    StatsDateRange range,
    bool isArabic,
  ) {
    final theme = Theme.of(context);
    final habitColor = Color(int.parse((habit.color ?? '#795548').replaceFirst('#', '0xFF')));

    // Build day-by-day sums
    final daysCount = range.end.difference(range.start).inDays + 1;
    final effectiveDays = daysCount.clamp(1, 31); // show at most 31 points
    final dailySums = <int, double>{};

    for (final l in logs) {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(l.logDate);
        final diff = d.difference(range.start).inDays;
        if (diff >= 0 && diff < effectiveDays) {
          dailySums[diff] = (dailySums[diff] ?? 0.0) + l.value;
        }
      } catch (_) {}
    }

    final spots = <FlSpot>[];
    double maxY = 4.0;
    for (int i = 0; i < effectiveDays; i++) {
      final val = dailySums[i] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), val));
      if (val > maxY) maxY = val;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(HabitIconHelper.getIcon(habit.icon), color: habitColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'المعدل اليومي لـ ${habit.nameAr} (${habit.unit ?? 'العدد'})'
                        : 'Daily Trend: ${habit.nameEn ?? habit.nameAr}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (effectiveDays - 1).toDouble(),
                  minY: 0,
                  maxY: maxY + 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: habitColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: habitColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCalculatedStat {
  final double completionRate;
  final int currentStreak;
  final int bestStreak;
  final int missedDays;
  final Map<String, bool> completionMap;

  const _HabitCalculatedStat({
    required this.completionRate,
    required this.currentStreak,
    required this.bestStreak,
    required this.missedDays,
    required this.completionMap,
  });
}
