import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../voice_notes/presentation/widgets/voice_notes_section.dart';
import '../../reminders/domain/notification_service.dart';
import '../../reminders/domain/reminder_scheduler.dart';
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

class _LocalReminderItem {
  int? id;
  String kind; // 'alarm' | 'notification'
  String triggerType; // 'offset' | 'absolute'
  int? offsetMinutes;
  DateTime? absoluteTime;
  String? message;

  _LocalReminderItem({
    this.id,
    required this.kind,
    this.triggerType = 'offset',
    this.offsetMinutes = 0,
    this.absoluteTime,
    this.message,
  });
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late TextEditingController _locationController;
  late TextEditingController _outcomeController;

  String _kind = 'task';
  String _priority = 'normal';
  String? _dueDate;
  String? _dueTime;
  int? _goalId;
  int? _startedAt;
  int? _finishedAt;

  List<_LocalReminderItem> _localReminders = [];
  bool _isInit = false;
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  void _initFromTask(Task task, List<Reminder> initialReminders) {
    if (_isInit) return;
    _isInit = true;

    _titleController = TextEditingController(text: task.title);
    _notesController = TextEditingController(text: task.notes ?? '');
    _locationController = TextEditingController(text: task.locationText ?? '');
    _outcomeController = TextEditingController(text: task.outcomeNote ?? '');

    _kind = task.kind;
    _priority = task.priority;
    _dueDate = task.dueDate;
    _dueTime = task.dueTime;
    _goalId = task.goalId;
    _startedAt = task.startedAt;
    _finishedAt = task.finishedAt;

    _localReminders = initialReminders.map((r) {
      return _LocalReminderItem(
        id: r.id,
        kind: r.kind,
        triggerType: r.triggerType,
        offsetMinutes: r.offsetMinutes,
        absoluteTime: r.absoluteTime,
        message: r.message,
      );
    }).toList();
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    DateTime initial = now;
    if (_dueDate != null && _dueDate!.contains('-')) {
      final parts = _dueDate!.split('-');
      if (parts.length == 3) {
        initial = DateTime(
          int.tryParse(parts[0]) ?? now.year,
          int.tryParse(parts[1]) ?? now.month,
          int.tryParse(parts[2]) ?? now.day,
        );
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2046),
    );

    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      setState(() {
        _dueDate = '$y-$m-$d';
        _isDirty = true;
      });
    }
  }

  Future<void> _pickDueTime() async {
    TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
    if (_dueTime != null && _dueTime!.contains(':')) {
      final parts = _dueTime!.split(':');
      initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _dueTime = '$h:$m';
        _isDirty = true;
      });
    }
  }

  Future<void> _pickStartedAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startedAt != null ? DateTime.fromMillisecondsSinceEpoch(_startedAt!) : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2046),
    );
    if (picked != null && mounted) {
      final timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _startedAt != null ? DateTime.fromMillisecondsSinceEpoch(_startedAt!) : now,
        ),
      );
      if (timePicked != null) {
        final dt = DateTime(picked.year, picked.month, picked.day, timePicked.hour, timePicked.minute);
        setState(() {
          _startedAt = dt.millisecondsSinceEpoch;
          _isDirty = true;
        });
      }
    }
  }

  Future<void> _pickFinishedAt() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _finishedAt != null ? DateTime.fromMillisecondsSinceEpoch(_finishedAt!) : now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2046),
    );
    if (picked != null && mounted) {
      final timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _finishedAt != null ? DateTime.fromMillisecondsSinceEpoch(_finishedAt!) : now,
        ),
      );
      if (timePicked != null) {
        final dt = DateTime(picked.year, picked.month, picked.day, timePicked.hour, timePicked.minute);
        setState(() {
          _finishedAt = dt.millisecondsSinceEpoch;
          _isDirty = true;
        });
      }
    }
  }

  void _showAddReminderSheet(bool isArabic) {
    if (_localReminders.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'الحد الأقصى 3 تنبيهات لكل مهمة' : 'Maximum 3 reminders per task',
          ),
        ),
      );
      return;
    }

    String selectedKind = 'alarm';
    int selectedOffset = 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isArabic ? 'إضافة تنبيه جديد' : 'Add New Reminder',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Kind Selector (Alarm vs Notification)
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.alarm_rounded, size: 18),
                          label: Text(isArabic ? 'منبه (Alarm)' : 'Alarm'),
                          selected: selectedKind == 'alarm',
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedKind = 'alarm');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          avatar: const Icon(Icons.notifications_rounded, size: 18),
                          label: Text(isArabic ? 'إشعار (Notification)' : 'Notification'),
                          selected: selectedKind == 'notification',
                          onSelected: (val) {
                            if (val) setSheetState(() => selectedKind = 'notification');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Offset Selector
                  Text(
                    isArabic ? 'موعد التنبيه بالنسبة لوقت المهمة:' : 'Reminder timing:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _offsetChip(0, isArabic ? 'في الموعد تماماً' : 'At due time', selectedOffset, (val) {
                        setSheetState(() => selectedOffset = val);
                      }),
                      _offsetChip(10, isArabic ? 'قبل 10 دقائق' : '10 min before', selectedOffset, (val) {
                        setSheetState(() => selectedOffset = val);
                      }),
                      _offsetChip(30, isArabic ? 'قبل 30 دقيقة' : '30 min before', selectedOffset, (val) {
                        setSheetState(() => selectedOffset = val);
                      }),
                      _offsetChip(60, isArabic ? 'قبل ساعة' : '1 hour before', selectedOffset, (val) {
                        setSheetState(() => selectedOffset = val);
                      }),
                      _offsetChip(1440, isArabic ? 'قبل يوم' : '1 day before', selectedOffset, (val) {
                        setSheetState(() => selectedOffset = val);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _localReminders.add(
                          _LocalReminderItem(
                            kind: selectedKind,
                            triggerType: 'offset',
                            offsetMinutes: selectedOffset,
                          ),
                        );
                        _isDirty = true;
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(isArabic ? 'إضافة التنبيه' : 'Add Reminder'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _offsetChip(int value, String label, int currentSelected, Function(int) onSelected) {
    final selected = currentSelected == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) onSelected(value);
      },
    );
  }

  Future<void> _pickGoal(List<Goal> goals, bool isArabic) async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              isArabic ? 'اختر الهدف المرتبط' : 'Select Linked Goal',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_off_rounded),
              title: Text(isArabic ? 'بدون هدف (فصل الارتباط)' : 'No Goal (Unlink)'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            ...goals.map((g) {
              return ListTile(
                leading: const Icon(Icons.flag_rounded, color: Colors.teal),
                title: Text(g.title),
                trailing: _goalId == g.id ? const Icon(Icons.check, color: Colors.teal) : null,
                onTap: () => Navigator.pop(ctx, g.id),
              );
            }),
          ],
        );
      },
    );

    if (selected != null) {
      setState(() {
        _goalId = selected == -1 ? null : selected;
        _isDirty = true;
      });
    }
  }

  Future<void> _saveAllChanges(Task currentTask) async {
    setState(() => _isSaving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Handle Recurring Task choice (Spec 1.1)
    if (currentTask.recurrenceId != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isArabic ? 'تعديل مهمة متكررة' : 'Edit Recurring Task'),
          content: Text(
            isArabic
                ? 'هل تريد تطبيق هذه التعديلات على هذه المهمة فقط، أم على كل المهام القادمة؟'
                : 'Apply these changes to this task only, or all future recurring tasks?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'this_only'),
              child: Text(isArabic ? 'هذه فقط' : 'This only'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'all_future'),
              child: Text(isArabic ? 'كل القادمة' : 'All future'),
            ),
          ],
        ),
      );

      if (choice == null) {
        setState(() => _isSaving = false);
        return;
      }

      if (choice == 'all_future') {
        await db.updateFutureTasksForRecurrence(
          recurrenceId: currentTask.recurrenceId!,
          fromDate: currentTask.dueDate ?? '',
          title: _titleController.text.trim(),
          kind: _kind,
          dueTime: _dueTime,
          priority: _priority,
          notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        );
      }
    }

    // Update current task fields
    await db.updateTaskFields(
      TasksCompanion(
        id: drift.Value(currentTask.id),
        title: drift.Value(_titleController.text.trim()),
        kind: drift.Value(_kind),
        priority: drift.Value(_priority),
        dueDate: drift.Value(_dueDate),
        dueTime: drift.Value(_dueTime),
        locationText: drift.Value(
          _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        ),
        notes: drift.Value(
          _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        ),
        outcomeNote: drift.Value(
          _outcomeController.text.trim().isNotEmpty ? _outcomeController.text.trim() : null,
        ),
        goalId: drift.Value(_goalId),
        startedAt: drift.Value(_startedAt),
        finishedAt: drift.Value(_finishedAt),
        updatedAt: drift.Value(now),
      ),
    );

    // Sync Reminders using ReminderScheduler
    final scheduler = ReminderScheduler(db: db);
    await scheduler.cancelAllForOwner('task', currentTask.id);
    await db.deleteRemindersForOwner('task', currentTask.id);

    for (final rem in _localReminders) {
      final remId = await db.insertReminder(
        ownerType: 'task',
        ownerId: currentTask.id,
        kind: rem.kind,
        triggerType: rem.triggerType,
        offsetMinutes: rem.offsetMinutes,
        absoluteTime: rem.absoluteTime,
        message: rem.message,
      );
      final savedReminder = await (db.select(db.reminders)..where((r) => r.id.equals(remId))).getSingleOrNull();
      if (savedReminder != null && currentTask.status != 'done') {
        await scheduler.scheduleReminder(
          reminder: savedReminder,
          title: _titleController.text.trim(),
          dueDate: _dueDate,
          dueTime: _dueTime,
          languageCode: isArabic ? 'ar' : 'en',
        );
      }
    }

    setState(() {
      _isDirty = false;
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم حفظ التعديلات بنجاح ✅' : 'Changes saved successfully ✅'),
        ),
      );
    }
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
        locationText: task.locationText != null ? drift.Value(task.locationText) : const drift.Value.absent(),
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
      await ReminderScheduler(db: db).cancelAllForOwner('task', task.id);
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
      await ReminderScheduler(db: db).cancelAllForOwner('task', task.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskDeleted),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              await db.restoreTask(task.id);
              await ReminderScheduler(db: db).rescheduleAllForOwner(
                'task',
                task.id,
                title: task.title,
                dueDate: task.dueDate,
                dueTime: task.dueTime,
              );
            },
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تعديلات غير محفوظة' : 'Unsaved Changes'),
        content: Text(
          isArabic
              ? 'لديك تعديلات لم تقم بحفظها، هل تريد الخروج وتجاهل التعديلات؟'
              : 'You have unsaved changes. Do you want to discard them and leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'البقاء في الصفحة' : 'Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'تجاهل والخروج' : 'Discard & Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: StreamBuilder<Task?>(
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

          return FutureBuilder<List<Reminder>>(
            future: db.getRemindersForOwner('task', task.id),
            builder: (context, remindersSnapshot) {
              if (!_isInit && remindersSnapshot.hasData) {
                _initFromTask(task, remindersSnapshot.data ?? []);
              }

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
                bottomNavigationBar: _isDirty
                    ? SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: FilledButton.icon(
                            onPressed: _isSaving ? null : () => _saveAllChanges(task),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              _isSaving
                                  ? (isArabic ? 'جاري الحفظ...' : 'Saving...')
                                  : (isArabic ? 'حفظ التعديلات' : 'Save Changes'),
                            ),
                          ),
                        ),
                      )
                    : null,
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title Text Field
                      TextField(
                        controller: _titleController,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'عنوان المهمة' : 'Task Title',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: 12),

                      // Kind and Priority Row
                      Row(
                        children: [
                          // Kind Selector
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _kind,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'النوع' : 'Kind',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'task',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.task_alt_rounded, size: 18),
                                      const SizedBox(width: 8),
                                      Text(l10n.task),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'errand',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 18),
                                      const SizedBox(width: 8),
                                      Text(l10n.errand),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _kind = val;
                                    _isDirty = true;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Priority Selector
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _priority,
                              decoration: InputDecoration(
                                labelText: isArabic ? 'الأولوية' : 'Priority',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'low',
                                  child: Text(isArabic ? 'منخفضة (Low)' : 'Low'),
                                ),
                                DropdownMenuItem(
                                  value: 'normal',
                                  child: Text(isArabic ? 'عادية (Normal)' : 'Normal'),
                                ),
                                DropdownMenuItem(
                                  value: 'high',
                                  child: Text(isArabic ? 'عالية (High)' : 'High'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _priority = val;
                                    _isDirty = true;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location Field (for errand or if filled)
                      if (_kind == 'errand' || _locationController.text.isNotEmpty) ...[
                        TextField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: l10n.locationHint,
                            prefixIcon: const Icon(Icons.pin_drop_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => _markDirty(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDueDate,
                              icon: const Icon(Icons.calendar_today_rounded, size: 18),
                              label: Text(
                                _dueDate != null
                                    ? _dueDate!
                                    : (isArabic ? 'بدون تاريخ' : 'No Date'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDueTime,
                              icon: const Icon(Icons.access_time_rounded, size: 18),
                              label: Text(
                                _dueTime != null
                                    ? _dueTime!
                                    : (isArabic ? 'بدون وقت' : 'No Time'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status Chip (opens status sheet)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => StatusSheet.show(context, task: task),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: statusColor.withOpacity(0.4)),
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
                                    style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: statusColor),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Linked Goal Section
                      FutureBuilder<List<Goal>>(
                        future: db.getAllActiveGoals(),
                        builder: (context, goalsSnapshot) {
                          final goals = goalsSnapshot.data ?? [];
                          final linkedGoal = goals.where((g) => g.id == _goalId).firstOrNull;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const Icon(Icons.flag_rounded, color: Colors.teal),
                              title: Text(isArabic ? 'الهدف المرتبط' : 'Linked Goal'),
                              subtitle: Text(
                                linkedGoal != null
                                    ? linkedGoal.title
                                    : (isArabic ? 'غير مرتبط بهدف' : 'Not linked to a goal'),
                              ),
                              trailing: TextButton(
                                onPressed: () => _pickGoal(goals, isArabic),
                                child: Text(isArabic ? 'تغيير' : 'Change'),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Reminders Section (Spec 1.1 & 1.2: up to 3 reminders)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.alarm_rounded, color: Colors.teal),
                                      const SizedBox(width: 8),
                                      Text(
                                        isArabic ? 'التنبيهات والمنبه' : 'Reminders & Alarm',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_localReminders.length < 3)
                                    TextButton.icon(
                                      onPressed: () => _showAddReminderSheet(isArabic),
                                      icon: const Icon(Icons.add, size: 18),
                                      label: Text(isArabic ? 'إضافة تنبيه' : 'Add'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_localReminders.isEmpty)
                                Text(
                                  isArabic ? 'لا توجد تنبيهات محددة لهذه المهمة' : 'No reminders set',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                )
                              else
                                ..._localReminders.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final rem = entry.value;
                                  final isAlarm = rem.kind == 'alarm';
                                  final offsetLabel = rem.offsetMinutes == 0
                                      ? (isArabic ? 'في الموعد تماماً' : 'At due time')
                                      : (isArabic ? 'قبل ${rem.offsetMinutes} دقيقة' : '${rem.offsetMinutes} min before');

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isAlarm ? Icons.alarm_rounded : Icons.notifications_rounded,
                                          size: 20,
                                          color: isAlarm ? Colors.orange : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${isAlarm ? (isArabic ? "منبه" : "Alarm") : (isArabic ? "إشعار" : "Notification")} - $offsetLabel',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _localReminders.removeAt(idx);
                                              _isDirty = true;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Timeline Card (Editable Started & Finished Times)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                  Text(l10n.created, style: theme.textTheme.bodySmall),
                                  Text(
                                    AppFormatter.formatDateTime(
                                      DateTime.fromMillisecondsSinceEpoch(task.createdAt),
                                      locale: Localizations.localeOf(context).toString(),
                                      format: numeralsFormat,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.started, style: theme.textTheme.bodySmall),
                                  Row(
                                    children: [
                                      Text(
                                        _startedAt != null
                                            ? AppFormatter.formatDateTime(
                                                DateTime.fromMillisecondsSinceEpoch(_startedAt!),
                                                locale: Localizations.localeOf(context).toString(),
                                                format: numeralsFormat,
                                              )
                                            : (isArabic ? 'لم تبدأ بعد' : 'Not started'),
                                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                                        onPressed: _pickStartedAt,
                                        tooltip: isArabic ? 'تعديل وقت البدء' : 'Edit started time',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(l10n.finished, style: theme.textTheme.bodySmall),
                                  Row(
                                    children: [
                                      Text(
                                        _finishedAt != null
                                            ? AppFormatter.formatDateTime(
                                                DateTime.fromMillisecondsSinceEpoch(_finishedAt!),
                                                locale: Localizations.localeOf(context).toString(),
                                                format: numeralsFormat,
                                              )
                                            : (isArabic ? 'لم تكتمل بعد' : 'Not finished'),
                                        style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                                        onPressed: _pickFinishedAt,
                                        tooltip: isArabic ? 'تعديل وقت الانتهاء' : 'Edit finished time',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (_startedAt != null && _finishedAt != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(l10n.duration, style: theme.textTheme.bodySmall),
                                    Text(
                                      _formatDuration(_startedAt!, _finishedAt!, l10n),
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

                      // Outcome Note (if done)
                      if (task.status == 'done') ...[
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _outcomeController,
                                  decoration: InputDecoration(
                                    hintText: l10n.outcomeNoteHint,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onChanged: (_) => _markDirty(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Notes Field
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.notesHint,
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _notesController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onChanged: (_) => _markDirty(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Voice Notes Section (Addendum v1.1)
                      VoiceNotesSection(
                        parentType: 'task',
                        parentId: task.id,
                      ),
                      const SizedBox(height: 16),

                      // History Events Log
                      Text(
                        l10n.historyLog,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  AppColors.getStatusIcon(event.toStatus),
                                  color: AppColors.getStatusColor(event.toStatus, isDark),
                                  size: 20,
                                ),
                                title: Text(
                                  '${event.fromStatus ?? "todo"} ➔ ${event.toStatus}',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                subtitle: event.reasonText != null ? Text(event.reasonText!) : null,
                                trailing: Text(
                                  AppFormatter.formatDateTime(
                                    DateTime.fromMillisecondsSinceEpoch(event.at),
                                    locale: Localizations.localeOf(context).toString(),
                                    format: numeralsFormat,
                                  ),
                                  style: theme.textTheme.bodySmall,
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
