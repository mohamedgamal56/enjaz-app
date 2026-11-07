import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../finance/presentation/add_transaction_sheet.dart';
import '../../ideas/presentation/add_idea_sheet.dart';
import '../../notes/presentation/add_note_sheet.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../action_executor.dart';
import '../action_plan.dart';
import '../action_planner.dart';
import '../rule_based_intent_parser.dart';
import 'widgets/confirmation_card.dart';

/// Modal bottom sheet for the Voice Assistant (VOICE.md Section 2.2 & Step 3).
/// In Step 3, provides typed input, suggestion chips, confirmation card preview,
/// direct execution into Drift database tables, and the Undo snackbar.
class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AssistantSheet(),
    );
  }

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  ActionPlan? _currentPlan;
  bool _isProcessing = false;
  String? _statusFeedback;

  static const List<String> _suggestedPhrases = [
    'أنا بكرة عايز أعمل مونتاج الإعلان الساعة 4 العصر',
    'سجل مشوار النهارده أروح السنترال الساعة 1',
    'فكرني يوم الخميس أكلم دكتور أحمد الساعة 7 بالليل',
    'صرفت 100 جنيه بنزين للموتوسيكل النهارده',
    'سجل شاي وقهوة بـ 25 جنيه',
    'خلصت مهمة تسليم الفيديوهات',
    'أجل مهمة مراجعة الحسابات لبكرة عشان مضغوط في الشغل',
    'شربت كوبايتين قهوة',
    'ضيف للمشتريات سماعة بـ 1500 جنيه',
    'فكرة تطبيق للمشاوير',
    'ملاحظة اللي بيذاكر بيتعلم الصبر',
    'محتاج كشف أسنان يوم الخميس',
    'امسح مهمة التقرير',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusFeedback = null;
    });

    final db = ref.read(databaseProvider);
    final parser = RuleBasedIntentParser();
    final intent = parser.parse(trimmed);

    // Fetch open tasks for status matching
    final activeTasks = await (db.select(db.tasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final openTasks = activeTasks.where((t) => t.status != 'done').toList();

    final candidateTasks = openTasks
        .map((t) => CandidateTask(
              id: t.id,
              title: t.title,
              dueDate: t.dueDate,
              status: t.status,
            ))
        .toList();

    final planner = ActionPlanner();
    final plan = planner.plan(intent, existingOpenTasks: candidateTasks);

    setState(() {
      _currentPlan = plan;
      _isProcessing = false;
    });
  }

  Future<void> _executeCurrentPlan() async {
    if (_currentPlan == null) return;

    final db = ref.read(databaseProvider);
    final executor = ActionExecutor(db: db);

    setState(() {
      _isProcessing = true;
    });

    final result = await executor.execute(_currentPlan!);

    setState(() {
      _isProcessing = false;
    });

    if (result.success) {
      final undoAction = result.undoAction;
      final msg = result.message;

      // Dismiss the sheet
      if (mounted) {
        Navigator.of(context).pop();

        // Show standard Undo snackbar (VOICE.md Section 2.4 & 7)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 6),
            action: undoAction != null
                ? SnackBarAction(
                    label: 'تراجع',
                    onPressed: () async {
                      await undoAction.undo();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم التراجع عن العملية بنجاح'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                  )
                : null,
          ),
        );
      }
    } else {
      setState(() {
        _statusFeedback = result.message;
      });
    }
  }

  void _handleEdit() {
    if (_currentPlan == null) return;
    final plan = _currentPlan!;
    final slots = plan.slots;

    Navigator.of(context).pop(); // Close assistant sheet

    switch (plan.actionType) {
      case 'task':
      case 'errand':
      case 'reminder':
        QuickAddSheet.show(
          context,
          initialKind: slots['kind'] as String? ?? 'task',
          initialTitle: slots['title'] as String?,
          initialDate: slots['date'] as String?,
          initialTime: slots['time'] as String?,
          initialReminderOffset: slots['reminderOffsetMinutes'] as int?,
          initialLocation: slots['location'] as String?,
        );
        break;

      case 'expense':
      case 'income':
        AddTransactionSheet.show(
          context,
          initialKind: plan.actionType == 'expense' ? 'expense' : 'income',
        );
        break;

      case 'note':
        AddNoteSheet.show(context);
        break;

      case 'idea':
        AddIdeaSheet.show(context);
        break;

      default:
        QuickAddSheet.show(
          context,
          initialTitle: plan.intent.rawText,
        );
    }
  }

  void _handleDateChipSelected(String chip) {
    if (_currentPlan == null) return;
    final now = DateTime.now();
    String? newDate;

    if (chip == 'today') {
      newDate = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } else if (chip == 'tomorrow') {
      final tomorrow = now.add(const Duration(days: 1));
      newDate = '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    } else if (chip == 'custom') {
      showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 365 * 5)),
      ).then((selected) {
        if (selected != null) {
          final customDateStr = '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
          _updatePlanDate(customDateStr, 'custom');
        }
      });
      return;
    }

    _updatePlanDate(newDate, chip);
  }

  void _updatePlanDate(String? newDate, String chip) {
    if (_currentPlan == null) return;
    final updatedSlots = Map<String, dynamic>.from(_currentPlan!.slots);
    if (newDate != null) {
      updatedSlots['date'] = newDate;
    } else {
      updatedSlots.remove('date');
    }

    final title = updatedSlots['title'] ?? 'مهمة';
    final dateWords = newDate != null ? ActionPlanner.formatDateInArabicWords(newDate) : null;
    final timeStr = updatedSlots['time'] as String?;
    final timeWords = timeStr != null ? ActionPlanner.formatTimeInArabic(timeStr) : null;

    final buffer = StringBuffer('مهمة — $title');
    if (dateWords != null) buffer.write(' — $dateWords');
    if (timeWords != null) buffer.write(' — $timeWords');

    setState(() {
      _currentPlan = _currentPlan!.copyWith(
        slots: updatedSlots,
        selectedDateChip: chip,
        hasMissingDate: newDate == null,
        descriptionInWords: buffer.toString(),
      );
    });
  }

  void _handleReasonSelected(String reason) {
    if (_currentPlan == null) return;
    final updatedSlots = Map<String, dynamic>.from(_currentPlan!.slots);
    updatedSlots['reason'] = reason;

    final title = updatedSlots['title'] ?? 'مهمة';
    final status = updatedSlots['status'] ?? 'done';
    final dateStr = updatedSlots['date'] as String?;
    final dateWords = dateStr != null ? ActionPlanner.formatDateInArabicWords(dateStr) : null;

    String statusLabel = 'تمت';
    if (status == 'postponed') statusLabel = 'مؤجلة';
    if (status == 'waiting') statusLabel = 'معلقة';
    if (status == 'stopped') statusLabel = 'متوقفة';
    if (status == 'partial') statusLabel = 'مكتملة جزئياً';

    final buffer = StringBuffer('تحديث مهمة — $title — $statusLabel');
    if (dateWords != null) buffer.write(' إلى $dateWords');
    buffer.write(' ($reason)');

    setState(() {
      _currentPlan = _currentPlan!.copyWith(
        slots: updatedSlots,
        hasMissingReason: false,
        descriptionInWords: buffer.toString(),
      );
    });
  }

  void _handleCandidateSelected(CandidateTask task) {
    if (_currentPlan == null) return;
    final updatedSlots = Map<String, dynamic>.from(_currentPlan!.slots);
    updatedSlots['taskId'] = task.id;
    updatedSlots['title'] = task.title;

    final status = updatedSlots['status'] ?? 'done';
    final dateStr = updatedSlots['date'] as String?;
    final reason = updatedSlots['reason'] as String?;
    final dateWords = dateStr != null ? ActionPlanner.formatDateInArabicWords(dateStr) : null;

    String statusLabel = 'تمت';
    if (status == 'postponed') statusLabel = 'مؤجلة';
    if (status == 'waiting') statusLabel = 'معلقة';
    if (status == 'stopped') statusLabel = 'متوقفة';
    if (status == 'partial') statusLabel = 'مكتملة جزئياً';

    final buffer = StringBuffer('تحديث مهمة — ${task.title} — $statusLabel');
    if (dateWords != null) buffer.write(' إلى $dateWords');
    if (reason != null && reason.isNotEmpty) buffer.write(' ($reason)');

    setState(() {
      _currentPlan = _currentPlan!.copyWith(
        slots: updatedSlots,
        isAmbiguous: false,
        descriptionInWords: buffer.toString(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title and Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.keyboard_outlined,
                          color: colorScheme.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المساعد الذكي (تجربة الأوامر)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'إدخال نصي وتأكيد الإجراءات (Step 3)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Text Input Field (VOICE.md Section 2.2)
              TextField(
                controller: _inputController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleInput,
                decoration: InputDecoration(
                  hintText: 'اكتب أمراً هنا (مثال: سجل شاي وقهوة بـ 25 جنيه)...',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_inputController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            setState(() {
                              _inputController.clear();
                              _currentPlan = null;
                              _statusFeedback = null;
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded),
                        color: colorScheme.primary,
                        onPressed: () => _handleInput(_inputController.text),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (text) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Suggestion chips
              Text(
                'أمثلة مقترحة للتجربة السريعة:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestedPhrases.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final phrase = _suggestedPhrases[index];
                    return ActionChip(
                      label: Text(
                        phrase,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () {
                        _inputController.text = phrase;
                        _handleInput(phrase);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Progress Indicator
              if (_isProcessing) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (_statusFeedback != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusFeedback!,
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ] else if (_currentPlan != null) ...[
                // Card View Area
                if (_currentPlan!.isUnrecognized) ...[
                  // Not understood fallback card (VOICE.md Section 2.7)
                  Card(
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.help_outline_rounded, color: colorScheme.secondary),
                              const SizedBox(width: 8),
                              Text(
                                'سمعت... مفهمتش',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_currentPlan!.descriptionInWords),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              QuickAddSheet.show(
                                context,
                                initialTitle: _currentPlan!.fallbackTitle,
                              );
                            },
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('افتح الإضافة ده بالنص'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  ConfirmationCard(
                    plan: _currentPlan!,
                    onConfirm: _executeCurrentPlan,
                    onEdit: _handleEdit,
                    onCancel: () {
                      setState(() {
                        _currentPlan = null;
                        _inputController.clear();
                      });
                    },
                    onDateChipSelected: _handleDateChipSelected,
                    onReasonSelected: _handleReasonSelected,
                    onCandidateSelected: _handleCandidateSelected,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
