import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../tasks/presentation/task_details_screen.dart';
import '../domain/goal_progress_service.dart';
import 'add_goal_sheet.dart';

class GoalDetailsScreen extends ConsumerStatefulWidget {
  final int goalId;

  const GoalDetailsScreen({
    super.key,
    required this.goalId,
  });

  @override
  ConsumerState<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends ConsumerState<GoalDetailsScreen> {
  // Dialog to log numeric progress
  Future<void> _showLogProgressDialog(Goal goal) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deltaController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.trending_up_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(l10n.logProgress),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: deltaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.progressDelta,
                hintText: '+10 أو -5',
                suffixText: goal.unit,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: l10n.progressNote,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(deltaController.text.trim());
              if (val != null) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result == true) {
      final val = double.tryParse(deltaController.text.trim());
      if (val != null) {
        final db = ref.read(databaseProvider);
        await db.logGoalProgress(
          goal.id,
          val,
          note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.progressLoggedSuccess)),
        );
      }
    }
  }

  // Dialog to add or edit milestone
  Future<void> _showAddMilestoneDialog(Goal goal, {Milestone? existing}) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEdit = existing != null;
    final titleController = TextEditingController(text: existing?.title ?? '');
    int weight = existing?.weight ?? 1;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? l10n.editMilestone : l10n.addMilestone),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.milestoneTitle,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.milestoneWeight}: $weight',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: weight > 1
                            ? () => setDialogState(() => weight--)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: weight < 10
                            ? () => setDialogState(() => weight++)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final db = ref.read(databaseProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final title = titleController.text.trim();

      if (isEdit) {
        final updated = existing!.toCompanion(true).copyWith(
          title: drift.Value(title),
          weight: drift.Value(weight),
          updatedAt: drift.Value(now),
        );
        await db.updateMilestoneData(updated);
      } else {
        await db.insertNewMilestone(
          MilestonesCompanion.insert(
            goalId: goal.id,
            title: title,
            weight: drift.Value(weight),
            sortOrder: const drift.Value(0),
            status: const drift.Value('pending'),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.milestoneAdded)),
      );
    }
  }

  // Toggle milestone completion with last-milestone prompt (Spec 6.7)
  Future<void> _toggleMilestone(
    Goal goal,
    Milestone milestone,
    List<Milestone> allMilestones,
  ) async {
    final db = ref.read(databaseProvider);
    final willBeDone = milestone.status != 'done';
    await db.toggleMilestoneStatus(milestone.id, willBeDone);

    if (!mounted) return;

    if (willBeDone) {
      // Check if all OTHER milestones are already done
      final otherPending = allMilestones
          .where((m) => m.id != milestone.id && m.status != 'done')
          .toList();

      if (otherPending.isEmpty && goal.status == 'active') {
        final l10n = AppLocalizations.of(context);
        final confirmDone = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.markGoalDone),
            content: Text(l10n.allMilestonesDonePrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.markGoalDone),
              ),
            ],
          ),
        );

        if (confirmDone == true) {
          await db.updateGoalStatus(goal.id, 'done');
        }
      }
    }
  }

  // Prompt for status change reason (Pause / Abandon)
  Future<String?> _promptReason(String titlePrompt) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titlePrompt),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.reasonRequired,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(controller.text.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    String formatNum(dynamic n) {
      if (n is num) return AppFormatter.formatNumber(n, format: numeralsFormat);
      final parsed = num.tryParse(n.toString());
      if (parsed != null) return AppFormatter.formatNumber(parsed, format: numeralsFormat);
      return n.toString();
    }

    return StreamBuilder<Goal?>(
      stream: db.watchGoalById(widget.goalId),
      builder: (context, goalSnapshot) {
        if (!goalSnapshot.hasData || goalSnapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final goal = goalSnapshot.data!;
        final daysLeft = GoalProgressService.calculateDaysLeft(targetDateStr: goal.targetDate);
        final isOverdue = GoalProgressService.isOverdue(
          targetDateStr: goal.targetDate,
          status: goal.status,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tabGoals),
            actions: [
              // Edit Goal
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editGoal,
                onPressed: () {
                  AddGoalSheet.show(context, existingGoal: goal);
                },
              ),

              // More Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) async {
                  if (action == 'pause') {
                    final reason = await _promptReason(l10n.pauseReasonPrompt);
                    if (reason != null) {
                      await db.updateGoalStatus(goal.id, 'paused', reason: reason);
                    }
                  } else if (action == 'resume') {
                    await db.updateGoalStatus(goal.id, 'active');
                  } else if (action == 'done') {
                    await db.updateGoalStatus(goal.id, 'done');
                  } else if (action == 'abandon') {
                    final reason = await _promptReason(l10n.abandonReasonPrompt);
                    if (reason != null) {
                      await db.updateGoalStatus(goal.id, 'abandoned', reason: reason);
                    }
                  } else if (action == 'reopen') {
                    await db.updateGoalStatus(goal.id, 'active');
                  } else if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.deleteGoal),
                        content: Text(l10n.deleteGoalConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            child: Text(l10n.deleteTask),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await db.softDeleteGoal(goal.id);
                      if (mounted) Navigator.of(context).pop();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  if (goal.status == 'active') ...[
                    PopupMenuItem(
                      value: 'pause',
                      child: Row(
                        children: [
                          const Icon(Icons.pause_circle_outline, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(l10n.pauseGoal),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'done',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(l10n.markGoalDone),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'abandon',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(l10n.abandonGoal),
                        ],
                      ),
                    ),
                  ] else if (goal.status == 'paused') ...[
                    PopupMenuItem(
                      value: 'resume',
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(l10n.resumeGoal),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'done',
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(l10n.markGoalDone),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'abandon',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(l10n.abandonGoal),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Done or Abandoned
                    PopupMenuItem(
                      value: 'reopen',
                      child: Row(
                        children: [
                          const Icon(Icons.refresh_rounded),
                          const SizedBox(width: 8),
                          Text(l10n.resumeGoal),
                        ],
                      ),
                    ),
                  ],
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text(l10n.deleteGoal, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Progress Card with Circular Ring
                _buildHeaderProgressCard(context, goal, daysLeft, isOverdue, formatNum),
                const SizedBox(height: 16),

                // Milestones or Numeric Progress section
                if (goal.progressMode == 'milestones')
                  _buildMilestonesSection(context, goal, formatNum)
                else
                  _buildNumericSection(context, goal, formatNum),

                const SizedBox(height: 24),

                // Linked Tasks Section
                _buildLinkedTasksSection(context, goal, formatNum),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // Large Header Card with Circular Indicator & Details
  Widget _buildHeaderProgressCard(
    BuildContext context,
    Goal goal,
    int daysLeft,
    bool isOverdue,
    String Function(dynamic) formatNum,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.watch(databaseProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: StreamBuilder<List<Milestone>>(
          stream: goal.progressMode == 'milestones'
              ? db.watchMilestonesForGoal(goal.id)
              : Stream.value([]),
          builder: (context, snapshot) {
            final milestones = snapshot.data ?? [];
            double progress = 0.0;

            if (goal.progressMode == 'numeric') {
              final current = goal.currentValue ?? 0.0;
              final target = goal.targetValue ?? 1.0;
              progress = GoalProgressService.calculateNumericProgress(
                currentValue: current,
                targetValue: target,
              );
            } else {
              final weights = milestones.map((m) => m.weight).toList();
              final isDoneList = milestones.map((m) => m.status == 'done').toList();
              progress = GoalProgressService.calculateMilestonesProgress(
                weights: weights,
                isDoneList: isDoneList,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big Circular Ring
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: (progress / 100.0).clamp(0.0, 1.0),
                        strokeWidth: 10,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: progress >= 100 ? Colors.green : theme.colorScheme.primary,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formatNum(progress.toInt())}%',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Text(
                              goal.status == 'done'
                                  ? l10n.goalsDone
                                  : goal.status == 'paused'
                                      ? l10n.goalsPaused
                                      : l10n.goalsActive,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Goal Title
                Text(
                  goal.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),

                // Goal Description
                if (goal.description != null && goal.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    goal.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],

                // Status Reason if paused or abandoned
                if (goal.statusReason != null && goal.statusReason!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${l10n.notesHint}: ${goal.statusReason}',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Meta Row: Target Date & Days Left
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Target Date
                    Column(
                      children: [
                        Text(l10n.targetDate, style: theme.textTheme.labelSmall),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              goal.targetDate ?? l10n.noTargetDate,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Days Left Badge
                    if (goal.targetDate != null)
                      Column(
                        children: [
                          Text(l10n.filterStatus, style: theme.textTheme.labelSmall),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? theme.colorScheme.errorContainer
                                  : daysLeft == 0
                                      ? Colors.amber.withOpacity(0.2)
                                      : theme.colorScheme.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isOverdue
                                  ? (isArabic
                                      ? 'متأخر ${formatNum(daysLeft.abs())} يوم'
                                      : '${formatNum(daysLeft.abs())} d overdue')
                                  : daysLeft == 0
                                      ? l10n.dueToday
                                      : (isArabic
                                          ? 'باقي ${formatNum(daysLeft)} يوم'
                                          : '${formatNum(daysLeft)} d left'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOverdue
                                    ? theme.colorScheme.onErrorContainer
                                    : daysLeft == 0
                                        ? Colors.amber.shade800
                                        : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Milestones List Section
  Widget _buildMilestonesSection(
    BuildContext context,
    Goal goal,
    String Function(dynamic) formatNum,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<Milestone>>(
      stream: db.watchMilestonesForGoal(goal.id),
      builder: (context, snapshot) {
        final milestones = snapshot.data ?? [];

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.milestones} (${formatNum(milestones.where((m) => m.status == 'done').length)}/${formatNum(milestones.length)})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.addMilestone),
                      onPressed: () => _showAddMilestoneDialog(goal),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (milestones.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        l10n.noMilestonesYet,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: milestones.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (oldIndex < newIndex) newIndex -= 1;
                      final item = milestones.removeAt(oldIndex);
                      milestones.insert(newIndex, item);
                      for (int i = 0; i < milestones.length; i++) {
                        await db.updateMilestoneData(
                          milestones[i].toCompanion(true).copyWith(
                                sortOrder: drift.Value(i),
                              ),
                        );
                      }
                    },
                    itemBuilder: (ctx, idx) {
                      final m = milestones[idx];
                      final isDone = m.status == 'done';

                      return ListTile(
                        key: ValueKey(m.id),
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: isDone,
                          onChanged: (_) => _toggleMilestone(goal, m, milestones),
                        ),
                        title: Text(
                          m.title,
                          style: TextStyle(
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? theme.colorScheme.outline : null,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: m.weight > 1
                            ? Text(
                                '${l10n.milestoneWeight}: ${formatNum(m.weight)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showAddMilestoneDialog(goal, existing: m),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                              onPressed: () async {
                                await db.deleteMilestoneSoft(m.id);
                              },
                            ),
                            ReorderableDragStartListener(
                              index: idx,
                              child: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Numeric Goal Section with Log Progress & Updates History
  Widget _buildNumericSection(
    BuildContext context,
    Goal goal,
    String Function(dynamic) formatNum,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    final current = goal.currentValue ?? 0.0;
    final target = goal.targetValue ?? 1.0;
    final unit = goal.unit != null && goal.unit!.isNotEmpty ? ' ${goal.unit}' : '';

    final currStr = current.truncateToDouble() == current
        ? current.toInt().toString()
        : current.toStringAsFixed(1);
    final targStr = target.truncateToDouble() == target
        ? target.toInt().toString()
        : target.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Numeric Summary Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.currentValue, style: theme.textTheme.labelSmall),
                        Text(
                          '${formatNum(currStr)}$unit',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(l10n.targetValue, style: theme.textTheme.labelSmall),
                        Text(
                          '${formatNum(targStr)}$unit',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.add_chart_rounded),
                  label: Text(l10n.logProgress),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _showLogProgressDialog(goal),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Progress Updates History
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.progressHistory,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<GoalUpdate>>(
                  stream: db.watchGoalUpdates(goal.id),
                  builder: (context, snapshot) {
                    final updates = snapshot.data ?? [];
                    if (updates.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            l10n.noGoalUpdatesYet,
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: updates.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final u = updates[idx];
                        final delta = u.valueDelta ?? 0.0;
                        final isPositive = delta >= 0;
                        final deltaStr = delta.truncateToDouble() == delta
                            ? delta.toInt().toString()
                            : delta.toStringAsFixed(1);
                        final dateStr = AppFormatter.formatDate(
                          DateTime.fromMillisecondsSinceEpoch(u.at),
                          locale: isArabic ? 'ar' : 'en',
                          format: numeralsFormat,
                        );

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isPositive
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            child: Icon(
                              isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              color: isPositive ? Colors.green : Colors.red,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            '${isPositive ? '+' : ''}${formatNum(deltaStr)}$unit',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                          subtitle: u.note != null && u.note!.isNotEmpty ? Text(u.note!) : null,
                          trailing: Text(
                            dateStr,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Linked Tasks Section
  Widget _buildLinkedTasksSection(
    BuildContext context,
    Goal goal,
    String Function(dynamic) formatNum,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final db = ref.watch(databaseProvider);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.linkedTasks,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: Text(l10n.addTaskToGoal),
                  onPressed: () {
                    QuickAddSheet.show(context, initialGoalId: goal.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            StreamBuilder<List<Task>>(
              stream: db.watchTasksForGoal(goal.id),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Text(
                        l10n.noLinkedTasksYet,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final t = tasks[idx];
                    final isDone = t.status == 'done';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: isDone ? Colors.green : theme.colorScheme.outline,
                      ),
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: t.dueDate != null ? Text(t.dueDate!) : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.green.withOpacity(0.15)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.getStatusLabel(t.status),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDone ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TaskDetailsScreen(taskId: t.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
