import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../voice_notes/presentation/widgets/voice_notes_section.dart';
import '../../reminders/domain/notification_service.dart';
import '../../reminders/presentation/notification_permission_sheet.dart';
import 'status_sheet.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskDetailsScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _locationController;
  late TextEditingController _outcomeController;

  bool _isInit = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  void _initControllers(Task task) {
    if (_isInit) return;
    _isInit = true;
    _titleController = TextEditingController(text: task.title);
    _notesController = TextEditingController(text: task.notes ?? '');
    _locationController = TextEditingController(text: task.locationText ?? '');
    _outcomeController = TextEditingController(text: task.outcomeNote ?? '');
  }

  String _formatDuration(int startedAt, int finishedAt, AppLocalizations l10n) {
    final diffMs = finishedAt - startedAt;
    if (diffMs <= 0) return '0 ${l10n.minute}';
    final duration = Duration(milliseconds: diffMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '$hours ${l10n.hour} $minutes ${l10n.minute}';
    } else {
      return '$minutes ${l10n.minute}';
    }
  }

  Future<void> _saveChanges(Task currentTask) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.updateTaskFields(
      TasksCompanion(
        id: drift.Value(currentTask.id),
        title: drift.Value(_titleController.text.trim()),
        notes: drift.Value(_notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null),
        locationText: drift.Value(_locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null),
        outcomeNote: drift.Value(_outcomeController.text.trim().isNotEmpty
            ? _outcomeController.text.trim()
            : null),
        updatedAt: drift.Value(now),
      ),
    );
  }

  void _duplicateTask(Task task) async {
    final db = ref.read(databaseProvider);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insertNewTask(
      TasksCompanion.insert(
        title: '${task.title} (نسخة)',
        notes: task.notes != null ? drift.Value(task.notes) : const drift.Value.absent(),
        kind: drift.Value(task.kind),
        priority: drift.Value(task.priority),
        dueDate: task.dueDate != null ? drift.Value(task.dueDate) : const drift.Value.absent(),
        dueTime: task.dueTime != null ? drift.Value(task.dueTime) : const drift.Value.absent(),
        locationText: task.locationText != null
            ? drift.Value(task.locationText)
            : const drift.Value.absent(),
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.taskAddedSuccess)),
    );
    Navigator.of(context).pop();
  }

  void _deleteTask(Task task) async {
    final l10n = AppLocalizations.of(context);
    final isRecurring = task.recurrenceId != null;

    if (isRecurring) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteRecurringTitle),
          content: Text(l10n.deleteTaskConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('this_only'),
              child: Text(l10n.deleteRecurringThisOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('all_future'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.deleteRecurringAllFuture),
            ),
          ],
        ),
      );

      if (choice == null) return;
      final db = ref.read(databaseProvider);
      if (choice == 'all_future') {
        await db.deleteFutureTasksForRecurrence(task.recurrenceId!, task.dueDate ?? '');
        await db.softDeleteRecurrence(task.recurrenceId!);
      }
      await db.softDeleteTask(task.id);
      await NotificationService().cancelTaskReminder(task.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTask),
        content: Text(l10n.deleteTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.deleteTask),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.softDeleteTask(task.id);
      await NotificationService().cancelTaskReminder(task.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await db.restoreTask(task.id);
              await NotificationService().scheduleTaskReminder(task: task);
            },
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Task?>(
      stream: db.watchTaskById(widget.taskId),
      builder: (context, snapshot) {
        final task = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting && task == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.taskDetailsTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (task == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.taskDetailsTitle)),
            body: Center(child: Text(l10n.taskDeleted)),
          );
        }

        _initControllers(task);

        final statusColor = AppColors.getStatusColor(task.status, isDark);
        final statusIcon = AppColors.getStatusIcon(task.status);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.taskDetailsTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_rounded),
                tooltip: l10n.duplicateTask,
                onPressed: () => _duplicateTask(task),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: l10n.deleteTask,
                onPressed: () => _deleteTask(task),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title and Kind Segmented Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: l10n.taskTitleHint,
                        ),
                        onChanged: (_) => _saveChanges(task),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Kind Badge (Task / Errand)
                    FilterChip(
                      selected: task.kind == 'errand',
                      avatar: Icon(
                        task.kind == 'errand'
                            ? Icons.location_on_outlined
                            : Icons.task_alt_rounded,
                        size: 16,
                      ),
                      label: Text(
                        task.kind == 'errand' ? l10n.errand : l10n.task,
                      ),
                      onSelected: (val) async {
                        final newKind = val ? 'errand' : 'task';
                        await db.updateTaskFields(
                          TasksCompanion(
                            id: drift.Value(task.id),
                            kind: drift.Value(newKind),
                            updatedAt: drift.Value(
                              DateTime.now().millisecondsSinceEpoch,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Status Chip (tap opens status sheet)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => StatusSheet.show(context, task: task),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              l10n.getStatusLabel(task.status),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              l10n.changeStatusTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason Card (if postponed, waiting, stopped, partial)
                if (task.reasonText != null && task.reasonText!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: statusColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.selectReason,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  task.reasonText!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Timeline Card (Created, Started, Finished, Duration)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.timeline,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.created,
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              AppFormatter.formatDateTime(
                                DateTime.fromMillisecondsSinceEpoch(task.createdAt),
                                locale: Localizations.localeOf(context).toString(),
                                format: numeralsFormat,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (task.startedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.started,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                AppFormatter.formatDateTime(
                                  DateTime.fromMillisecondsSinceEpoch(task.startedAt!),
                                  locale: Localizations.localeOf(context).toString(),
                                  format: numeralsFormat,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (task.finishedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.finished,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                AppFormatter.formatDateTime(
                                  DateTime.fromMillisecondsSinceEpoch(task.finishedAt!),
                                  locale: Localizations.localeOf(context).toString(),
                                  format: numeralsFormat,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Duration (only when both started_at and finished_at exist)
                        if (task.startedAt != null && task.finishedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.duration,
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                _formatDuration(task.startedAt!, task.finishedAt!, l10n),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getStatusColor('done', isDark),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Outcome Note (visible once done)
                if (task.status == 'done') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.celebration_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                l10n.outcomeNoteLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _outcomeController,
                            decoration: InputDecoration(
                              hintText: l10n.outcomeNoteHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => _saveChanges(task),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Errand Location Field
                if (task.kind == 'errand') ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: l10n.locationHint,
                          prefixIcon: const Icon(Icons.pin_drop_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) => _saveChanges(task),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Notes Field
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.notesHint,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => _saveChanges(task),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // History List (Every event with time, reason, and note)
                Text(
                  l10n.historyLog,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                StreamBuilder<List<TaskEvent>>(
                  stream: db.watchTaskEvents(task.id),
                  builder: (context, eventSnapshot) {
                    final events = eventSnapshot.data ?? [];
                    if (events.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final ev = events[idx];
                        final evColor = AppColors.getStatusColor(ev.toStatus, isDark);
                        final evIcon = AppColors.getStatusIcon(ev.toStatus);

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: evColor.withValues(alpha: 0.15),
                            child: Icon(evIcon, color: evColor, size: 16),
                          ),
                          title: Row(
                            children: [
                              Text(
                                ev.fromStatus.isEmpty
                                    ? l10n.created
                                    : '${l10n.getStatusLabel(ev.fromStatus)} → ${l10n.getStatusLabel(ev.toStatus)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (ev.toStatus == 'partial') ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(%${AppFormatter.formatNumber(ev.progress, format: numeralsFormat)})',
                                  style: TextStyle(
                                    color: evColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (ev.reasonText != null && ev.reasonText!.isNotEmpty)
                                Text(
                                  '${l10n.selectReason}: ${ev.reasonText!}',
                                  style: TextStyle(color: evColor, fontSize: 12),
                                ),
                              if (ev.note != null && ev.note!.isNotEmpty)
                                Text(
                                  ev.note!,
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                          trailing: Text(
                            AppFormatter.formatDateTime(
                              DateTime.fromMillisecondsSinceEpoch(ev.at),
                              locale: Localizations.localeOf(context).toString(),
                              format: numeralsFormat,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                VoiceNotesSection(parentType: 'task', parentId: task.id),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}
