import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'سلة المحذوفات' : l10n.trash),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: isArabic ? 'تفريغ السلة' : l10n.purgeTrash,
            onPressed: () => _purgeTrash(context, ref),
          ),
        ],
      ),
      body: StreamBuilder<List<Task>>(
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
    );
  }
}
