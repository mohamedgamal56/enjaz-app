import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../voice_notes/presentation/widgets/voice_notes_section.dart';

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
