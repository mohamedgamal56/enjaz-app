import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../status_sheet.dart';
import '../task_details_screen.dart';

class TaskCard extends ConsumerWidget {
  final Task task;

  const TaskCard({
    super.key,
    required this.task,
  });

  void _markDoneQuickly(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);

    if (task.status == 'done') {
      // Reopen to todo
      await db.updateTaskStatus(task: task, newStatus: 'todo');
      return;
    }

    final eventId = await db.updateTaskStatus(
      task: task,
      newStatus: 'done',
    );

    if (!context.mounted) return;

    // Show 8-second SnackBar with Undo and Add note (Spec Section 5 Rule 6)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(l10n.taskCompleted),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await db.undoStatusChange(task.id, eventId);
          },
        ),
      ),
    );
  }

  void _openStatusSheet(BuildContext context, {String? initialStatus}) {
    StatusSheet.show(
      context,
      task: task,
      initialStatus: initialStatus,
    );
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailsScreen(taskId: task.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final numeralsFormat = ref.watch(numeralsProvider);

    final statusColor = AppColors.getStatusColor(task.status, isDark);
    final statusIcon = AppColors.getStatusIcon(task.status);
    final isDone = task.status == 'done';

    return Dismissible(
      key: ValueKey('task_${task.id}_${task.status}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.getStatusColor('done', isDark).withValues(alpha: 0.8),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'تمت',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.getStatusColor('postponed', isDark).withValues(alpha: 0.8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'تأجيل',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.schedule_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // In RTL start is right, in LTR start is left.
          // Spec: toward start edge = Done, toward end edge = Postpone
          _markDoneQuickly(context, ref);
          return false; // Don't remove card from tree immediately, db stream will update it
        } else {
          // Toward end edge = Postpone (opens status sheet on postponed)
          _openStatusSheet(context, initialStatus: 'postponed');
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openDetails(context),
          onLongPress: () => _openStatusSheet(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Row: Checkbox, Title, Time, Priority dot, Status Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Leading Checkbox (Tap = done, Long-press = status sheet)
                    GestureDetector(
                      onTap: () => _markDoneQuickly(context, ref),
                      onLongPress: () => _openStatusSheet(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? statusColor : theme.colorScheme.outline,
                            width: 2,
                          ),
                          color: isDone ? statusColor : Colors.transparent,
                        ),
                        child: isDone
                            ? const Icon(
                                Icons.check_rounded,
                                size: 20,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Time & Errand Pin
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Priority Dot (High = Red, Low = Grey)
                              if (task.priority == 'high') ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDone
                                        ? theme.colorScheme.outline
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Optional Time / Location Row
                          if (task.dueTime != null ||
                              (task.kind == 'errand' && task.locationText != null)) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (task.dueTime != null) ...[
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.dueTime!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (task.kind == 'errand' &&
                                    task.locationText != null) ...[
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      task.locationText!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (task.reminderOffsetMinutes != null) ...[
                                  Icon(
                                    Icons.alarm_rounded,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (task.recurrenceId != null) ...[
                                  Icon(
                                    Icons.repeat_rounded,
                                    size: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Status Chip
                    GestureDetector(
                      onTap: () => _openStatusSheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusIcon,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.getStatusLabel(task.status),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Thin progress bar for in_progress / partial
                if (task.status == 'in_progress' || task.status == 'partial') ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.status == 'in_progress'
                          ? 0.4
                          : (task.progress / 100.0).clamp(0.01, 0.99),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                      minHeight: 4,
                    ),
                  ),
                ],

                // Reason line for postponed / waiting / stopped / partial
                if (task.reasonText != null &&
                    task.reasonText!.isNotEmpty &&
                    task.status != 'todo' &&
                    task.status != 'done') ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.reasonText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      if (task.status == 'partial') ...[
                        Text(
                          '%${AppFormatter.formatNumber(task.progress, format: numeralsFormat)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
