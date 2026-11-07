import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../finance/presentation/add_transaction_sheet.dart';
import '../../finance/presentation/finance_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../health/presentation/health_screen.dart';
import '../../ideas/presentation/add_idea_sheet.dart';
import '../../notes/presentation/add_note_sheet.dart';
import '../../tasks/presentation/quick_add_sheet.dart';
import '../../timeline/presentation/timeline_calendar_screen.dart';
import '../action_executor.dart';
import '../action_plan.dart';
import '../action_planner.dart';
import '../answer_service.dart';
import '../rule_based_intent_parser.dart';
import '../voice_input_service.dart';
import 'voice_test_screen.dart';
import 'widgets/answer_card.dart';
import 'widgets/confirmation_card.dart';

/// Modal bottom sheet for the Voice Assistant (VOICE.md Section 2.2 & Step 5).
/// Features a large microphone button with chained sessions, live transcript streaming,
/// fallback text input, suggestion chips, confirmation and answer cards.
class AssistantSheet extends ConsumerStatefulWidget {
  final VoiceInputService? voiceService;

  const AssistantSheet({super.key, this.voiceService});

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

class _AssistantSheetState extends ConsumerState<AssistantSheet> with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  late final VoiceInputService _voiceService;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<VoiceInputState>? _stateSub;
  StreamSubscription<String>? _errorSub;

