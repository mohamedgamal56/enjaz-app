import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../voice_notes/presentation/widgets/voice_notes_section.dart';
import '../../reminders/domain/reminder_scheduler.dart';

class IdeaDetailsScreen extends ConsumerStatefulWidget {
  final int ideaId;

  const IdeaDetailsScreen({
    super.key,
    required this.ideaId,
  });

  @override
  ConsumerState<IdeaDetailsScreen> createState() => _IdeaDetailsScreenState();
}

class _IdeaDetailsScreenState extends ConsumerState<IdeaDetailsScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagInputController = TextEditingController();

  bool _isInit = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Widget _buildIdeaRemindersSection(BuildContext context, Idea idea) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<Reminder>>(
      stream: db.watchRemindersForOwner('idea', idea.id),
      builder: (context, snapshot) {
        final reminders = snapshot.data ?? [];

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          isArabic ? 'تذكير بالفكرة' : 'Idea Reminder',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (reminders.isEmpty)
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.alarm_add_rounded, size: 18),
                        label: Text(isArabic ? 'ذكّرني بهذه الفكرة' : 'Remind me'),
                        onPressed: () => _showAddIdeaReminderSheet(context, idea),
                      ),
                  ],
                ),
                if (reminders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...reminders.map((r) {
                    final isAlarm = r.kind == 'alarm';
                    String timeLabel = '';
                    if (r.absoluteTime != null) {
                      timeLabel = '${r.absoluteTime!.year}-${r.absoluteTime!.month.toString().padLeft(2, '0')}-${r.absoluteTime!.day.toString().padLeft(2, '0')} ${r.absoluteTime!.hour.toString().padLeft(2, '0')}:${r.absoluteTime!.minute.toString().padLeft(2, '0')}';
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAlarm ? Icons.alarm_rounded : Icons.notifications_rounded,
                            color: isAlarm ? Colors.amber : Colors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.message ?? idea.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  timeLabel,
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                            onPressed: () async {
                              await ReminderScheduler(db: db).cancelReminder(r.id);
                              await db.deleteReminder(r.id);
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddIdeaReminderSheet(BuildContext context, Idea idea) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final db = ref.read(databaseProvider);
    var kind = 'notification';
    var selectedOption = 1; // 1: tomorrow, 3: in 3 days, 7: in a week, 0: custom
    DateTime selectedDateTime = DateTime.now().add(const Duration(days: 1));
    selectedDateTime = DateTime(selectedDateTime.year, selectedDateTime.month, selectedDateTime.day, 9, 0);
    final msgController = TextEditingController(text: idea.title);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'ذكّرني بهذه الفكرة' : 'Remind Me About This Idea',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(isArabic ? 'إشعار عادي' : 'Notification'),
                      selected: kind == 'notification',
                      onSelected: (_) => setSheetState(() => kind = 'notification'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(isArabic ? 'منبه مستمر' : 'Alarm'),
                      selected: kind == 'alarm',
                      onSelected: (_) => setSheetState(() => kind = 'alarm'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(isArabic ? 'غداً (9:00 ص)' : 'Tomorrow (9 AM)'),
                      selected: selectedOption == 1,
                      onSelected: (_) => setSheetState(() {
                        selectedOption = 1;
                        final d = DateTime.now().add(const Duration(days: 1));
                        selectedDateTime = DateTime(d.year, d.month, d.day, 9, 0);
                      }),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'بعد 3 أيام' : 'In 3 days'),
                      selected: selectedOption == 3,
                      onSelected: (_) => setSheetState(() {
                        selectedOption = 3;
                        final d = DateTime.now().add(const Duration(days: 3));
                        selectedDateTime = DateTime(d.year, d.month, d.day, 9, 0);
                      }),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'بعد أسبوع' : 'In 1 week'),
                      selected: selectedOption == 7,
                      onSelected: (_) => setSheetState(() {
                        selectedOption = 7;
                        final d = DateTime.now().add(const Duration(days: 7));
                        selectedDateTime = DateTime(d.year, d.month, d.day, 9, 0);
                      }),
                    ),
                    ChoiceChip(
                      label: Text(isArabic ? 'تاريخ مخصص' : 'Custom'),
                      selected: selectedOption == 0,
                      onSelected: (_) => setSheetState(() => selectedOption = 0),
                    ),
                  ],
                ),
                if (selectedOption == 0) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded),
                    title: Text(
                      '${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')} ${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.edit_rounded, size: 18),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (pickedDate != null && context.mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                        );
                        if (pickedTime != null) {
                          setSheetState(() {
                            selectedDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: msgController,
                  decoration: InputDecoration(
                    labelText: isArabic ? 'نص التذكير' : 'Reminder note',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final now = DateTime.now().millisecondsSinceEpoch;
                      final reminderId = await db.into(db.reminders).insert(
                        RemindersCompanion.insert(
                          ownerType: 'idea',
                          ownerId: idea.id,
                          kind: drift.Value(kind),
                          triggerType: const drift.Value('absolute'),
                          absoluteTime: drift.Value(selectedDateTime),
                          message: drift.Value(msgController.text.trim().isNotEmpty ? msgController.text.trim() : idea.title),
                          enabled: const drift.Value(true),
                          createdAt: now,
                          updatedAt: now,
                        ),
                      );

                      final saved = await (db.select(db.reminders)..where((r) => r.id.equals(reminderId))).getSingle();
                      await ReminderScheduler(db: db).scheduleReminder(
                        reminder: saved,
                        title: idea.title,
                      );

                      if (context.mounted) Navigator.of(ctx).pop();
                    },
                    child: Text(isArabic ? 'حفظ التذكير' : 'Save Reminder'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _saveEdits(Idea idea) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.updateIdeaData(
      idea.toCompanion(true).copyWith(
        title: drift.Value(title),
        description: _descController.text.trim().isNotEmpty
            ? drift.Value(_descController.text.trim())
            : const drift.Value(null),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> _addTagToIdea(Idea idea, List<Tag> currentTags) async {
    final text = _tagInputController.text.trim();
    if (text.isEmpty) return;

    final db = ref.read(databaseProvider);
    final tagNames = currentTags.map((t) => t.name).toList();
    if (!tagNames.contains(text)) {
      tagNames.add(text);
      await db.syncIdeaTags(idea.id, tagNames);
    }
    _tagInputController.clear();
  }

  Future<void> _removeTagFromIdea(Idea idea, List<Tag> currentTags, String removeName) async {
    final db = ref.read(databaseProvider);
    final tagNames = currentTags.map((t) => t.name).where((n) => n != removeName).toList();
    await db.syncIdeaTags(idea.id, tagNames);
  }

  Future<void> _convertToTask(Idea idea) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Insert task
    final taskId = await db.insertNewTask(
      TasksCompanion.insert(
        title: idea.title,
        notes: idea.description != null ? drift.Value(idea.description) : const drift.Value.absent(),
        kind: const drift.Value('task'),
        priority: const drift.Value('normal'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Convert idea & move voice notes
    await db.convertIdea(
      ideaId: idea.id,
      targetType: 'task',
      targetId: taskId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ideaConvertedToTaskSuccess)),
    );
  }

  Future<void> _convertToGoal(Idea idea) async {
    final l10n = AppLocalizations.of(context);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Insert goal
    final goalId = await db.insertNewGoal(
      GoalsCompanion.insert(
        title: idea.title,
        description: idea.description != null ? drift.Value(idea.description) : const drift.Value.absent(),
        progressMode: const drift.Value('milestones'),
        status: const drift.Value('active'),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Convert idea & move voice notes
    await db.convertIdea(
      ideaId: idea.id,
      targetType: 'goal',
      targetId: goalId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.ideaConvertedToGoalSuccess)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);

    return StreamBuilder<Idea?>(
      stream: db.watchIdeaById(widget.ideaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final idea = snapshot.data!;
        if (!_isInit) {
          _titleController.text = idea.title;
          _descController.text = idea.description ?? '';
          _isInit = true;
        }

        final statuses = [
          {'key': 'new', 'label': l10n.ideasNew},
          {'key': 'exploring', 'label': l10n.ideasExploring},
          {'key': 'converted', 'label': l10n.ideasConverted},
          {'key': 'archived', 'label': l10n.ideasArchived},
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.tabIdeas),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (action) async {
                  if (action == 'archive') {
                    final next = idea.status == 'archived' ? 'new' : 'archived';
                    await db.updateIdeaStatus(idea.id, next);
                  } else if (action == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(l10n.deleteIdea),
                        content: Text(l10n.deleteIdeaConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.error,
                            ),
                            child: Text(l10n.deleteTask),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await db.softDeleteIdea(idea.id);
                      if (mounted) Navigator.of(context).pop();
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(idea.status == 'archived' ? Icons.unarchive_outlined : Icons.archive_outlined),
                        const SizedBox(width: 8),
                        Text(idea.status == 'archived' ? l10n.unarchiveIdea : l10n.archiveIdea),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text(l10n.deleteIdea, style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Segmented Selector
                SegmentedButton<String>(
                  segments: statuses.map((s) {
                    return ButtonSegment<String>(
                      value: s['key']!,
                      label: Text(s['label']!, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  selected: {idea.status},
                  onSelectionChanged: (set) async {
                    await db.updateIdeaStatus(idea.id, set.first);
                  },
                ),
                const SizedBox(height: 16),

                // Card for Title & Description
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: l10n.ideaTitle,
                            border: const UnderlineInputBorder(),
                          ),
                          onChanged: (_) => _saveEdits(idea),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.ideaDescription,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (_) => _saveEdits(idea),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tags Section
                StreamBuilder<List<Tag>>(
                  stream: db.watchTagsForIdea(idea.id),
                  builder: (context, tagSnapshot) {
                    final currentTags = tagSnapshot.data ?? [];

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.tags,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            if (currentTags.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: currentTags.map((tag) {
                                  return Chip(
                                    label: Text('#${tag.name}'),
                                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                                    onDeleted: () => _removeTagFromIdea(idea, currentTags, tag.name),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),
                            ],

                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _tagInputController,
                                    onSubmitted: (_) => _addTagToIdea(idea, currentTags),
                                    decoration: InputDecoration(
                                      hintText: l10n.tagHint,
                                      prefixIcon: const Icon(Icons.tag_rounded),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: () => _addTagToIdea(idea, currentTags),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Reminders Section (Round 3 Spec 3.3)
                _buildIdeaRemindersSection(context, idea),
                const SizedBox(height: 16),

                // Conversion Actions (Spec 6.8)
                if (idea.status != 'converted') ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.task_alt_rounded),
                          label: Text(l10n.convertToTask),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _convertToTask(idea),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.flag_rounded),
                          label: Text(l10n.convertToGoal),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _convertToGoal(idea),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          idea.convertedType == 'goal'
                              ? 'تم تحويل هذه الفكرة إلى هدف'
                              : 'تم تحويل هذه الفكرة إلى مهمة',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Voice Notes Section (Spec 14.4)
                VoiceNotesSection(
                  parentType: 'idea',
                  parentId: idea.id,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
