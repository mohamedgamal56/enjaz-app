import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';

class ReasonsManagerScreen extends ConsumerStatefulWidget {
  const ReasonsManagerScreen({super.key});

  @override
  ConsumerState<ReasonsManagerScreen> createState() => _ReasonsManagerScreenState();
}

class _ReasonsManagerScreenState extends ConsumerState<ReasonsManagerScreen> {
  String _selectedCategory = 'all';

  String _getCategoryName(String cat, AppLocalizations l10n) {
    switch (cat) {
      case 'postpone':
        return l10n.categoryPostpone;
      case 'waiting':
        return l10n.categoryWaiting;
      case 'stopped':
        return l10n.categoryStopped;
      case 'partial':
        return l10n.categoryPartial;
      case 'any':
      default:
        return l10n.categoryAny;
    }
  }

  void _showAddOrEditReasonDialog([Reason? reason]) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final arController = TextEditingController(text: reason?.labelAr ?? '');
    final enController = TextEditingController(text: reason?.labelEn ?? '');
    String cat = reason?.category ?? (_selectedCategory != 'all' ? _selectedCategory : 'postpone');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              reason == null ? l10n.addReason : l10n.editReason,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: arController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.reasonLabelAr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: enController,
                    decoration: InputDecoration(
                      labelText: l10n.reasonLabelEn,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: cat,
                    decoration: InputDecoration(
                      labelText: l10n.reasonCategory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'postpone',
                        child: Text(l10n.categoryPostpone),
                      ),
                      DropdownMenuItem(
                        value: 'waiting',
                        child: Text(l10n.categoryWaiting),
                      ),
                      DropdownMenuItem(
                        value: 'stopped',
                        child: Text(l10n.categoryStopped),
                      ),
                      DropdownMenuItem(
                        value: 'partial',
                        child: Text(l10n.categoryPartial),
                      ),
                      DropdownMenuItem(
                        value: 'any',
                        child: Text(l10n.categoryAny),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          cat = val;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: arController.text.trim().isNotEmpty
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      final db = ref.read(databaseProvider);
      final labelAr = arController.text.trim();
      final labelEn = enController.text.trim().isNotEmpty
          ? enController.text.trim()
          : null;

      if (reason == null) {
        await db.insertCustomReason(
          labelAr: labelAr,
          labelEn: labelEn,
          category: cat,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reasonAddedSuccess)),
        );
      } else {
        await db.updateReasonData(
          id: reason.id,
          labelAr: labelAr,
          labelEn: labelEn,
          category: cat,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.reasonUpdatedSuccess)),
        );
      }
    }
  }

  void _archiveReason(Reason reason) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.archive),
        content: Text(l10n.archiveReasonConfirm),
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
            child: Text(l10n.archive),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.archiveReason(reason.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reasonArchivedSuccess)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);
    final db = ref.watch(databaseProvider);

    final categories = [
      'all',
      'postpone',
      'waiting',
      'stopped',
      'partial',
      'any',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reasonsManager),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addReason,
        onPressed: () => _showAddOrEditReasonDialog(),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Category selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: categories.map((catKey) {
                final isSelected = _selectedCategory == catKey;
                final label = catKey == 'all'
                    ? l10n.filterAll
                    : _getCategoryName(catKey, l10n);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _selectedCategory = catKey;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // List of reasons
          Expanded(
            child: StreamBuilder<List<Reason>>(
              stream: db.watchAllReasons(),
              builder: (context, snapshot) {
                final allReasons = snapshot.data ?? [];
                final reasons = _selectedCategory == 'all'
                    ? allReasons
                    : allReasons
                        .where((r) => r.category == _selectedCategory)
                        .toList();

                if (reasons.isEmpty) {
                  return Center(
                    child: Text(
                      isArabic
                          ? 'مفيش أسباب مسجلة في هذا التصنيف'
                          : 'No reasons in this category',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: reasons.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final r = reasons[idx];
                    final label = isArabic ? r.labelAr : (r.labelEn ?? r.labelAr);
                    final countStr = AppFormatter.formatNumber(
                      r.usageCount,
                      format: numeralsFormat,
                    );

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            r.category == 'postpone'
                                ? Icons.schedule_rounded
                                : r.category == 'waiting'
                                    ? Icons.hourglass_empty_rounded
                                    : r.category == 'stopped'
                                        ? Icons.stop_circle_outlined
                                        : Icons.info_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getCategoryName(r.category, l10n),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${l10n.usageCountLabel}: $countStr',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: l10n.editReason,
                              onPressed: () => _showAddOrEditReasonDialog(r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.archive_outlined, size: 20),
                              tooltip: l10n.archive,
                              onPressed: () => _archiveReason(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