  ActionPlan? _currentPlan;
  AnswerCardData? _currentAnswer;
  bool _isProcessing = false;
  String? _statusFeedback;
  String _liveVoiceTranscript = '';
  VoiceInputState _voiceState = VoiceInputState.idle;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<String> _suggestedPhrases = [
    'ورايا إيه النهارده؟',
    'صرفت كام الشهر ده؟',
    'إيه المهام المتأخرة عندي؟',
    'عملت إيه إمبارح؟',
    'إيه اللي عليا الشهر ده؟',
    'شربت كام قهوة النهارده؟',
    'إيه الكشوفات المؤجلة؟',
    'إجمالي المشتريات اللي عايزها كام؟',
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
  void initState() {
    super.initState();
    _voiceService = widget.voiceService ?? VoiceInputService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _transcriptSub = _voiceService.transcriptStream.listen((text) {
      if (mounted) {
        setState(() {
          _liveVoiceTranscript = text;
        });
      }
    });

    _stateSub = _voiceService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _voiceState = state;
        });
        if (state == VoiceInputState.listening) {
          if (!_pulseController.isAnimating) {
            _pulseController.repeat(reverse: true);
          }
        } else {
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }
      }
    });

    _errorSub = _voiceService.errorStream.listen((error) {
      if (mounted) {
        setState(() {
          _statusFeedback = error;
        });
      }
    });
  }

  @override
  void dispose() {
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _pulseController.dispose();
    _voiceService.cancel();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceListening() async {
    if (_voiceService.isListening) {
      // Tap to stop
      final finalTranscript = await _voiceService.stopListening();
      final textToProcess = finalTranscript.isNotEmpty ? finalTranscript : _liveVoiceTranscript;
      setState(() {
        _liveVoiceTranscript = '';
      });
      if (textToProcess.trim().isNotEmpty) {
        _inputController.text = textToProcess;
        _handleInput(textToProcess);
      }
    } else {
      // Tap to start
      setState(() {
        _statusFeedback = null;
        _liveVoiceTranscript = '';
        _currentPlan = null;
        _currentAnswer = null;
      });
      final started = await _voiceService.startListening();
      if (!started && mounted) {
        setState(() {
          _statusFeedback = 'تعذر تشغيل الميكروفون، يرجى التأكد من الصلاحية.';
        });
      }
    }
  }

  void _handleAnswerNavigation(String? navTarget) {
    if (navTarget == null) return;
    Navigator.of(context).pop();

    switch (navTarget) {
      case 'timeline':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TimelineCalendarScreen()),
        );
        break;
      case 'finance':
      case 'obligations':
      case 'wishlist':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FinanceScreen()),
        );
        break;
      case 'habits':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HabitsScreen()),
        );
        break;
      case 'health':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthScreen()),
        );
        break;
      case 'tasks':
      default:
        break;
    }
  }

  Future<void> _handleInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _statusFeedback = null;
      _currentPlan = null;
      _currentAnswer = null;
    });

    final db = ref.read(databaseProvider);
    final parser = RuleBasedIntentParser();
    final intent = parser.parse(trimmed);

    // If intent is a question, query AnswerService (Step 4 & Section 6)
    if (intent.isQuestion) {
      final answerService = AnswerService(db: db);
      final answerData = await answerService.buildAnswer(intent);
      setState(() {
        _currentAnswer = answerData;
        _isProcessing = false;
      });
      return;
    }

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
    final isListening = _voiceState == VoiceInputState.listening;

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

              // Title and Header with Test Wizard shortcut
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isListening ? Colors.red.shade100 : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isListening ? Icons.mic_rounded : Icons.graphic_eq_rounded,
                          color: isListening ? Colors.red : colorScheme.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المساعد الصوتي الذكي (Voice Assistant)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isListening ? 'جارِ الاستماع... اضغط لإيقاف التسجيل' : 'تحدث بالصوت أو اكتب نصاً أوفلاين',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isListening ? Colors.red : colorScheme.onSurfaceVariant,
                              fontWeight: isListening ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'أداة اختبار الـ 30 جملة (Voice Test)',
                        icon: const Icon(Icons.science_outlined, color: Colors.teal),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VoiceTestScreen(voiceService: _voiceService),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Large Microphone Button with Chained Sessions (VOICE.md Section 2.2 & 3.2)
              Center(
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                      child: GestureDetector(
                        onTap: _toggleVoiceListening,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening ? Colors.red : colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: (isListening ? Colors.red : colorScheme.primary).withValues(alpha: 0.35),
                                blurRadius: isListening ? 20 : 10,
                                spreadRadius: isListening ? 6 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isListening ? 'اضغط للإيقاف والمعالجة' : 'اضغط على المايك وابدأ الكلام',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isListening ? Colors.red : colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Live Transcript Display Area (VOICE.md Section 2.2)
              if (_liveVoiceTranscript.isNotEmpty || isListening) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isListening ? Colors.red.shade50 : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isListening ? Colors.red.shade300 : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isListening ? Icons.hearing_rounded : Icons.record_voice_over_rounded,
                        size: 20,
                        color: isListening ? Colors.red : colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _liveVoiceTranscript.isEmpty ? 'جاري الاستماع إليك...' : _liveVoiceTranscript,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isListening ? Colors.red.shade900 : colorScheme.onSurface,
                            fontStyle: _liveVoiceTranscript.isEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Text Input Field (VOICE.md Section 2.2)
              TextField(
                controller: _inputController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleInput,
                decoration: InputDecoration(
                  hintText: 'أو اكتب أمراً هنا (مثال: سجل شاي وقهوة بـ 25 جنيه)...',
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
                              _currentAnswer = null;
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

              // Status / Loading Indicator
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('جاري المعالجة محلياً...'),
                      ],
                    ),
                  ),
                ),

              // Feedback message
              if (_statusFeedback != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusFeedback!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),

              // Answer Card Preview (Step 4 & Section 6)
              if (_currentAnswer != null)
                AnswerCard(
                  data: _currentAnswer!,
                  onNavigate: _currentAnswer!.navTarget != null
                      ? () => _handleAnswerNavigation(_currentAnswer!.navTarget)
                      : null,
                  onClose: () {
                    setState(() {
                      _currentAnswer = null;
                    });
                  },
                ),

              // Confirmation Card Preview (Step 3 & Section 5)
              if (_currentPlan != null)
                ConfirmationCard(
                  plan: _currentPlan!,
                  onConfirm: _executeCurrentPlan,
                  onEdit: _handleEdit,
                  onCancel: () {
                    setState(() {
                      _currentPlan = null;
                    });
                  },
                  onDateChipSelected: _handleDateChipSelected,
                  onReasonSelected: _handleReasonSelected,
                  onCandidateSelected: _handleCandidateSelected,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
