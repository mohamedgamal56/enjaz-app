import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';
import '../../voice_notes/domain/voice_note_service.dart';
import '../../voice_notes/presentation/voice_recorder_sheet.dart';
import '../../recurrence/domain/recurrence_service.dart';
import '../../reminders/domain/notification_service.dart';
import '../../reminders/presentation/notification_permission_sheet.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final String? initialDate; // YYYY-MM-DD
  final String initialKind; // task | errand | goal | idea
  final int? initialGoalId;

  const QuickAddSheet({
    super.key,
    this.initialDate,
    this.initialKind = 'task',
    this.initialGoalId,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialDate,
    String initialKind = 'task',
    int? initialGoalId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickAddSheet(
        initialDate: initialDate,
        initialKind: initialKind,
        initialGoalId: initialGoalId,
      ),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  final _tagInputController = TextEditingController();
  final List<String> _ideaTags = [];
  final _titleFocusNode = FocusNode();

  late String _selectedKind; // 'task' | 'errand' | 'goal' | 'idea'
  String? _selectedDate; // YYYY-MM-DD or null (no date / inbox)
  String? _selectedTime; // HH:mm or null
  String _selectedPriority = 'normal'; // low | normal | high
  VoiceRecordingResult? _recordedVoiceNote;

  int? _selectedReminderOffset;
  String _selectedRecurrenceRule = 'none'; // 'none' | 'daily' | 'weekly' | 'monthly'
  int _selectedWeekdaysBitmask = 0;
  int _selectedDayOfMonth = 1;
  String? _selectedRecurrenceEndDate;
  bool _showRecurrencePanel = false;

  void _addIdeaTag() {
    final text = _tagInputController.text.trim();
    if (text.isNotEmpty && !_ideaTags.contains(text)) {
      setState(() {
        _ideaTags.add(text);
        _tagInputController.clear();
      });
    }
  }

  Future<void> _recordVoiceNote() async {
    final result = await VoiceRecorderSheet.show(context);
    if (result != null) {
      setState(() {
        _recordedVoiceNote = result;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind;
    // Default date is today unless provided
    final now = DateTime.now();
    _selectedDayOfMonth = now.day;
    _selectedWeekdaysBitmask = 1 << now.weekday;
    _selectedDate = widget.initialDate ??
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    _tagInputController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _formatTomorrowDate() {
    final tom = DateTime.now().add(const Duration(days: 1));
    return '${tom.year.toString().padLeft(4, '0')}-${tom.month.toString().padLeft(2, '0')}-${tom.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _checkMultiLinePaste(String text) {
    if (!text.contains('\n')) return;
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length > 1) {
      _showMultiLineImportDialog(lines);
    }
  }

  void _showMultiLineImportDialog([List<String>? initialLines]) async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final pasteController = TextEditingController(
      text: initialLines != null ? initialLines.join('\n') : '',
    );

    final confirmedLines = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final lines = pasteController.text
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.playlist_add_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.multiLinePasteTitle,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lines.length > 1
                        ? (isArabic
                            ? 'تحويلها إلى ${lines.length} مهام منفصلة؟'
                            : 'Create ${lines.length} separate tasks?')
                        : l10n.pasteNotesHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pasteController,
                    maxLines: 6,
                    autofocus: initialLines == null,
                    decoration: InputDecoration(
                      hintText: l10n.pasteNotesHint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: lines.isNotEmpty
                    ? () => Navigator.of(ctx).pop(lines)
                    : null,
                child: Text(
                  isArabic
                      ? 'إنشاء ${lines.length} مهام'
                      : 'Create ${lines.length} tasks',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmedLines != null && confirmedLines.isNotEmpty) {
      final db = ref.read(databaseProvider);
      final count = await db.insertBatchTasks(
        titles: confirmedLines,
        kind: _selectedKind,
        dueDate: _selectedDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'تم إنشاء $count مهام بنجاح 🎉'
                : '$count tasks created successfully 🎉',
          ),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<bool> _saveTask() async {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    String title = _titleController.text.trim();
    if (title.isEmpty && _recordedVoiceNote != null) {
      title = VoiceNoteService.generateVoiceOnlyTitle(
        date: DateTime.now(),
        isArabic: isArabic,
      );
    }
    if (title.isEmpty) return false;

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    int? insertedId;
    String parentType = 'task';

    if (_selectedKind == 'task' || _selectedKind == 'errand') {
      parentType = 'task';

      if (_selectedRecurrenceRule != 'none') {
        final recCompanion = RecurrencesCompanion.insert(
          rule: _selectedRecurrenceRule,
          weekdays: drift.Value(_selectedWeekdaysBitmask),
          dayOfMonth: _selectedRecurrenceRule == 'monthly'
              ? drift.Value(_selectedDayOfMonth)
              : const drift.Value.absent(),
          startsOn: _selectedDate ?? _formatTodayDate(),
          endsOn: _selectedRecurrenceEndDate != null
              ? drift.Value(_selectedRecurrenceEndDate)
              : const drift.Value.absent(),
          title: title,
          kind: _selectedKind,
          dueTime: _selectedTime != null
              ? drift.Value(_selectedTime)
              : const drift.Value.absent(),
          notes: _notesController.text.trim().isNotEmpty
              ? drift.Value(_notesController.text.trim())
              : const drift.Value.absent(),
          priority: drift.Value(_selectedPriority),
          reminderOffsetMinutes: _selectedReminderOffset != null
              ? drift.Value(_selectedReminderOffset)
              : const drift.Value.absent(),
          createdAt: now,
          updatedAt: now,
        );

        final recId = await db.insertRecurrence(recCompanion);
        await RecurrenceService.generateAllUpcomingInstances(db);
        await NotificationService().rescheduleAll(db);
        insertedId = recId;
      } else {
        final companion = TasksCompanion.insert(
        title: title,
        notes: _notesController.text.trim().isNotEmpty
            ? drift.Value(_notesController.text.trim())
            : const drift.Value.absent(),
        kind: drift.Value(_selectedKind),
        priority: drift.Value(_selectedPriority),
        dueDate: _selectedDate != null
            ? drift.Value(_selectedDate)
            : const drift.Value.absent(),
        dueTime: _selectedTime != null
            ? drift.Value(_selectedTime)
            : const drift.Value.absent(),
        reminderOffsetMinutes: _selectedReminderOffset != null
            ? drift.Value(_selectedReminderOffset)
            : const drift.Value.absent(),
        locationText: _selectedKind == 'errand' &&
                _locationController.text.trim().isNotEmpty
            ? drift.Value(_locationController.text.trim())
            : const drift.Value.absent(),
        goalId: widget.initialGoalId != null
            ? drift.Value(widget.initialGoalId)
            : const drift.Value.absent(),
        createdAt: now,
        updatedAt: now,
        status: const drift.Value('todo'),
        progress: const drift.Value(0),
      );

      insertedId = await db.insertNewTask(companion);

        if (_selectedReminderOffset != null) {
          final task = await (db.select(db.tasks)..where((t) => t.id.equals(insertedId!))).getSingleOrNull();
          if (task != null) {
            await NotificationService().scheduleTaskReminder(task: task);
          }
        }
      }
    } else if (_selectedKind == 'goal') {
      parentType = 'goal';
      insertedId = await db.into(db.goals).insert(
            GoalsCompanion.insert(
              title: title,
              description: _notesController.text.trim().isNotEmpty
                  ? drift.Value(_notesController.text.trim())
                  : const drift.Value.absent(),
              targetDate: _selectedDate != null
                  ? drift.Value(_selectedDate)
                  : const drift.Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else if (_selectedKind == 'idea') {
      parentType = 'idea';
      insertedId = await db.insertNewIdea(
        title: title,
        description: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        tagNames: _ideaTags,
      );
    }

    if (_recordedVoiceNote != null && insertedId != null) {
      await db.insertVoiceNote(
        VoiceNotesCompanion.insert(
          parentType: parentType,
          parentId: insertedId,
          fileName: _recordedVoiceNote!.relativeFileName,
          durationMs: drift.Value(_recordedVoiceNote!.durationMs),
          sizeBytes: drift.Value(_recordedVoiceNote!.sizeBytes),
          recordedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      _recordedVoiceNote = null;
    }

    return true;
  }

  void _onSave({bool addAnother = false}) async {
    final success = await _saveTask();
    if (!mounted) return;

    if (success) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.taskAddedSuccess),
          duration: const Duration(seconds: 2),
        ),
      );

      if (addAnother) {
        setState(() {
          _titleController.clear();
          _notesController.clear();
          _locationController.clear();
          _selectedTime = null;
        });
        _titleFocusNode.requestFocus();
      } else {
        Navigator.of(context).pop();
      }
    }
  }


  Widget _buildWeekdayChip(int weekday, String label) {
    final isSelected = RecurrenceService.isWeekdaySelected(_selectedWeekdaysBitmask, weekday);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedWeekdaysBitmask = RecurrenceService.setWeekday(
            _selectedWeekdaysBitmask,
            weekday,
            val,
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final numeralsFormat = ref.watch(numeralsProvider);

    final todayStr = _formatTodayDate();
    final tomorrowStr = _formatTomorrowDate();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row: Segmented Control for Kind (Task, Errand, Goal, Idea)
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'task',
                  label: Text(l10n.task),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                ),
                ButtonSegment(
                  value: 'errand',
                  label: Text(l10n.errand),
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 'goal',
                  label: Text(l10n.goal),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 'idea',
                  label: Text(l10n.idea),
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                ),
              ],
              selected: {_selectedKind},
              onSelectionChanged: (val) {
                setState(() {
                  _selectedKind = val.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Title Input with multi-line paste & import action
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              textInputAction: TextInputAction.done,
              onChanged: _checkMultiLinePaste,
              onSubmitted: (_) => _onSave(addAnother: false),
              decoration: InputDecoration(
                hintText: _selectedKind == 'errand'
                    ? (isArabic ? 'اسم المشوار...' : 'Errand name...')
                    : _selectedKind == 'goal'
                        ? (isArabic ? 'عنوان الهدف...' : 'Goal title...')
                        : _selectedKind == 'idea'
                            ? (isArabic ? 'عنوان الفكرة...' : 'Idea title...')
                            : l10n.taskTitleHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  _selectedKind == 'errand'
                      ? Icons.directions_walk_rounded
                      : _selectedKind == 'goal'
                          ? Icons.flag_rounded
                          : _selectedKind == 'idea'
                              ? Icons.lightbulb_rounded
                              : Icons.task_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _recordedVoiceNote != null ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _recordedVoiceNote != null ? Colors.red : theme.colorScheme.primary,
                      ),
                      tooltip: l10n.addVoiceNote,
                      onPressed: _recordVoiceNote,
                    ),
                    if (_selectedKind == 'task' || _selectedKind == 'errand')
                      IconButton(
                        icon: const Icon(Icons.playlist_add_rounded),
                        tooltip: l10n.importNotes,
                        onPressed: () => _showMultiLineImportDialog(),
                      ),
                  ],
                ),
              ),
            ),
            if (_recordedVoiceNote != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.audiotrack_rounded, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.voiceNotes} (${VoiceNoteService.formatDuration(_recordedVoiceNote!.durationMs)})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() => _recordedVoiceNote = null);
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Errand Location Input (Visible only for Errand)
            if (_selectedKind == 'errand') ...[
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: l10n.locationHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Form for Goal (Section 0.6)
            if (_selectedKind == 'goal') ...[
              // Goal Description Input
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isArabic ? 'وصف الهدف (اختياري)...' : 'Goal description (optional)...',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),

              // Target Date Selector for Goal
              Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.flag_outlined, size: 16),
                    label: Text(
                      _selectedDate != null
                          ? (isArabic
                              ? 'تاريخ الهدف: ${AppFormatter.formatDate(DateTime.parse(_selectedDate!), locale: Localizations.localeOf(context).toString(), format: numeralsFormat)}'
                              : 'Target: ${AppFormatter.formatDate(DateTime.parse(_selectedDate!), locale: Localizations.localeOf(context).toString(), format: numeralsFormat)}')
                          : (isArabic ? 'تحديد تاريخ مستهدف (اختياري)' : 'Target date (optional)'),
                    ),
                    onPressed: _pickCustomDate,
                  ),
                  if (_selectedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      tooltip: isArabic ? 'إزالة التاريخ' : 'Clear date',
                      onPressed: () => setState(() => _selectedDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Form for Idea (Section 0.6)
            if (_selectedKind == 'idea') ...[
              // Idea Details Input
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: isArabic ? 'تفاصيل الفكرة (اختياري)...' : 'Idea details (optional)...',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),

              // Tags Input Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagInputController,
                      onSubmitted: (_) => _addIdeaTag(),
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
                    onPressed: _addIdeaTag,
                  ),
                ],
              ),
              if (_ideaTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _ideaTags.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final tag = entry.value;
                    return Chip(
                      label: Text('#$tag'),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () {
                        setState(() => _ideaTags.removeAt(idx));
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Form for Task & Errand (Section 0.6)
            if (_selectedKind == 'task' || _selectedKind == 'errand') ...[
              // Date Selection Chips
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(l10n.dateToday),
                    selected: _selectedDate == todayStr,
                    onSelected: (sel) {
                      setState(() {
                        _selectedDate = sel ? todayStr : null;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: Text(l10n.dateTomorrow),
                    selected: _selectedDate == tomorrowStr,
                    onSelected: (sel) {
                      setState(() {
                        _selectedDate = sel ? tomorrowStr : null;
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_rounded, size: 14),
                    label: Text(
                      _selectedDate != null &&
                              _selectedDate != todayStr &&
                              _selectedDate != tomorrowStr
                          ? AppFormatter.formatDate(
                              DateTime.parse(_selectedDate!),
                              locale: Localizations.localeOf(context).toString(),
                              format: numeralsFormat,
                            )
                          : l10n.datePick,
                    ),
                    onPressed: _pickCustomDate,
                  ),
                  ChoiceChip(
                    label: Text(l10n.dateNoDate),
                    selected: _selectedDate == null,
                    onSelected: (sel) {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time and Priority row
              Row(
                children: [
                  // Time Picker Button
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        _selectedTime ?? l10n.timeOptional,
                        style: theme.textTheme.bodyMedium,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _pickTime,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Priority Menu
                  PopupMenuButton<String>(
                    initialValue: _selectedPriority,
                    onSelected: (val) {
                      setState(() {
                        _selectedPriority = val;
                      });
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'low',
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.blueGrey, size: 12),
                            const SizedBox(width: 8),
                            Text(l10n.priorityLow),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'normal',
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.grey, size: 12),
                            const SizedBox(width: 8),
                            Text(l10n.priorityNormal),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'high',
                        child: Row(
                          children: [
                            const Icon(Icons.circle, color: Colors.redAccent, size: 12),
                            const SizedBox(width: 8),
                            Text(l10n.priorityHigh),
                          ],
                        ),
                      ),
                    ],
                    child: OutlinedButton.icon(
                      icon: Icon(
                        Icons.circle,
                        size: 10,
                        color: _selectedPriority == 'high'
                            ? Colors.redAccent
                            : _selectedPriority == 'low'
                                ? Colors.blueGrey
                                : theme.colorScheme.outline,
                      ),
                      label: Text(
                        _selectedPriority == 'high'
                            ? l10n.priorityHigh
                            : _selectedPriority == 'low'
                                ? l10n.priorityLow
                                : l10n.priorityNormal,
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onPressed: null, // Handled by PopupMenuButton
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Reminder Selector
                  Expanded(
                    child: PopupMenuButton<int?>(
                      initialValue: _selectedReminderOffset,
                      onSelected: (val) async {
                        if (val != null) {
                          await NotificationPermissionSheet.show(context);
                        }
                        setState(() {
                          _selectedReminderOffset = val;
                        });
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: null,
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_off_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.noReminder),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 0,
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_active_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.reminderAtDueTime),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 10,
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.reminder10MinBefore),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 30,
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.reminder30MinBefore),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 60,
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_bottom_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.reminder1HourBefore),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 1440,
                          child: Row(
                            children: [
                              const Icon(Icons.today_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.reminder1DayBefore),
                            ],
                          ),
                        ),
                      ],
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _selectedReminderOffset != null
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_outlined,
                          size: 18,
                          color: _selectedReminderOffset != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        label: Text(
                          _selectedReminderOffset == null
                              ? l10n.noReminder
                              : _selectedReminderOffset == 0
                                  ? l10n.reminderAtDueTime
                                  : _selectedReminderOffset == 10
                                      ? l10n.reminder10MinBefore
                                      : _selectedReminderOffset == 30
                                          ? l10n.reminder30MinBefore
                                          : _selectedReminderOffset == 60
                                              ? l10n.reminder1HourBefore
                                              : l10n.reminder1DayBefore,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _selectedReminderOffset != null
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onPressed: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Recurrence Toggle Button
                  OutlinedButton.icon(
                    icon: Icon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: _selectedRecurrenceRule != 'none'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _selectedRecurrenceRule == 'none'
                          ? l10n.recurrenceNone
                          : _selectedRecurrenceRule == 'daily'
                              ? l10n.recurrenceDaily
                              : _selectedRecurrenceRule == 'weekly'
                                  ? l10n.recurrenceWeekly
                                  : l10n.recurrenceMonthly,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _selectedRecurrenceRule != 'none'
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: _selectedRecurrenceRule != 'none'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: () {
                      setState(() {
                        _showRecurrencePanel = !_showRecurrencePanel;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recurrence Options Expandable Panel
              if (_showRecurrencePanel) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.recurrence,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(l10n.recurrenceNone),
                            selected: _selectedRecurrenceRule == 'none',
                            onSelected: (_) => setState(() => _selectedRecurrenceRule = 'none'),
                          ),
                          ChoiceChip(
                            label: Text(l10n.recurrenceDaily),
                            selected: _selectedRecurrenceRule == 'daily',
                            onSelected: (_) => setState(() => _selectedRecurrenceRule = 'daily'),
                          ),
                          ChoiceChip(
                            label: Text(l10n.recurrenceWeekly),
                            selected: _selectedRecurrenceRule == 'weekly',
                            onSelected: (_) => setState(() => _selectedRecurrenceRule = 'weekly'),
                          ),
                          ChoiceChip(
                            label: Text(l10n.recurrenceMonthly),
                            selected: _selectedRecurrenceRule == 'monthly',
                            onSelected: (_) => setState(() => _selectedRecurrenceRule = 'monthly'),
                          ),
                        ],
                      ),

                      // Weekly Days Selector
                      if (_selectedRecurrenceRule == 'weekly') ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.repeatOnDays,
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildWeekdayChip(DateTime.saturday, isArabic ? 'سبت' : 'Sat'),
                            _buildWeekdayChip(DateTime.sunday, isArabic ? 'أحد' : 'Sun'),
                            _buildWeekdayChip(DateTime.monday, isArabic ? 'إثنين' : 'Mon'),
                            _buildWeekdayChip(DateTime.tuesday, isArabic ? 'ثلاثاء' : 'Tue'),
                            _buildWeekdayChip(DateTime.wednesday, isArabic ? 'أربعاء' : 'Wed'),
                            _buildWeekdayChip(DateTime.thursday, isArabic ? 'خميس' : 'Thu'),
                            _buildWeekdayChip(DateTime.friday, isArabic ? 'جمعة' : 'Fri'),
                          ],
                        ),
                      ],

                      // Monthly Day Selector
                      if (_selectedRecurrenceRule == 'monthly') ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              ': ',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            DropdownButton<int>(
                              value: _selectedDayOfMonth,
                              items: List.generate(31, (i) => i + 1)
                                  .map((d) => DropdownMenuItem(value: d, child: Text('')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDayOfMonth = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ],

                      // Recurrence End Date
                      if (_selectedRecurrenceRule != 'none') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.event_busy_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              ': ',
                              style: theme.textTheme.bodySmall,
                            ),
                            TextButton(
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: now.add(const Duration(days: 30)),
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 3650)),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedRecurrenceEndDate =
                                        '--';
                                  });
                                }
                              },
                              child: Text(
                                _selectedRecurrenceEndDate ?? l10n.recurrenceEndsNever,
                                style: TextStyle(
                                  color: _selectedRecurrenceEndDate != null
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: _selectedRecurrenceEndDate != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_selectedRecurrenceEndDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => setState(() => _selectedRecurrenceEndDate = null),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],

            // Notes field (For Task & Errand only)
            if (_selectedKind == 'task' || _selectedKind == 'errand') ...[
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.notesHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Action Buttons: Save & Save and Add Another
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _onSave(addAnother: true),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(
                      l10n.saveAndAddAnother,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _onSave(addAnother: false),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(l10n.save),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
