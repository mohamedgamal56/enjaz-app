import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import '../../voice_notes/presentation/voice_recorder_sheet.dart';

class AddNoteSheet extends ConsumerStatefulWidget {
  final Note? noteToEdit;
  final String? initialDate;
  final String? initialTitle;
  final String? initialBody;
  final String? initialKind;

  const AddNoteSheet({
    super.key,
    this.noteToEdit,
    this.initialDate,
    this.initialTitle,
    this.initialBody,
    this.initialKind,
  });

  static Future<void> show(
    BuildContext context, {
    Note? noteToEdit,
    String? initialDate,
    String? initialTitle,
    String? initialBody,
    String? initialKind,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddNoteSheet(
        noteToEdit: noteToEdit,
        initialDate: initialDate,
        initialTitle: initialTitle,
        initialBody: initialBody,
        initialKind: initialKind,
      ),
    );
  }

  @override
  ConsumerState<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<AddNoteSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagInputController = TextEditingController();

  String _kind = 'note'; // note | quote | info
  String? _selectedColor; // hex or color name
  late String _noteDate;
  bool _pinned = false;
  final List<String> _tags = [];

  VoiceRecordingResult? _recordedVoiceResult;

  static const List<String> _colorOptions = [
    '#FFFFFF', // default
    '#FFCDD2', // soft red
    '#C8E6C9', // soft green
    '#BBDEFB', // soft blue
    '#FFE082', // soft amber
    '#E1BEE7', // soft purple
    '#B2DFDB', // soft teal
  ];

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _noteDate = widget.initialDate ?? today;

    if (widget.noteToEdit != null) {
      final n = widget.noteToEdit!;
      _titleController.text = n.title ?? '';
      _bodyController.text = n.body;
      _kind = n.kind;
      _selectedColor = n.color;
      _pinned = n.pinned;
      _noteDate = n.noteDate ?? today;
      if (n.tags != null && n.tags!.trim().isNotEmpty) {
        _tags.addAll(n.tags!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
      }
    } else {
      if (widget.initialTitle != null) _titleController.text = widget.initialTitle!;
      if (widget.initialBody != null) _bodyController.text = widget.initialBody!;
      if (widget.initialKind != null) _kind = widget.initialKind!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _addTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() {
        _tags.add(text);
        _tagInputController.clear();
      });
    }
  }

  void _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_noteDate) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );

    if (picked != null) {
      setState(() {
        _noteDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _recordVoiceNote() async {
    final result = await VoiceRecorderSheet.show(context);
    if (result != null) {
      setState(() {
        _recordedVoiceResult = result;

        // Voice-only auto title
        if (_titleController.text.trim().isEmpty) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          _titleController.text = VoiceNoteService.generateVoiceOnlyTitle(
            date: DateTime.now(),
            isArabic: isAr,
          );
        }
        if (_bodyController.text.trim().isEmpty) {
          _bodyController.text = 'تسجيل صوتي مرفق بالملاحظة';
        }
      });
    }
  }

  void _saveNote() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final body = _bodyController.text.trim();
    final title = _titleController.text.trim();

    if (body.isEmpty && _recordedVoiceResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'يرجى كتابة نص الملاحظة أو تسجيل ملاحظة صوتية'
                : 'Please enter note content or record a voice note',
          ),
        ),
      );
      return;
    }

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final tagsStr = _tags.isNotEmpty ? _tags.join(',') : null;

    if (widget.noteToEdit != null) {
      // Update
      await db.updateNote(
        widget.noteToEdit!.toCompanion(true).copyWith(
              title: drift.Value(title.isNotEmpty ? title : null),
              body: drift.Value(body.isNotEmpty ? body : 'تسجيل صوتي'),
              kind: drift.Value(_kind),
              color: drift.Value(_selectedColor),
              pinned: drift.Value(_pinned),
              noteDate: drift.Value(_noteDate),
              tags: drift.Value(tagsStr),
              updatedAt: drift.Value(now),
            ),
      );
    } else {
      // Insert
      final noteId = await db.insertNote(
        NotesCompanion.insert(
          title: drift.Value(title.isNotEmpty ? title : null),
          body: body.isNotEmpty ? body : 'تسجيل صوتي',
          kind: drift.Value(_kind),
          color: drift.Value(_selectedColor),
          pinned: drift.Value(_pinned),
          noteDate: drift.Value(_noteDate),
          tags: drift.Value(tagsStr),
          occurredAt: drift.Value(now),
          localDate: drift.Value(_noteDate),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Attach voice note if recorded
      if (_recordedVoiceResult != null) {
        await db.insertVoiceNote(
          VoiceNotesCompanion.insert(
            parentType: 'note',
            parentId: noteId,
            fileName: _recordedVoiceResult!.relativeFileName,
            durationMs: drift.Value(_recordedVoiceResult!.durationMs),
            sizeBytes: drift.Value(_recordedVoiceResult!.sizeBytes),
            recordedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title & Pin row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.noteToEdit != null
                      ? (isArabic ? 'تعديل الملاحظة' : 'Edit Note')
                      : (isArabic ? 'ملاحظة جديدة' : 'New Note'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    color: _pinned ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  tooltip: isArabic ? 'تثبيت في الأعلى' : 'Pin to top',
                  onPressed: () => setState(() => _pinned = !_pinned),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kind selector chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.note_outlined, size: 16),
                    label: Text(isArabic ? 'ملاحظة' : 'Note'),
                    selected: _kind == 'note',
                    onSelected: (_) => setState(() => _kind = 'note'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.format_quote_rounded, size: 16),
                    label: Text(isArabic ? 'اقتباس أو حكمة' : 'Quote'),
                    selected: _kind == 'quote',
                    onSelected: (_) => setState(() => _kind = 'quote'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                    label: Text(isArabic ? 'معلومة' : 'Info'),
                    selected: _kind == 'info',
                    onSelected: (_) => setState(() => _kind = 'info'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date & Color row
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(_noteDate),
                  onPressed: _pickDate,
                ),
                const Spacer(),
                // Color dots
                ..._colorOptions.map((cHex) {
                  final isSelected = _selectedColor == cHex || (_selectedColor == null && cHex == '#FFFFFF');
                  final col = Color(int.parse(cHex.replaceFirst('#', '0xFF')));

                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = cHex),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
                          width: isSelected ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),

            // Title field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: isArabic ? 'العنوان (اختياري)...' : 'Title (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Body field (multi-line)
            TextField(
              controller: _bodyController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: isArabic ? 'اكتب ملاحظتك هنا بالتفصيل...' : 'Write note body here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Voice recorder attachment
            if (_recordedVoiceResult != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_rounded, color: Colors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'تسجيل صوتي مرفق (${VoiceNoteService.formatDuration(_recordedVoiceResult!.durationMs)})'
                            : 'Voice note attached (${VoiceNoteService.formatDuration(_recordedVoiceResult!.durationMs)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _recordedVoiceResult = null),
                    ),
                  ],
                ),
              )
            else
              TextButton.icon(
                icon: const Icon(Icons.mic_rounded),
                label: Text(isArabic ? 'تسجيل ملاحظة صوتية' : 'Record voice note'),
                onPressed: _recordVoiceNote,
              ),

            const SizedBox(height: 12),

            // Tags input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    onSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'إضافة وسم (#حكمة، #تطوير)' : 'Add tag (#wisdom)',
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                spacing: 6,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag'),
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 18),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  widget.noteToEdit != null
                      ? (isArabic ? 'حفظ التعديلات' : 'Save Changes')
                      : (isArabic ? 'حفظ الملاحظة' : 'Save Note'),
                ),
                onPressed: _saveNote,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
