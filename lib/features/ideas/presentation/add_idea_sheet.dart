import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import '../../voice_notes/presentation/voice_recorder_sheet.dart';

class AddIdeaSheet extends ConsumerStatefulWidget {
  final bool startWithRecorder;
  final String? initialTitle;
  final String? initialDescription;

  const AddIdeaSheet({
    super.key,
    this.startWithRecorder = false,
    this.initialTitle,
    this.initialDescription,
  });

  static Future<int?> show(
    BuildContext context, {
    bool startWithRecorder = false,
    String? initialTitle,
    String? initialDescription,
  }) {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddIdeaSheet(
        startWithRecorder: startWithRecorder,
        initialTitle: initialTitle,
        initialDescription: initialDescription,
      ),
    );
  }

  @override
  ConsumerState<AddIdeaSheet> createState() => _AddIdeaSheetState();
}

class _AddIdeaSheetState extends ConsumerState<AddIdeaSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  final _titleFocusNode = FocusNode();

  final List<String> _tags = [];
  VoiceRecordingResult? _recordedVoiceNote;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDescription != null) {
      _descController.text = widget.initialDescription!;
    }
    if (widget.startWithRecorder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordVoiceNote();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _recordVoiceNote() async {
    final result = await VoiceRecorderSheet.show(context);
    if (result != null) {
      setState(() {
        _recordedVoiceNote = result;
      });
    }
  }

  void _addTag() {
    final text = _tagsController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagsController.clear();
      });
    }
  }

  Future<void> _saveIdea() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String title = _titleController.text.trim();

    // Voice-only capture (Spec 14.3): If title is empty but voice note exists, auto-generate title
    if (title.isEmpty && _recordedVoiceNote != null) {
      title = VoiceNoteService.generateVoiceOnlyTitle(
        date: DateTime.now(),
        isArabic: isArabic,
      );
    }

    if (title.isEmpty) return;

    final db = ref.read(databaseProvider);
    final desc = _descController.text.trim();

    // 1. Insert idea & sync tags
    final ideaId = await db.insertNewIdea(
      title: title,
      description: desc.isNotEmpty ? desc : null,
      tagNames: _tags,
    );

    // 2. Attach recorded voice note if any
    if (_recordedVoiceNote != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insertVoiceNote(
        VoiceNotesCompanion.insert(
          parentType: 'idea',
          parentId: ideaId,
          fileName: _recordedVoiceNote!.relativeFileName,
          durationMs: drift.Value(_recordedVoiceNote!.durationMs),
          sizeBytes: drift.Value(_recordedVoiceNote!.sizeBytes),
          recordedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(ideaId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomInset,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n.addIdea,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title Input with Voice Note Button beside it (Spec 14.4)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    decoration: InputDecoration(
                      hintText: l10n.ideaTitle,
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: Icon(
                    _recordedVoiceNote != null ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _recordedVoiceNote != null ? Colors.red : theme.colorScheme.primary,
                  ),
                  tooltip: l10n.addVoiceNote,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(50, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _recordVoiceNote,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recorded voice note preview chip if recorded
            if (_recordedVoiceNote != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.voiceNotes} (${VoiceNoteService.formatDuration(_recordedVoiceNote!.durationMs)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _recordedVoiceNote = null);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description Input
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.ideaDescription,
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 14),

            // Tags Input Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagsController,
                    onSubmitted: (_) => _addTag(),
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
                  onPressed: _addTag,
                ),
              ],
            ),

            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _tags.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tag = entry.value;
                  return Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () {
                      setState(() => _tags.removeAt(idx));
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.save),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saveIdea,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
