import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../voice_notes/presentation/widgets/voice_notes_section.dart';
import 'add_note_sheet.dart';

class NoteCard extends ConsumerWidget {
  final Note note;

  const NoteCard({
    super.key,
    required this.note,
  });

  Color _resolveCardColor(BuildContext context, String? colorHex) {
    if (colorHex == null || colorHex == '#FFFFFF') {
      return Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    }
    try {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final parsed = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      return isDark ? Color.alphaBlend(parsed.withValues(alpha: 0.25), Theme.of(context).colorScheme.surface) : parsed;
    } catch (_) {
      return Theme.of(context).colorScheme.surface;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'حذف الملاحظة' : 'Delete Note'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من نقل هذه الملاحظة إلى سلة المحذوفات؟'
              : 'Move this note to trash?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.softDeleteNote(note.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'تم نقل الملاحظة إلى السلة' : 'Note moved to trash'),
          action: SnackBarAction(
            label: isArabic ? 'تراجع' : 'Undo',
            onPressed: () async {
              await db.restoreNote(note.id);
            },
          ),
        ),
      );
    }
  }

  void _convertToTask(BuildContext context, WidgetRef ref) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    final title = (note.title != null && note.title!.isNotEmpty) ? note.title! : note.body.split('\n').first;
    final notesText = note.body;

    await db.insertNewTask(
      TasksCompanion.insert(
        title: title,
        notes: drift.Value(notesText),
        dueDate: drift.Value(note.noteDate),
        kind: const drift.Value('task'),
        priority: const drift.Value('normal'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? 'تم تحويل الملاحظة إلى مهمة بنجاح' : 'Note converted to task'),
      ),
    );
  }

  void _convertToIdea(BuildContext context, WidgetRef ref) async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.read(databaseProvider);

    final title = (note.title != null && note.title!.isNotEmpty) ? note.title! : note.body.split('\n').first;
    final descText = note.body;

    await db.insertNewIdea(
      title: title,
      description: descText,
      tagNames: note.tags != null ? note.tags!.split(',') : [],
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isArabic ? 'تم تحويل الملاحظة إلى فكرة بنجاح' : 'Note converted to idea'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.read(databaseProvider);

    final tagsList = (note.tags != null && note.tags!.trim().isNotEmpty)
        ? note.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    String kindLabel;
    IconData kindIcon;
    switch (note.kind) {
      case 'quote':
        kindLabel = isArabic ? 'اقتباس / حكمة' : 'Quote';
        kindIcon = Icons.format_quote_rounded;
        break;
      case 'info':
        kindLabel = isArabic ? 'معلومة' : 'Info';
        kindIcon = Icons.lightbulb_outline_rounded;
        break;
      default:
        kindLabel = isArabic ? 'ملاحظة' : 'Note';
        kindIcon = Icons.note_outlined;
    }

    return Card(
      color: _resolveCardColor(context, note.color),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: note.pinned ? theme.colorScheme.primary : Colors.black12,
          width: note.pinned ? 1.5 : 0.8,
        ),
      ),
      elevation: note.pinned ? 2 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges & actions row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(kindIcon, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        kindLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (note.noteDate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    note.noteDate!,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                  ),
                ],
                const Spacer(),
                if (note.pinned)
                  Icon(
                    Icons.push_pin_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      AddNoteSheet.show(context, noteToEdit: note);
                    } else if (val == 'pin') {
                      db.togglePinNote(note.id, !note.pinned);
                    } else if (val == 'to_task') {
                      _convertToTask(context, ref);
                    } else if (val == 'to_idea') {
                      _convertToIdea(context, ref);
                    } else if (val == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'تعديل' : 'Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(note.pinned ? (isArabic ? 'إلغاء التثبيت' : 'Unpin') : (isArabic ? 'تثبيت' : 'Pin')),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'to_task',
                      child: Row(
                        children: [
                          const Icon(Icons.task_alt_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'تحويل إلى مهمة' : 'Convert to Task'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'to_idea',
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'تحويل إلى فكرة' : 'Convert to Idea'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(isArabic ? 'حذف' : 'Delete', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Title (if present)
            if (note.title != null && note.title!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                note.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
            ],

            // Body
            const SizedBox(height: 6),
            Text(
              note.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),

            // Tags
            if (tagsList.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tagsList.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // Voice Notes section attached to note
            const SizedBox(height: 8),
            VoiceNotesSection(
              parentType: 'note',
              parentId: note.id,
            ),
          ],
        ),
      ),
    );
  }
}
