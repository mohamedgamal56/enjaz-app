import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../domain/task_selection_provider.dart';
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

    final selectionState = ref.watch(taskSelectionProvider);
    final isSelecting = selectionState.isSelecting;
    final isSelected = selectionState.selectedTaskIds.contains(task.id);

    final statusColor = AppColors.getStatusColor(task.status, isDark);
    final statusIcon = AppColors.getStatusIcon(task.status);
    final isDone = task.status == 'done';

    return Dismissible(
      key: ValueKey('task_${task.id}_${task.status}'),
      direction: isSelecting ? DismissDirection.none : DismissDirection.horizontal,
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
          _markDoneQuickly(context, ref);
          return false;
        } else {
          _openStatusSheet(context, initialStatus: 'postponed');
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isSelecting
              ? () => ref.read(taskSelectionProvider.notifier).toggle(task.id)
              : () => _openDetails(context),
          onLongPress: () {
            if (isSelecting) {
              ref.read(taskSelectionProvider.notifier).toggle(task.id);
            } else {
              ref.read(taskSelectionProvider.notifier).enterSelection(task.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Row: Checkbox, Title, Time, Priority dot, Status Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isSelecting) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) =>
                            ref.read(taskSelectionProvider.notifier).toggle(task.id),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      // Leading Checkbox (Tap = done, Long-press = enter bulk selection)
                      GestureDetector(
                        onTap: () => _markDoneQuickly(context, ref),
                        onLongPress: () =>
                            ref.read(taskSelectionProvider.notifier).enterSelection(task.id),
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
                    ],

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
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    color: isDone ? theme.colorScheme.outline : null,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Secondary Info (Kind, Time, Location, Postponed)
                          Row(
                            children: [
                              // Errand icon & text
                              if (task.kind == 'errand') ...[
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 2),
                                if (task.locationText != null &&
                                    task.locationText!.isNotEmpty) ...[
                                  Text(
                                    task.locationText!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                              ],
                              // Time
                              if (task.dueTime != null) ...[
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  AppFormatter.formatNumber(
                                    task.dueTime!,
                                    format: numeralsFormat,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              // Postpone Count if > 0
                              if (task.postponeCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.history_rounded, size: 12),
                                      const SizedBox(width: 2),
                                      Text(
                                        'أُجلت ${AppFormatter.formatNumber(task.postponeCount, format: numeralsFormat)}×',
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Voice Note indicator badge (Addendum v1.1)
                              StreamBuilder<int>(
                                stream: ref.watch(databaseProvider).watchVoiceNoteCount(
                                      'task',
                                      task.id,
                                    ),
                                builder: (context, vnSnapshot) {
                                  final count = vnSnapshot.data ?? 0;
                                  if (count == 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.graphic_eq_rounded,
                                            size: 12,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            AppFormatter.formatNumber(
                                              count,
                                              format: numeralsFormat,
                                            ),
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.teal,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Trailing Status Chip
                    if (!isSelecting)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _openStatusSheet(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                l10n.getStatusLabel(task.status),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Note preview if exists
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
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
