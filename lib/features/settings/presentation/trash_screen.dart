import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../reminders/domain/reminder_scheduler.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  void _purgeTrash(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'تفريغ سلة المحذوفات' : l10n.purgeTrash),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من تفريغ السلة نهائياً؟ سيتم حذف جميع العناصر والتسجيلات الصوتية بشكل لا رجعة فيه.'
              : l10n.purgeTrashConfirm,
        ),
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
            child: Text(isArabic ? 'تفريغ السلة نهائياً' : l10n.purgeTrash),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      final stats = await db.purgeTrashDetailed();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم تفريغ السلة بنجاح: تم حذف ${stats.$1} عنصر (${stats.$2} ملف صوتي)'
                : '${l10n.trashPurgedSuccess}: ${stats.$1} items (${stats.$2} audio files)',
          ),
        ),
      );
    }
  }

  void _permanentlyDeleteTask(BuildContext context, WidgetRef ref, Task task) async {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف "${task.title}" نهائياً من الذاكرة؟ سيتم مسح أي تسجيلات صوتية تابعة لها ولن تتمكن من استرجاعها.'
              : 'Permanently delete "${task.title}"? Audio files will be removed and this cannot be undone.',
        ),
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
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteTask(task.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تم حذف العنصر نهائياً من الذاكرة' : 'Item permanently deleted',
          ),
        ),
      );
    }
  }

  void _permanentlyDeleteNote(BuildContext context, WidgetRef ref, Note note) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف هذه الملاحظة نهائياً من الذاكرة؟ سيتم مسح أي تسجيلات صوتية تابعة لها.'
              : 'Permanently delete this note? Audio files will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteNote(note.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الملاحظة نهائياً' : 'Note permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteHabit(BuildContext context, WidgetRef ref, Habit habit) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف عادة "${habit.nameAr}" وسجلاتها وتنبيهاتها نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'Permanently delete habit "${habit.nameEn ?? habit.nameAr}" and all its logs? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteHabit(habit.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف العادة نهائياً' : 'Habit permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteTransaction(BuildContext context, WidgetRef ref, Transaction tx) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف هذه المعاملة نهائياً من الذاكرة؟'
              : 'Permanently delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteTransaction(tx.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف المعاملة نهائياً' : 'Transaction permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteHealthItem(BuildContext context, WidgetRef ref, HealthItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف "${item.title}" وسجلاتها وتسجيلاتها الصوتية نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'Permanently delete "${item.title}" and all its records? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteHealthItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الفحص نهائياً' : 'Health item permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteTreatment(BuildContext context, WidgetRef ref, Treatment tr) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف علاج "${tr.name}" وتأكيداته نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
              : 'Permanently delete treatment "${tr.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text(isArabic ? 'حذف نهائي' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.permanentlyDeleteTreatment(tr.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف العلاج نهائياً' : 'Treatment permanently deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'سلة المحذوفات' : l10n.trash),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: isArabic ? 'المهام' : 'Tasks'),
              Tab(text: isArabic ? 'الملاحظات' : 'Notes'),
              Tab(text: isArabic ? 'العادات' : 'Habits'),
              Tab(text: isArabic ? 'المال' : 'Finance'),
              Tab(text: isArabic ? 'الصحة' : 'Health'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded),
              tooltip: isArabic ? 'تفريغ السلة' : l10n.purgeTrash,
              onPressed: () => _purgeTrash(context, ref),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            StreamBuilder<List<Task>>(
        stream: db.watchTrashTasks(),
        builder: (context, snapshot) {
          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'سلة المحذوفات فارغة' : l10n.emptyTrash,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabic
                        ? 'تُحذف العناصر من السلة تلقائياً بعد 30 يوماً'
                        : 'Items are automatically purged after 30 days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final t = tasks[idx];
              final deletedDateStr = t.deletedAt != null
                  ? AppFormatter.formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(t.deletedAt!),
                      locale: Localizations.localeOf(context).toString(),
                      format: numeralsFormat,
                    )
                  : '';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.delete_outline_rounded, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic ? 'حُذفت: $deletedDateStr' : 'Deleted: $deletedDateStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Actions: Restore & Permanent Delete
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                        tooltip: isArabic ? 'استرجاع' : l10n.restore,
                        onPressed: () async {
                          await db.restoreTask(t.id);
                          await ReminderScheduler(db: db).rescheduleAllForOwner(
                            'task',
                            t.id,
                            title: t.title,
                            dueDate: t.dueDate,
                            dueTime: t.dueTime,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isArabic ? 'تم استرجاع المهمة بنجاح' : l10n.taskRestored,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                        tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                        onPressed: () => _permanentlyDeleteTask(context, ref, t),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Tab 2: Notes in Trash
      StreamBuilder<List<Note>>(
        stream: db.watchTrashNotes(),
        builder: (context, snapshot) {
          final notes = snapshot.data ?? [];
          if (notes.isEmpty) {
            return Center(
              child: Text(
                isArabic ? 'لا توجد ملاحظات محذوفة' : 'No deleted notes',
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final n = notes[idx];
              final deletedDateStr = n.deletedAt != null
                  ? AppFormatter.formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(n.deletedAt!),
                      locale: Localizations.localeOf(context).toString(),
                      format: numeralsFormat,
                    )
                  : '';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.description_outlined, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (n.title != null && n.title!.isNotEmpty) ? n.title! : n.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic ? 'حُذفت: $deletedDateStr' : 'Deleted: $deletedDateStr',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                        tooltip: isArabic ? 'استرجاع' : 'Restore',
                        onPressed: () async {
                          await db.restoreNote(n.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isArabic ? 'تم استرجاع الملاحظة' : 'Note restored')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                        tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                        onPressed: () => _permanentlyDeleteNote(context, ref, n),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // 3. Habits Trash
      StreamBuilder<List<Habit>>(
        stream: db.watchTrashHabits(),
        builder: (context, snapshot) {
          final habits = snapshot.data ?? [];

          if (habits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.repeat_rounded,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'سلة العادات فارغة' : 'Habits trash is empty',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: habits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final h = habits[idx];
              final deletedDateStr = h.deletedAt != null
                  ? AppFormatter.formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(h.deletedAt!),
                      locale: Localizations.localeOf(context).toString(),
                      format: numeralsFormat,
                    )
                  : '';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.repeat_rounded, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? h.nameAr : (h.nameEn ?? h.nameAr),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArabic ? 'حُذفت: $deletedDateStr' : 'Deleted: $deletedDateStr',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                        tooltip: isArabic ? 'استرجاع' : 'Restore',
                        onPressed: () async {
                          await db.restoreHabit(h.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isArabic ? 'تم استرجاع العادة' : 'Habit restored')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                        tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                        onPressed: () => _permanentlyDeleteHabit(context, ref, h),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Tab 4: Finance (Transactions)
      StreamBuilder<List<Transaction>>(
        stream: db.watchTrashTransactions(),
        builder: (context, snapshot) {
          final txs = snapshot.data ?? [];

          if (txs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? 'سلة المحذوفات فارغة' : l10n.emptyTrash,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isArabic ? 'لا توجد معاملات مالية محذوفة' : 'No deleted transactions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final tx = txs[index];
              final deletedDate = tx.deletedAt != null
                  ? DateTime.fromMillisecondsSinceEpoch(tx.deletedAt!)
                  : DateTime.now();
              final deletedDateStr = AppFormatter.formatDate(
                deletedDate,
                locale: Localizations.localeOf(context).languageCode,
                format: numeralsFormat,
              );
              final isExpense = tx.kind == 'expense';
              final amountFormatted = MoneyFormatter.formatWithCurrency(
                tx.amountMinor,
                currency: isArabic ? 'ج.م' : 'EGP',
                format: numeralsFormat,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: (isExpense ? Colors.red : Colors.green).withValues(alpha: 0.15),
                        child: Icon(
                          isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 18,
                          color: isExpense ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              amountFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tx.localDate} • ${isArabic ? 'حُذفت:' : 'Deleted:'} $deletedDateStr',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                        tooltip: isArabic ? 'استرجاع' : 'Restore',
                        onPressed: () async {
                          await db.restoreTransaction(tx.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(isArabic ? 'تم استرجاع المعاملة' : 'Transaction restored')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                        tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                        onPressed: () => _permanentlyDeleteTransaction(context, ref, tx),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // 5. Health Tab
      StreamBuilder<List<HealthItem>>(
        stream: db.watchTrashHealthItems(),
        builder: (context, healthSnap) {
          final healthItems = healthSnap.data ?? [];

          return StreamBuilder<List<Treatment>>(
            stream: db.watchTrashTreatments(),
            builder: (context, treatSnap) {
              final treatments = treatSnap.data ?? [];

              if (healthItems.isEmpty && treatments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        isArabic ? 'سلة محذوفات الصحة فارغة' : 'Health trash is empty',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                children: [
                  if (healthItems.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                      child: Text(
                        isArabic ? 'الفحوصات والكشوفات المحذوفة' : 'Deleted Checkups & Tests',
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...healthItems.map((item) {
                      final deletedDateStr = item.deletedAt != null
                          ? AppFormatter.formatDate(
                              DateTime.fromMillisecondsSinceEpoch(item.deletedAt!),
                              locale: Localizations.localeOf(context).toString(),
                              format: numeralsFormat,
                            )
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                                child: const Icon(Icons.medical_services_outlined, size: 18, color: Colors.redAccent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isArabic ? 'حُذف:' : 'Deleted:'} $deletedDateStr',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                tooltip: isArabic ? 'استرجاع' : 'Restore',
                                onPressed: () async {
                                  await db.restoreHealthItem(item.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isArabic ? 'تم استرجاع الفحص' : 'Item restored')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                                tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                                onPressed: () => _permanentlyDeleteHealthItem(context, ref, item),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (treatments.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
                      child: Text(
                        isArabic ? 'العلاجات المحذوفة' : 'Deleted Treatments',
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...treatments.map((tr) {
                      final deletedDateStr = tr.deletedAt != null
                          ? AppFormatter.formatDate(
                              DateTime.fromMillisecondsSinceEpoch(tr.deletedAt!),
                              locale: Localizations.localeOf(context).toString(),
                              format: numeralsFormat,
                            )
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.purple.withValues(alpha: 0.15),
                                child: const Icon(Icons.medication_outlined, size: 18, color: Colors.purple),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tr.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isArabic ? 'حُذف:' : 'Deleted:'} $deletedDateStr',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                tooltip: isArabic ? 'استرجاع' : 'Restore',
                                onPressed: () async {
                                  await db.restoreTreatment(tr.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isArabic ? 'تم استرجاع العلاج' : 'Treatment restored')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                                tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                                onPressed: () => _permanentlyDeleteTreatment(context, ref, tr),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
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
