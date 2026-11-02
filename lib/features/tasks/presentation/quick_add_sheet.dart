import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/db/app_database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/date_formatter.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final String? initialDate; // YYYY-MM-DD
  final String initialKind; // task | errand | goal | idea

  const QuickAddSheet({
    super.key,
    this.initialDate,
    this.initialKind = 'task',
  });

  static Future<void> show(
    BuildContext context, {
    String? initialDate,
    String initialKind = 'task',
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
  final _titleFocusNode = FocusNode();

  late String _selectedKind; // 'task' | 'errand' | 'goal' | 'idea'
  String? _selectedDate; // YYYY-MM-DD or null (no date / inbox)
  String? _selectedTime; // HH:mm or null
  String _selectedPriority = 'normal'; // low | normal | high

  @override
  void initState() {
    super.initState();
    _selectedKind = widget.initialKind;
    // Default date is today unless provided
    final now = DateTime.now();
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

  Future<bool> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return false;

    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_selectedKind == 'task' || _selectedKind == 'errand') {
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
        locationText: _selectedKind == 'errand' &&
                _locationController.text.trim().isNotEmpty
            ? drift.Value(_locationController.text.trim())
            : const drift.Value.absent(),
        createdAt: now,
        updatedAt: now,
        status: const drift.Value('todo'),
        progress: const drift.Value(0),
      );

      await db.insertNewTask(companion);
    } else if (_selectedKind == 'goal') {
      await db.into(db.goals).insert(
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
      await db.into(db.ideas).insert(
            IdeasCompanion.insert(
              title: title,
              description: _notesController.text.trim().isNotEmpty
                  ? drift.Value(_notesController.text.trim())
                  : const drift.Value.absent(),
              createdAt: now,
              updatedAt: now,
            ),
          );
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

            // Title Input
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              textInputAction: TextInputAction.done,
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
              ),
            ),
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

            // Date Selection Chips (For Task, Errand, Goal)
            if (_selectedKind != 'idea') ...[
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
                      onPressed: null, // Tap handled by PopupMenuButton
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Notes / details field
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
