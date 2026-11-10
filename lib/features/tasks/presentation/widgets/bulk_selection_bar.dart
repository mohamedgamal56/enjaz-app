import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../reminders/domain/reminder_scheduler.dart';
import '../../domain/task_selection_provider.dart';

class BulkSelectionBar extends ConsumerWidget implements PreferredSizeWidget {
  final List<int> currentVisibleTaskIds;

  const BulkSelectionBar({
    super.key,
    required this.currentVisibleTaskIds,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _bulkDone(BuildContext context, WidgetRef ref, List<int> selectedIds) async {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    await db.bulkUpdateTasksStatus(selectedIds, 'done');
    final scheduler = ReminderScheduler(db: db);
    for (final id in selectedIds) {
      await scheduler.cancelAllForOwner('task', id);
    }

    ref.read(taskSelectionProvider.notifier).clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic ? 'تم إنجاز ${selectedIds.length} مهام ✅' : '${selectedIds.length} tasks marked as done ✅',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: isArabic ? 'تراجع' : 'Undo',
          onPressed: () async {
            await db.bulkUpdateTasksStatus(selectedIds, 'todo');
          },
        ),
      ),
    );
  }

  Future<void> _bulkDelete(BuildContext context, WidgetRef ref, List<int> selectedIds) async {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف المهام المحددة' : 'Delete Selected Tasks'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من نقل ${selectedIds.length} مهام إلى سلة المحذوفات؟'
              : 'Move ${selectedIds.length} selected tasks to trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.bulkSoftDeleteTasks(selectedIds);
      final scheduler = ReminderScheduler(db: db);
      for (final id in selectedIds) {
        await scheduler.cancelAllForOwner('task', id);
      }

      ref.read(taskSelectionProvider.notifier).clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم نقل ${selectedIds.length} مهام إلى السلة 🗑️'
                : 'Moved ${selectedIds.length} tasks to trash 🗑️',
          ),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: isArabic ? 'تراجع' : 'Undo',
            onPressed: () async {
              await db.bulkRestoreTasks(selectedIds);
            },
          ),
        ),
      );
    }
  }

  Future<void> _bulkMoveDate(BuildContext context, WidgetRef ref, List<int> selectedIds) async {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();

    String formatDt(DateTime dt) =>
        '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    final todayStr = formatDt(now);
    final tomorrowStr = formatDt(now.add(const Duration(days: 1)));

    final choice = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isArabic ? 'نقل المهام المحددة إلى:' : 'Move Selected Tasks To:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.today_rounded, color: Colors.teal),
                title: Text(isArabic ? 'اليوم' : 'Today'),
                onTap: () => Navigator.pop(ctx, todayStr),
              ),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined, color: Colors.amber),
                title: Text(isArabic ? 'بكرة' : 'Tomorrow'),
                onTap: () => Navigator.pop(ctx, tomorrowStr),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(isArabic ? 'اختيار تاريخ محدد...' : 'Pick Date...'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2046),
                  );
                  if (picked != null && ctx.mounted) {
                    Navigator.pop(ctx, formatDt(picked));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.inbox_outlined),
                title: Text(isArabic ? 'بدون تاريخ (صندوق الوارد)' : 'No Date (Inbox)'),
                onTap: () => Navigator.pop(ctx, 'no_date'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice != null) {
      final targetDate = choice == 'no_date' ? null : choice;
      await db.bulkMoveTasksDueDate(selectedIds, targetDate);

      ref.read(taskSelectionProvider.notifier).clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم نقل ${selectedIds.length} مهام بنجاح 📅'
                : 'Moved ${selectedIds.length} tasks successfully 📅',
          ),
        ),
      );
    }
  }

  Future<void> _bulkChangeStatus(BuildContext context, WidgetRef ref, List<int> selectedIds) async {
    final db = ref.read(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final selectedStatus = await showModalBottomSheet<String?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isArabic ? 'تغيير حالة المهام المحددة إلى:' : 'Change Status To:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                title: Text(isArabic ? 'لم تبدأ (Todo)' : 'Todo'),
                onTap: () => Navigator.pop(ctx, 'todo'),
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline, color: Colors.blue),
                title: Text(isArabic ? 'قيد التنفيذ (In Progress)' : 'In Progress'),
                onTap: () => Navigator.pop(ctx, 'in_progress'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule, color: Colors.deepPurple),
                title: Text(isArabic ? 'مؤجلة (Postponed)' : 'Postponed'),
                onTap: () => Navigator.pop(ctx, 'postponed'),
              ),
              ListTile(
                leading: const Icon(Icons.pause_circle_outline, color: Colors.amber),
                title: Text(isArabic ? 'في الانتظار (Waiting)' : 'Waiting'),
                onTap: () => Navigator.pop(ctx, 'waiting'),
              ),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: Text(isArabic ? 'ملغاة / متوقفة (Stopped)' : 'Stopped'),
                onTap: () => Navigator.pop(ctx, 'stopped'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedStatus != null) {
      await db.bulkUpdateTasksStatus(selectedIds, selectedStatus);

      ref.read(taskSelectionProvider.notifier).clear();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم تحديث حالة ${selectedIds.length} مهام بنجاح'
                : 'Updated status for ${selectedIds.length} tasks',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(taskSelectionProvider);
    final selectedCount = selectionState.selectedTaskIds.length;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final allSelected = currentVisibleTaskIds.isNotEmpty &&
        currentVisibleTaskIds.every((id) => selectionState.selectedTaskIds.contains(id));

    final selectedList = selectionState.selectedTaskIds.toList();

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: isArabic ? 'إلغاء التحديد' : 'Cancel Selection',
        onPressed: () => ref.read(taskSelectionProvider.notifier).clear(),
      ),
      title: Text(
        isArabic ? 'تم تحديد $selectedCount' : '$selectedCount selected',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        // Select All / Deselect All
        IconButton(
          icon: Icon(allSelected ? Icons.select_all_rounded : Icons.library_add_check_outlined),
          tooltip: isArabic
              ? (allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل')
              : (allSelected ? 'Deselect All' : 'Select All'),
          onPressed: () {
            if (allSelected) {
              ref.read(taskSelectionProvider.notifier).clear();
            } else {
              ref.read(taskSelectionProvider.notifier).selectAll(currentVisibleTaskIds);
            }
          },
        ),

        // Bulk Done
        IconButton(
          icon: const Icon(Icons.check_circle_outline_rounded),
          tooltip: isArabic ? 'إنجاز' : 'Mark Done',
          onPressed: () => _bulkDone(context, ref, selectedList),
        ),

        // Bulk Change Status
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: isArabic ? 'تغيير الحالة' : 'Change Status',
          onPressed: () => _bulkChangeStatus(context, ref, selectedList),
        ),

        // Bulk Move Date
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: isArabic ? 'نقل لتاريخ' : 'Move to Date',
          onPressed: () => _bulkMoveDate(context, ref, selectedList),
        ),

        // Bulk Delete
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: isArabic ? 'حذف' : 'Delete',
          onPressed: () => _bulkDelete(context, ref, selectedList),
        ),
      ],
    );
  }
}
