import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../finance/presentation/add_transaction_sheet.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../goals/presentation/goal_details_screen.dart';
import '../../habits/presentation/habit_details_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../health/presentation/add_edit_health_item_sheet.dart';
import '../../health/presentation/add_edit_treatment_sheet.dart';
import '../../health/presentation/health_screen.dart';
import '../../ideas/presentation/idea_details_screen.dart';
import '../../notes/presentation/add_note_sheet.dart';
import '../../plan/presentation/plan_screen.dart';
import '../../tasks/presentation/task_details_screen.dart';
import '../../voice_notes/presentation/widgets/voice_player_card.dart';
import '../domain/timeline_models.dart';
import '../domain/timeline_provider.dart';

class TimelineDayView extends ConsumerStatefulWidget {
  final DateTime date;
  final VoidCallback onDayChanged;

  const TimelineDayView({
    super.key,
    required this.date,
    required this.onDayChanged,
  });

  @override
  ConsumerState<TimelineDayView> createState() => _TimelineDayViewState();
}

class _TimelineDayViewState extends ConsumerState<TimelineDayView> {
  TimelineModule? _selectedFilter;

  Future<void> _navigateToSource(BuildContext context, TimelineEntry entry) async {
    final db = ref.read(databaseProvider);
    switch (entry.sourceType) {
      case 'task':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskDetailsScreen(taskId: entry.sourceId)),
        );
        break;

