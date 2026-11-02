import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../excel_export/presentation/excel_export_sheet.dart';
import '../../tasks/presentation/task_details_screen.dart';
import '../domain/stats_service.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  StatsRangeType _rangeType = StatsRangeType.week;
  DateTime _referenceDate = DateTime.now();

  void _changeRangeType(StatsRangeType type) {
    setState(() {
      _rangeType = type;
      _referenceDate = DateTime.now();
    });
  }

  void _navigateRange(int direction) {
    setState(() {
      switch (_rangeType) {
        case StatsRangeType.week:
          _referenceDate = _referenceDate.add(Duration(days: 7 * direction));
          break;
        case StatsRangeType.month:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + direction, 1);
          break;
        case StatsRangeType.year:
          _referenceDate = DateTime(_referenceDate.year + direction, 1, 1);
          break;
        case StatsRangeType.allTime:
        case StatsRangeType.custom:
          break;
      }
    });
  }

  bool _canNavigateNext() {
    final now = DateTime.now();
    switch (_rangeType) {
      case StatsRangeType.week:
        return _referenceDate.isBefore(now.subtract(const Duration(days: 7)));
      case StatsRangeType.month:
        return _referenceDate.year < now.year || (_referenceDate.year == now.year && _referenceDate.month < now.month);
      case StatsRangeType.year:
        return _referenceDate.year < now.year;
      case StatsRangeType.allTime:
      case StatsRangeType.custom:
        return false;
    }
  }

  Future<StatsResult> _loadStats() async {
    final db = ref.read(databaseProvider);
    final range = StatsService.resolveRange(
      type: _rangeType,
      referenceDate: _referenceDate,
    );

    final tasks = await db.getTasksForStatsRange(range.start, range.end);
    final events = await db.getEventsForRange(range.start, range.end);
    final allDoneEvents = await db.getAllDoneEvents();
    final goals = await db.getAllGoalsList();
    final milestones = await db.getAllMilestonesList();
    final goalUpdates = await db.getGoalUpdatesForRange(range.start, range.end);
    final ideas = await db.getAllIdeasList();

    // Previous period for diff
    final prevRange = range.getPreviousRange();
    final prevEvents = await db.getEventsForRange(prevRange.start, prevRange.end);
    final prevDoneCount = prevEvents.where((e) => e.toStatus == 'done').map((e) => e.taskId).toSet().length;

    const service = StatsService();
    return service.computeStats(
      range: range,
      tasks: tasks,
      rangeEvents: events,
      allDoneEvents: allDoneEvents,
      previousPeriodCompletedCount: prevDoneCount,
      goals: goals,
      milestones: milestones,
      goalUpdates: goalUpdates,
      ideas: ideas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.locale.languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          l10n.stats,
          style: AppTypography.titleLarge(context).copyWith(
            fontWeight: FontWeight.bold,
            color: colors.text,
          ),
        ),
        centerTitle: false,
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          // Export Excel Button
          IconButton(
            icon: Icon(Icons.table_chart_rounded, color: colors.accent),
            tooltip: l10n.exportExcel,
            onPressed: () {
              ExcelExportSheet.show(
                context,
                initialRangeType: _rangeType,
                initialReferenceDate: _referenceDate,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<StatsResult>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colors.accent),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: TextStyle(color: colors.stopped),
              ),
            );
          }

          final stats = snapshot.data!;
          final rangeLabel = stats.range.getLocalizedLabel(isAr ? 'ar' : 'en');

          return RefreshIndicator(
            color: colors.accent,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Range Segmented Control
                _buildSegmentedControl(colors, l10n),
                const SizedBox(height: 12),

                // 2. Range Navigation Row
                _buildRangeNavigator(colors, rangeLabel, isAr),
                const SizedBox(height: 16),

                if (stats.isEmpty) ...[
                  _buildEmptyState(colors, l10n),
                ] else ...[
                  // 3. Summary Cards Grid
                  _buildSummaryCards(colors, l10n, stats, numeralsFormat),
                  const SizedBox(height: 20),

                  // 4. Completed Tasks Trend Chart
                  _buildTrendChartCard(colors, l10n, stats, isAr, numeralsFormat),
                  const SizedBox(height: 16),

                  // 5. Status Distribution Donut Chart
                  _buildStatusDonutCard(colors, l10n, stats, numeralsFormat),
                  const SizedBox(height: 16),

                  // 6. Top Reasons Horizontal Bars
                  if (stats.topReasons.isNotEmpty) ...[
                    _buildTopReasonsCard(colors, l10n, stats, numeralsFormat),
                    const SizedBox(height: 16),
                  ],

                  // 7. Weekday Productivity Chart
                  _buildWeekdayProductivityCard(colors, l10n, stats, isAr, numeralsFormat),
                  const SizedBox(height: 16),

                  // 8. Goals & Ideas Block
                  _buildGoalsIdeasCard(colors, l10n, stats, numeralsFormat),
                  const SizedBox(height: 16),

                  // 9. Highlights List (Latest up to 10 completed tasks)
                  if (stats.highlights.isNotEmpty) ...[
                    _buildHighlightsCard(colors, l10n, stats, numeralsFormat),
                    const SizedBox(height: 16),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Range Segmented Control ---
  Widget _buildSegmentedControl(AppColors colors, AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSegmentButton(colors, StatsRangeType.week, l10n.rangeWeek),
          _buildSegmentButton(colors, StatsRangeType.month, l10n.rangeMonth),
          _buildSegmentButton(colors, StatsRangeType.year, l10n.rangeYear),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(AppColors colors, StatsRangeType type, String label) {
    final isSelected = _rangeType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeRangeType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(context).copyWith(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? colors.accent : colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  // --- Range Navigator Row ---
  Widget _buildRangeNavigator(AppColors colors, String label, bool isAr) {
    final canNext = _canNavigateNext();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded, color: colors.text),
            onPressed: () => _navigateRange(-1),
            tooltip: 'السابق',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: colors.text,
              ),
            ),
          ),
          IconButton(
            icon: Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: canNext ? colors.text : colors.textMuted.withOpacity(0.3)),
            onPressed: canNext ? () => _navigateRange(1) : null,
            tooltip: 'التالي',
          ),
        ],
      ),
    );
  }

  // --- Summary Cards Grid ---
  Widget _buildSummaryCards(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    NumeralsFormat numFmt,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Card 1: Completed Tasks
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.completedTasksCount,
                value: AppFormatter.formatNumber(stats.completedCount, format: numFmt),
                icon: Icons.check_circle_rounded,
                iconColor: colors.done,
                badgeText: stats.completedDiff == 0
                    ? null
                    : '${stats.completedDiff > 0 ? '+' : ''}${AppFormatter.formatNumber(stats.completedDiff, format: numFmt)}',
                badgeColor: stats.completedDiff >= 0 ? colors.done : colors.stopped,
              ),
            ),
            const SizedBox(width: 10),

            // Card 2: Completion Rate
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.completionRate,
                value: '${AppFormatter.formatNumber(stats.completionRate, format: numFmt)}%',
                icon: Icons.percent_rounded,
                iconColor: colors.accent,
                progressFraction: stats.completionRate / 100.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Card 3: Postponed
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.postponedTasksCount,
                value: AppFormatter.formatNumber(stats.postponedCount, format: numFmt),
                icon: Icons.schedule_rounded,
                iconColor: colors.postponed,
              ),
            ),
            const SizedBox(width: 10),

            // Card 4: Partially Done
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.partialTasksCount,
                value: AppFormatter.formatNumber(stats.partialCount, format: numFmt),
                icon: Icons.timelapse_rounded,
                iconColor: colors.partial,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            // Card 5: Waiting & Stopped
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.waitingStoppedCount,
                value: AppFormatter.formatNumber(stats.waitingStoppedCount, format: numFmt),
                icon: Icons.pause_circle_rounded,
                iconColor: colors.stopped,
              ),
            ),
            const SizedBox(width: 10),

            // Card 6: Average Duration
            Expanded(
              child: _buildMetricCard(
                colors: colors,
                title: l10n.averageDuration,
                value: '${AppFormatter.formatNumber(stats.averageDurationMinutes.round(), format: numFmt)} ${l10n.minutesUnit}',
                icon: Icons.hourglass_top_rounded,
                iconColor: colors.inProgress,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Card 7: Streaks (Full Width)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Text('🔥', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentStreak,
                      style: AppTypography.bodySmall(context).copyWith(color: colors.textMuted),
                    ),
                    Row(
                      children: [
                        Text(
                          '${AppFormatter.formatNumber(stats.currentStreak, format: numFmt)} ${l10n.daysUnit}',
                          style: AppTypography.titleMedium(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.text,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '(${l10n.bestStreak}: ${AppFormatter.formatNumber(stats.bestStreak, format: numFmt)})',
                          style: AppTypography.bodySmall(context).copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required AppColors colors,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    String? badgeText,
    Color? badgeColor,
    double? progressFraction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor?.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.titleLarge(context).copyWith(
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.bodySmall(context).copyWith(
              color: colors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progressFraction != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFraction.clamp(0.0, 1.0),
                backgroundColor: colors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Chart 1: Trend Chart Card ---
  Widget _buildTrendChartCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    bool isAr,
    NumeralsFormat numFmt,
  ) {
    final daily = stats.dailyCompletedCounts;
    final entries = daily.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                l10n.completionTrend,
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: entries.isEmpty
                ? Center(child: Text(l10n.noStatsData, style: TextStyle(color: colors.textMuted)))
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (entries.map((e) => e.value).fold<int>(0, (max, v) => v > max ? v : max) + 2).toDouble(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final date = entries[group.x.toInt()].key;
                            final formattedDate = DateFormat('d MMM', isAr ? 'ar' : 'en').format(date);
                            return BarTooltipItem(
                              '$formattedDate\n${rod.toY.toInt()} ${l10n.task}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, meta) {
                              if (val % 2 != 0 && val != 0) return const SizedBox.shrink();
                              return Text(
                                AppFormatter.formatNumber(val.toInt(), format: numFmt),
                                style: TextStyle(color: colors.textMuted, fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, meta) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                              final dt = entries[idx].key;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('d/M', isAr ? 'ar' : 'en').format(dt),
                                  style: TextStyle(color: colors.textMuted, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: colors.border.withOpacity(0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(entries.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: entries[i].value.toDouble(),
                              color: colors.accent,
                              width: 14,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Chart 2: Status Distribution Donut ---
  Widget _buildStatusDonutCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    NumeralsFormat numFmt,
  ) {
    final dist = stats.statusDistribution;
    final total = stats.scheduledCount;

    final colorMap = <String, Color>{
      'todo': colors.textMuted,
      'in_progress': colors.inProgress,
      'partial': colors.partial,
      'done': colors.done,
      'postponed': colors.postponed,
      'waiting': colors.waiting,
      'stopped': colors.stopped,
    };

    final sections = <PieChartSectionData>[];
    dist.forEach((st, count) {
      if (count > 0) {
        sections.add(
          PieChartSectionData(
            color: colorMap[st] ?? colors.textMuted,
            value: count.toDouble(),
            title: total > 0 ? '${((count / total) * 100).round()}%' : '',
            radius: 36,
            titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                l10n.statusDistribution,
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            Center(child: Text(l10n.noStatsData, style: TextStyle(color: colors.textMuted)))
          else
            Row(
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: dist.entries.where((e) => e.value > 0).map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colorMap[e.key] ?? colors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.getStatusLabel(e.key),
                                style: AppTypography.bodySmall(context).copyWith(color: colors.text),
                              ),
                            ),
                            Text(
                              AppFormatter.formatNumber(e.value, format: numFmt),
                              style: AppTypography.bodySmall(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.text,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- Chart 3: Top Reasons ---
  Widget _buildTopReasonsCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    NumeralsFormat numFmt,
  ) {
    final top5 = stats.topReasons;
    final maxCount = top5.isNotEmpty ? top5.first.count : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_rounded, size: 20, color: colors.postponed),
              const SizedBox(width: 8),
              Text(
                l10n.topReasons,
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...top5.map((r) {
            final fraction = (r.count / maxCount).clamp(0.05, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.reason,
                          style: AppTypography.bodyMedium(context).copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${AppFormatter.formatNumber(r.count, format: numFmt)} ${l10n.daysUnit}',
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: colors.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.postponed),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Chart 4: Weekday Productivity ---
  Widget _buildWeekdayProductivityCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    bool isAr,
    NumeralsFormat numFmt,
  ) {
    // Days Saturday to Friday
    final daysOrder = [
      DateTime.saturday,
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];

    final weekdayLabelsAr = {
      DateTime.saturday: 'سبت',
      DateTime.sunday: 'أحد',
      DateTime.monday: 'إثنين',
      DateTime.tuesday: 'ثلاثاء',
      DateTime.wednesday: 'أربعاء',
      DateTime.thursday: 'خميس',
      DateTime.friday: 'جمعة',
    };

    final weekdayLabelsEn = {
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
    };

    final maxVal = daysOrder
        .map((d) => stats.weekdayProductivity[d] ?? 0)
        .fold<int>(0, (prev, v) => v > prev ? v : prev);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_view_week_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                l10n.productiveWeekday,
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxVal + 2).toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= daysOrder.length) return const SizedBox.shrink();
                        final day = daysOrder[idx];
                        final label = isAr ? weekdayLabelsAr[day]! : weekdayLabelsEn[day]!;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(color: colors.textMuted, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(daysOrder.length, (i) {
                  final day = daysOrder[i];
                  final count = stats.weekdayProductivity[day] ?? 0;
                  final isPeak = count > 0 && count == maxVal;

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: isPeak ? colors.accent : colors.accent.withOpacity(0.4),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Block 8: Goals & Ideas Card ---
  Widget _buildGoalsIdeasCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    NumeralsFormat numFmt,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 20, color: colors.accent),
              const SizedBox(width: 8),
              Text(
                '${l10n.goalsStats} & ${l10n.ideasStats}',
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMiniMetric(
                colors,
                'أهداف مكتملة',
                AppFormatter.formatNumber(stats.goalsCompletedCount, format: numFmt),
              ),
              _buildMiniMetric(
                colors,
                'مراحل أُنجزت',
                AppFormatter.formatNumber(stats.milestonesCompletedCount, format: numFmt),
              ),
              _buildMiniMetric(
                colors,
                'أفكار تم تحويلها',
                AppFormatter.formatNumber(stats.ideasConvertedCount, format: numFmt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(AppColors colors, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.titleMedium(context).copyWith(
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.bodySmall(context).copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- Highlights List ---
  Widget _buildHighlightsCard(
    AppColors colors,
    AppLocalizations l10n,
    StatsResult stats,
    NumeralsFormat numFmt,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                l10n.highlights,
                style: AppTypography.titleMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...stats.highlights.map((t) {
            final finishedStr = t.finishedAt != null
                ? DateFormat('d MMM h:mm a').format(DateTime.fromMillisecondsSinceEpoch(t.finishedAt!))
                : '';
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: t.id)),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: colors.done, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.title,
                        style: AppTypography.bodyMedium(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Text(
                      finishedStr,
                      style: TextStyle(color: colors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- Empty State ---
  Widget _buildEmptyState(AppColors colors, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insights_rounded, size: 48, color: colors.accent),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noStatsData,
            style: AppTypography.titleMedium(context).copyWith(
              fontWeight: FontWeight.bold,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.noStatsDataSubtitle,
            style: AppTypography.bodySmall(context).copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
