import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  void _purgeTrash(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purgeTrash),
        content: Text(l10n.purgeTrashConfirm),
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
            child: Text(l10n.purgeTrash),
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
            '${l10n.trashPurgedSuccess}: ${stats.$1} items (${stats.$2} audio files)',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trash),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            tooltip: l10n.purgeTrash,
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
                    l10n.emptyTrash,
                    style: theme.textTheme.titleMedium?.copyWith(
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
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    deletedDateStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(l10n.restore),
                    onPressed: () async {
                      await db.restoreTask(t.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.taskRestored)),
                      );
                    },
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