      case 'habit':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => HabitDetailsScreen(habitId: entry.sourceId)),
        );
        break;

      case 'idea':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => IdeaDetailsScreen(ideaId: entry.sourceId)),
        );
        break;

      case 'goal':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalDetailsScreen(goalId: entry.sourceId)),
        );
        break;

      case 'note':
        final note = await (db.select(db.notes)..where((n) => n.id.equals(entry.sourceId))).getSingleOrNull();
        if (note != null && context.mounted) {
          AddNoteSheet.show(context, noteToEdit: note);
        } else if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanScreen()));
        }
        break;

      case 'transaction':
        final tx = await (db.select(db.transactions)..where((t) => t.id.equals(entry.sourceId))).getSingleOrNull();
        if (tx != null && context.mounted) {
          AddTransactionSheet.show(context, existingTransaction: tx);
        } else if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen()));
        }
        break;

      case 'obligation':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinanceScreen()),
        );
        break;

      case 'health_item':
        final item = await (db.select(db.healthItems)..where((h) => h.id.equals(entry.sourceId))).getSingleOrNull();
        if (item != null && context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddEditHealthItemSheet(itemToEdit: item),
          );
        } else if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
        }
        break;

      case 'treatment':
        final treatment = await (db.select(db.treatments)..where((t) => t.id.equals(entry.sourceId))).getSingleOrNull();
        if (treatment != null && context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => AddEditTreatmentSheet(treatmentToEdit: treatment),
          );
        } else if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
        }
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final numerals = ref.watch(numeralsProvider);
    final aggregator = ref.watch(timelineAggregatorProvider);

    return FutureBuilder<(List<TimelineEntry>, TimelineDaySummary)>(
      future: aggregator.getTimelineForDay(widget.date),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: colors.accent),
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

        final data = snapshot.data!;
        final allEntries = data.$1;
        final summary = data.$2;

        // Apply module filter if selected
        final filteredEntries = _selectedFilter == null
            ? allEntries
            : allEntries.where((e) => e.module == _selectedFilter).toList();

        final allDayEntries = filteredEntries.where((e) => e.allDay).toList();
        final timedEntries = filteredEntries.where((e) => !e.allDay).toList();

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 1. Header Totals Card
            _buildDayHeaderCard(context, summary, isAr, numerals),
            const SizedBox(height: 12),

            // 2. Filter Chips Row
            _buildFilterChips(context, isAr),
            const SizedBox(height: 16),

            // Empty state check
            if (filteredEntries.isEmpty) ...[
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off_rounded, size: 56, color: colors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      isAr ? 'لا توجد أنشطة مسجلة في هذا اليوم' : 'No activities recorded for this day',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ] else ...[
              // 3. All Day Section
              if (allDayEntries.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      isAr ? 'طوال اليوم / All day' : 'All day',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...allDayEntries.map((e) => _buildTimelineCard(context, e, isAr, numerals)),
                const SizedBox(height: 16),
              ],

              // 4. Chronological Timeline with Hour Markers
              if (timedEntries.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(
                      isAr ? 'السجل الزمني' : 'Timeline',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...timedEntries.map((e) => _buildTimelineCard(context, e, isAr, numerals)),
              ],
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildDayHeaderCard(
    BuildContext context,
    TimelineDaySummary summary,
    bool isAr,
    NumeralsFormat numerals,
  ) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr ? 'ملخص إنجاز اليوم' : "Day's Progress Summary",
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSummaryBadge(
                  icon: Icons.task_alt_rounded,
                  color: Colors.blue,
                  label: AppFormatter.formatStringDigits(
                    isAr ? '${summary.tasksDoneCount} مهام منجزة' : '${summary.tasksDoneCount} tasks done',
                    format: numerals,
                  ),
                ),
                if (summary.expensesMinor > 0)
                  _buildSummaryBadge(
                    icon: Icons.trending_down_rounded,
                    color: Colors.redAccent,
                    label: AppFormatter.formatStringDigits(
                      isAr
                          ? 'مصروف: ${MoneyFormatter.formatMinorWithCurrency(summary.expensesMinor)}'
                          : 'Spent: ${MoneyFormatter.formatMinorWithCurrency(summary.expensesMinor)}',
                      format: numerals,
                    ),
                  ),
                if (summary.incomeMinor > 0)
                  _buildSummaryBadge(
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                    label: AppFormatter.formatStringDigits(
                      isAr
                          ? 'دخل: ${MoneyFormatter.formatMinorWithCurrency(summary.incomeMinor)}'
                          : 'Income: ${MoneyFormatter.formatMinorWithCurrency(summary.incomeMinor)}',
                      format: numerals,
                    ),
                  ),
                _buildSummaryBadge(
                  icon: Icons.repeat_rounded,
                  color: Colors.teal,
                  label: AppFormatter.formatStringDigits(
                    isAr ? '${summary.habitsDoneCount} عادات' : '${summary.habitsDoneCount} habits',
                    format: numerals,
                  ),
                ),
                _buildSummaryBadge(
                  icon: Icons.note_alt_rounded,
                  color: Colors.orange,
                  label: AppFormatter.formatStringDigits(
                    isAr ? '${summary.notesCount} ملاحظات' : '${summary.notesCount} notes',
                    format: numerals,
                  ),
                ),
                _buildSummaryBadge(
                  icon: Icons.lightbulb_rounded,
                  color: Colors.purple,
                  label: AppFormatter.formatStringDigits(
                    isAr ? '${summary.ideasCount} أفكار' : '${summary.ideasCount} ideas',
                    format: numerals,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBadge({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, bool isAr) {
    final modules = TimelineModule.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(isAr ? 'الكل' : 'All'),
            selected: _selectedFilter == null,
            onSelected: (val) {
              setState(() => _selectedFilter = null);
            },
          ),
          const SizedBox(width: 6),
          ...modules.map((m) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                avatar: Icon(m.icon, size: 14, color: m.color),
                label: Text(isAr ? m.labelAr : m.labelEn),
                selected: _selectedFilter == m,
                onSelected: (val) {
                  setState(() => _selectedFilter = val ? m : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(
    BuildContext context,
    TimelineEntry entry,
    bool isAr,
    NumeralsFormat numerals,
  ) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    final timeLabel = entry.timeStr != null
        ? AppFormatter.formatStringDigits(entry.timeStr!, format: numerals)
        : (entry.allDay ? (isAr ? 'طوال اليوم' : 'All day') : '');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToSource(context, entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Module Icon
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: entry.color.withValues(alpha: 0.15),
                    child: Icon(entry.icon, size: 16, color: entry.color),
                  ),
                  const SizedBox(width: 10),

                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (entry.subtitle != null && entry.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            entry.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Time & Badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeLabel.isNotEmpty)
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: entry.color,
                          ),
                        ),
                      if (entry.statusBadge != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: entry.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.statusBadge!,
                            style: TextStyle(fontSize: 10, color: entry.color, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              // Inline voice note player if entry has voice
              if (entry.hasVoice && entry.voiceFileName != null) ...[
                const SizedBox(height: 8),
                FutureBuilder<VoiceNote?>(
                  future: _findVoiceNote(entry.sourceType, entry.sourceId),
                  builder: (ctx, snap) {
                    if (snap.data != null) {
                      return VoicePlayerCard(voiceNote: snap.data!);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<VoiceNote?> _findVoiceNote(String parentType, int parentId) async {
    final db = ref.read(databaseProvider);
    final all = await db.getAllVoiceNotesList();
    return all.where((v) => v.parentType == parentType && v.parentId == parentId).firstOrNull;
  }
}
