import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/widgets.dart';
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
              ? 'هل أنت متأكد من تفريغ السلة نهائياً؟ سيتم حذف جميع العناصر والتسجيلات الصوتية والتنبيهات بشكل لا رجعة فيه.'
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
      try {
        await ReminderScheduler(db: db).rescheduleAllActive();
      } catch (_) {}
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
              ? 'هل تريد حذف "${task.title}" نهائياً؟ سيتم مسح أي تسجيلات صوتية وتنبيهات تابعة لها.'
              : 'Permanently delete "${task.title}"? Audio files and reminders will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
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
      await db.permanentlyDeleteTask(task.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف العنصر نهائياً' : 'Item permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteGoal(BuildContext context, WidgetRef ref, Goal goal) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي للهدف' : 'Delete Goal Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف هدف "${goal.title}" ومراحله وتنبيهاته نهائياً؟'
              : 'Permanently delete goal "${goal.title}" and its milestones?',
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
      await db.permanentlyDeleteGoal(goal.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الهدف نهائياً' : 'Goal permanently deleted')),
      );
    }
  }

  void _permanentlyDeleteIdea(BuildContext context, WidgetRef ref, Idea idea) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي للفكرة' : 'Delete Idea Permanently'),
        content: Text(
          isArabic
              ? 'هل تريد حذف فكرة "${idea.title}" نهائياً من الذاكرة؟'
              : 'Permanently delete idea "${idea.title}"?',
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
      await db.permanentlyDeleteIdea(idea.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الفكرة نهائياً' : 'Idea permanently deleted')),
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
              : 'Permanently delete habit "${habit.nameEn ?? habit.nameAr}"? This cannot be undone.',
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

  void _permanentlyDeleteWishlistItem(BuildContext context, WidgetRef ref, WishlistItem item) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي للأمنية' : 'Delete Wishlist Item'),
        content: Text(
          isArabic
              ? 'هل تريد حذف أمنية "${item.name}" نهائياً؟'
              : 'Permanently delete "${item.name}"?',
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
      await db.permanentlyDeleteWishlistItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الأمنية نهائياً' : 'Wishlist item deleted')),
      );
    }
  }

  void _permanentlyDeleteObligation(BuildContext context, WidgetRef ref, Obligation ob) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف نهائي للالتزام' : 'Delete Obligation'),
        content: Text(
          isArabic
              ? 'هل تريد حذف التزام "${ob.name}" وأقساطه وتنبيهاته نهائياً؟'
              : 'Permanently delete "${ob.name}" and its reminders?',
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
      await db.permanentlyDeleteObligation(ob.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'تم حذف الالتزام نهائياً' : 'Obligation deleted')),
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
              ? 'هل تريد حذف "${item.title}" وسجلاتها وتسجيلاتها الصوتية وتنبيهاتها نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
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
              ? 'هل تريد حذف علاج "${tr.name}" وتأكيداته وتنبيهاته نهائياً؟ لا يمكن التراجع عن هذا الإجراء.'
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
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'سلة المحذوفات' : l10n.trash),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: isArabic ? 'المهام والمشاوير' : 'Tasks & Errands'),
              Tab(text: isArabic ? 'الأهداف' : 'Goals'),
              Tab(text: isArabic ? 'الأفكار' : 'Ideas'),
              Tab(text: isArabic ? 'الملاحظات' : 'Notes'),
              Tab(text: isArabic ? 'العادات' : 'Habits'),
              Tab(text: isArabic ? 'المالية' : 'Finance'),
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
            // Tab 1: Tasks & Errands
            StreamBuilder<List<Task>>(
              stream: db.watchTrashTasks(),
              builder: (context, snapshot) {
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: isArabic ? 'سلة المهام فارغة' : l10n.emptyTrash,
                    subtitle: isArabic ? 'لا توجد مهام أو مشاوير محذوفة' : 'No deleted tasks or errands',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final t = tasks[idx];
                    final isErrand = t.kind == 'errand';
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
                            CircleAvatar(
                              backgroundColor: (isErrand ? Colors.orange : theme.colorScheme.primary).withValues(alpha: 0.15),
                              child: Icon(
                                isErrand ? Icons.directions_walk_rounded : Icons.task_alt_rounded,
                                size: 20,
                                color: isErrand ? Colors.orange : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isErrand ? Colors.orange : Colors.blue).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isErrand ? (isArabic ? 'مشوار' : 'Errand') : (isArabic ? 'مهمة' : 'Task'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isErrand ? Colors.orange.shade800 : Colors.blue.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
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
                                  SnackBar(content: Text(isArabic ? 'تم استرجاع المهمة بنجاح' : l10n.taskRestored)),
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

            // Tab 2: Goals
            StreamBuilder<List<Goal>>(
              stream: db.watchTrashGoals(),
              builder: (context, snapshot) {
                final goals = snapshot.data ?? [];
                if (goals.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: isArabic ? 'لا توجد أهداف محذوفة' : 'No deleted goals',
                    subtitle: isArabic ? 'الأهداف المحذوفة تظهر هنا' : 'Deleted goals appear here',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final g = goals[idx];
                    final deletedDateStr = g.deletedAt != null
                        ? AppFormatter.formatDateTime(
                            DateTime.fromMillisecondsSinceEpoch(g.deletedAt!),
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
                              backgroundColor: Color(0x229C27B0),
                              child: Icon(Icons.flag_rounded, size: 20, color: Colors.purple),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic ? 'حُذف: $deletedDateStr' : 'Deleted: $deletedDateStr',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                              tooltip: isArabic ? 'استرجاع' : l10n.restore,
                              onPressed: () async {
                                await db.restoreGoal(g.id);
                                await ReminderScheduler(db: db).rescheduleAllForOwner(
                                  'goal',
                                  g.id,
                                  title: g.title,
                                  dueDate: g.targetDate,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isArabic ? 'تم استرجاع الهدف بنجاح' : 'Goal restored')),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                              tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                              onPressed: () => _permanentlyDeleteGoal(context, ref, g),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Tab 3: Ideas
            StreamBuilder<List<Idea>>(
              stream: db.watchTrashIdeas(),
              builder: (context, snapshot) {
                final ideas = snapshot.data ?? [];
                if (ideas.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: isArabic ? 'لا توجد أفكار محذوفة' : 'No deleted ideas',
                    subtitle: isArabic ? 'الأفكار المحذوفة تظهر هنا' : 'Deleted ideas appear here',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ideas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final idea = ideas[idx];
                    final deletedDateStr = idea.deletedAt != null
                        ? AppFormatter.formatDateTime(
                            DateTime.fromMillisecondsSinceEpoch(idea.deletedAt!),
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
                              backgroundColor: Color(0x22FF9800),
                              child: Icon(Icons.lightbulb_outline_rounded, size: 20, color: Colors.amber),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    idea.title,
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
                              tooltip: isArabic ? 'استرجاع' : l10n.restore,
                              onPressed: () async {
                                await db.restoreIdea(idea.id);
                                await ReminderScheduler(db: db).rescheduleAllForOwner(
                                  'idea',
                                  idea.id,
                                  title: idea.title,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(isArabic ? 'تم استرجاع الفكرة بنجاح' : 'Idea restored')),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                              tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                              onPressed: () => _permanentlyDeleteIdea(context, ref, idea),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Tab 4: Notes
            StreamBuilder<List<Note>>(
              stream: db.watchTrashNotes(),
              builder: (context, snapshot) {
                final notes = snapshot.data ?? [];
                if (notes.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: isArabic ? 'لا توجد ملاحظات محذوفة' : 'No deleted notes',
                    subtitle: isArabic ? 'الملاحظات المحذوفة تظهر هنا' : 'Deleted notes appear here',
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
                              backgroundColor: Color(0x224CAF50),
                              child: Icon(Icons.note_alt_outlined, size: 20, color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (n.title?.isNotEmpty == true ? n.title! : n.body).trim().split('\n').first,
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
                              tooltip: isArabic ? 'استرجاع' : l10n.restore,
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

            // Tab 5: Habits
            StreamBuilder<List<Habit>>(
              stream: db.watchTrashHabits(),
              builder: (context, snapshot) {
                final habits = snapshot.data ?? [];
                if (habits.isEmpty) {
                  return _buildEmptyState(
                    context,
                    title: isArabic ? 'لا توجد عادات محذوفة' : 'No deleted habits',
                    subtitle: isArabic ? 'العادات المحذوفة تظهر هنا' : 'Deleted habits appear here',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
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
                              backgroundColor: Color(0x22009688),
                              child: Icon(Icons.repeat_rounded, size: 20, color: Colors.teal),
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
                              tooltip: isArabic ? 'استرجاع' : l10n.restore,
                              onPressed: () async {
                                await db.restoreHabit(h.id);
                                await ReminderScheduler(db: db).rescheduleAllForOwner(
                                  'habit',
                                  h.id,
                                  title: h.nameAr,
                                );
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

            // Tab 6: Finance (Expenses, Income, Wishlist, Obligations)
            StreamBuilder<List<Transaction>>(
              stream: db.watchTrashTransactions(),
              builder: (context, txSnap) {
                final txs = txSnap.data ?? [];
                return StreamBuilder<List<WishlistItem>>(
                  stream: db.watchTrashWishlistItems(),
                  builder: (context, wishSnap) {
                    final wishList = wishSnap.data ?? [];
                    return StreamBuilder<List<Obligation>>(
                      stream: db.watchTrashObligations(),
                      builder: (context, obSnap) {
                        final obligations = obSnap.data ?? [];

                        if (txs.isEmpty && wishList.isEmpty && obligations.isEmpty) {
                          return _buildEmptyState(
                            context,
                            title: isArabic ? 'سلة المالية فارغة' : 'Finance trash is empty',
                            subtitle: isArabic ? 'لا توجد معاملات أو أمنيات أو التزامات محذوفة' : 'No deleted finance records',
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (txs.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                child: Text(
                                  isArabic ? 'المعاملات المالية (مصاريف ودخل)' : 'Transactions (Expenses & Income)',
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...txs.map((tx) {
                                final isExpense = tx.kind == 'expense';
                                final amountFormatted = MoneyFormatter.formatWithCurrency(
                                  tx.amountMinor,
                                  currency: isArabic ? 'ج.م' : 'EGP',
                                  format: numeralsFormat,
                                );
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: (isExpense ? Colors.red : Colors.green).withValues(alpha: 0.15),
                                      child: Icon(
                                        isExpense ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                        size: 18,
                                        color: isExpense ? Colors.red : Colors.green,
                                      ),
                                    ),
                                    title: Text(amountFormatted, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${tx.localDate} • ${isExpense ? (isArabic ? "مصروف" : "Expense") : (isArabic ? "دخل" : "Income")}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
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
                              }),
                              const SizedBox(height: 12),
                            ],

                            if (wishList.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                child: Text(
                                  isArabic ? 'قائمة الأمنيات' : 'Wishlist Items',
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...wishList.map((item) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(0x22E91E63),
                                      child: Icon(Icons.card_giftcard_rounded, size: 18, color: Colors.pink),
                                    ),
                                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(item.note ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                          tooltip: isArabic ? 'استرجاع' : 'Restore',
                                          onPressed: () async {
                                            await db.restoreWishlistItem(item.id);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(isArabic ? 'تم استرجاع الأمنية' : 'Wishlist item restored')),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                                          tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                                          onPressed: () => _permanentlyDeleteWishlistItem(context, ref, item),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                            ],

                            if (obligations.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                                child: Text(
                                  isArabic ? 'الالتزامات والأقساط' : 'Obligations',
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...obligations.map((ob) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8.0),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Color(0x223F51B5),
                                      child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.indigo),
                                    ),
                                    title: Text(ob.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(ob.note ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                          tooltip: isArabic ? 'استرجاع' : 'Restore',
                                          onPressed: () async {
                                            await db.restoreObligation(ob.id);
                                            await ReminderScheduler(db: db).rescheduleAllForOwner(
                                              'obligation',
                                              ob.id,
                                              title: ob.name,
                                              dueDate: ob.dueDate,
                                            );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(isArabic ? 'تم استرجاع الالتزام' : 'Obligation restored')),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.delete_forever_rounded, color: theme.colorScheme.error),
                                          tooltip: isArabic ? 'حذف نهائي' : 'Delete Permanently',
                                          onPressed: () => _permanentlyDeleteObligation(context, ref, ob),
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
                );
              },
            ),

            // Tab 7: Health (Health items & Treatments)
            StreamBuilder<List<HealthItem>>(
              stream: db.watchTrashHealthItems(),
              builder: (context, healthSnap) {
                final healthItems = healthSnap.data ?? [];
                return StreamBuilder<List<Treatment>>(
                  stream: db.watchTrashTreatments(),
                  builder: (context, treatSnap) {
                    final treatments = treatSnap.data ?? [];

                    if (healthItems.isEmpty && treatments.isEmpty) {
                      return _buildEmptyState(
                        context,
                        title: isArabic ? 'سلة محذوفات الصحة فارغة' : 'Health trash is empty',
                        subtitle: isArabic ? 'لا توجد فحوصات أو علاجات محذوفة' : 'No deleted health items or treatments',
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (healthItems.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: Text(
                              isArabic ? 'الفحوصات الطبية' : 'Health Items',
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...healthItems.map((item) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0x22F44336),
                                  child: Icon(Icons.medical_services_outlined, size: 18, color: Colors.red),
                                ),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(item.placeOrDoctor ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                      tooltip: isArabic ? 'استرجاع' : 'Restore',
                                      onPressed: () async {
                                        await db.restoreHealthItem(item.id);
                                        await ReminderScheduler(db: db).rescheduleAllForOwner(
                                          'health_item',
                                          item.id,
                                          title: item.title,
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(isArabic ? 'تم استرجاع الفحص' : 'Health item restored')),
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
                          const SizedBox(height: 12),
                        ],

                        if (treatments.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: Text(
                              isArabic ? 'العلاجات والأدوية' : 'Treatments & Medicines',
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...treatments.map((tr) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Color(0x2200BCD4),
                                  child: Icon(Icons.medication_rounded, size: 18, color: Colors.cyan),
                                ),
                                title: Text(tr.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(tr.instructionsNote ?? tr.note ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.restore_rounded, color: Colors.teal),
                                      tooltip: isArabic ? 'استرجاع' : 'Restore',
                                      onPressed: () async {
                                        await db.restoreTreatment(tr.id);
                                        await ReminderScheduler(db: db).rescheduleAllForOwner(
                                          'treatment',
                                          tr.id,
                                          title: tr.name,
                                        );
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

  Widget _buildEmptyState(BuildContext context, {required String title, required String subtitle}) {
    return Center(
      child: EmptyState(
        icon: Icons.delete_outline_rounded,
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}
