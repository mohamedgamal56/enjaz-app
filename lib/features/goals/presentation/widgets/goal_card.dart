import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../domain/goal_progress_service.dart';
import '../goal_details_screen.dart';

class GoalCard extends ConsumerWidget {
  final Goal goal;

  const GoalCard({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);

    final daysLeft = GoalProgressService.calculateDaysLeft(targetDateStr: goal.targetDate);
    final isOverdue = GoalProgressService.isOverdue(
      targetDateStr: goal.targetDate,
      status: goal.status,
    );

    String formatNum(dynamic n) {
      final s = n.toString();
      if (numeralsFormat == 'arabic') {
        const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
        return s.split('').map((char) {
          final digit = int.tryParse(char);
          return digit != null ? arabicDigits[digit] : char;
        }).join('');
      }
      return s;
    }

    String getCategoryLabel(String? cat) {
      switch (cat) {
        case 'personal':
          return l10n.categoryPersonal;
        case 'work':
          return l10n.categoryWork;
        case 'study':
          return l10n.categoryStudy;
        case 'health':
          return l10n.categoryHealth;
        case 'finance':
          return l10n.categoryFinance;
        case 'other':
        default:
          return l10n.categoryOther;
      }
    }

    IconData getCategoryIcon(String? cat) {
      switch (cat) {
        case 'personal':
          return Icons.person_outline;
        case 'work':
          return Icons.business_center_outlined;
        case 'study':
          return Icons.school_outlined;
        case 'health':
          return Icons.favorite_outline;
        case 'finance':
          return Icons.account_balance_wallet_outlined;
        default:
          return Icons.star_outline;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue
              ? theme.colorScheme.error.withOpacity(0.5)
              : theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GoalDetailsScreen(goalId: goal.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<List<Milestone>>(
            stream: goal.progressMode == 'milestones'
                ? db.watchMilestonesForGoal(goal.id)
                : Stream.value([]),
            builder: (context, snapshot) {
              final milestones = snapshot.data ?? [];

              double progress = 0.0;
              String subtitle = '';
              String? nextMilestoneTitle;

              if (goal.progressMode == 'numeric') {
                final current = goal.currentValue ?? 0.0;
                final target = goal.targetValue ?? 1.0;
                progress = GoalProgressService.calculateNumericProgress(
                  currentValue: current,
                  targetValue: target,
                );
                final unit = goal.unit != null && goal.unit!.isNotEmpty ? ' ${goal.unit}' : '';
                final currStr = current.truncateToDouble() == current
                    ? current.toInt().toString()
                    : current.toStringAsFixed(1);
                final targStr = target.truncateToDouble() == target
                    ? target.toInt().toString()
                    : target.toStringAsFixed(1);

                subtitle = isArabic
                    ? '${formatNum(currStr)} من ${formatNum(targStr)}$unit'
                    : '${formatNum(currStr)} of ${formatNum(targStr)}$unit';
              } else {
                final weights = milestones.map((m) => m.weight).toList();
                final isDoneList = milestones.map((m) => m.status == 'done').toList();
                progress = GoalProgressService.calculateMilestonesProgress(
                  weights: weights,
                  isDoneList: isDoneList,
                );

                final doneCount = milestones.where((m) => m.status == 'done').length;
                final totalCount = milestones.length;

                subtitle = isArabic
                    ? '${formatNum(doneCount)} من ${formatNum(totalCount)} مراحل'
                    : '${formatNum(doneCount)} of ${formatNum(totalCount)} milestones';

                // Next pending milestone
                final pending = milestones.where((m) => m.status != 'done').toList();
                if (pending.isNotEmpty) {
                  nextMilestoneTitle = pending.first.title;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category chip + Status badge / Days left badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              getCategoryIcon(goal.category),
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              getCategoryLabel(goal.category),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Status or Days Left Badge
                      if (goal.status == 'paused') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.goalsPaused,
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (goal.status == 'done') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l10n.goalsDone,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else if (goal.targetDate != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOverdue
                                ? theme.colorScheme.errorContainer
                                : daysLeft == 0
                                    ? Colors.amber.withOpacity(0.2)
                                    : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOverdue
                                ? (isArabic
                                    ? 'متأخر ${formatNum(daysLeft.abs())} يوم'
                                    : '${formatNum(daysLeft.abs())} days overdue')
                                : daysLeft == 0
                                    ? l10n.dueToday
                                    : (isArabic
                                        ? 'باقي ${formatNum(daysLeft)} يوم'
                                        : '${formatNum(daysLeft)} days left'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOverdue
                                  ? theme.colorScheme.onErrorContainer
                                  : daysLeft == 0
                                      ? Colors.amber.shade800
                                      : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Goal Title
                  Text(
                    goal.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Goal Description if exists
                  if (goal.description != null && goal.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      goal.description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Progress Row: Subtitle + Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatNum(progress.toInt())}%',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress / 100.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: progress >= 100
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                  ),

                  // Next Milestone indicator if in Milestones mode
                  if (nextMilestoneTitle != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_right_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        Expanded(
                          child: Text(
                            '${l10n.nextMilestone}: $nextMilestoneTitle',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
