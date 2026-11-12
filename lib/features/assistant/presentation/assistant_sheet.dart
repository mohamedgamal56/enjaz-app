import 'speech_failure_view.dart';
import 'package:drift/drift.dart' as drift;
import '../../../l10n/app_localizations.dart';
import '../../voice_notes/presentation/voice_recorder_sheet.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/money_formatter.dart';
import '../tts_service.dart';
import 'assistant_help_screen.dart';
import 'assistant_settings_screen.dart';

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

class _AssistantSheetState extends ConsumerState<AssistantSheet>
    with SingleTickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  late final VoiceInputService _voiceService;
  StreamSubscription<String>? _transcriptSub;
  StreamSubscription<VoiceInputState>? _stateSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<String>? _finalSub;

  final _tts = TtsService();
  Timer? _confirmationTimer;
  ActionPlan? _confirmingPlan;
  bool _speaking = false;
  ActionPlan? _currentPlan;

  Future<void> _cancelConfirmation() async {
    _confirmationTimer?.cancel();
    _confirmingPlan = null;
    await _voiceService.cancel();
  }

  Future<void> _startConfirmation(ActionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted ||
        _currentPlan != plan ||
        plan.isBlocked ||
        plan.isUnrecognized ||
        plan.isAmbiguous ||
        plan.hasMissingReason ||
        prefs.getBool('assistant_confirm') == false)
      return;
    await _tts.stop();
    if (!mounted || _currentPlan != plan) return;
    _confirmingPlan = plan;
    final started = await _voiceService.startListening();
    if (!mounted || _confirmingPlan != plan) return;
    if (!started) {
      _confirmingPlan = null;
      return;
    }
    setState(
      () => _statusFeedback = 'قل تمام أو إلغاء أو تعديل، أو استخدم الأزرار',
    );
    _confirmationTimer = Timer(
      Duration(seconds: prefs.getInt('assistant_window') ?? 5),
      () async {
        await _cancelConfirmation();
        if (mounted)
          setState(
            () =>
                _statusFeedback = 'انتهى التأكيد الصوتي. استخدم أزرار الكارت.',
          );
      },
    );
  }

  Future<void> _acceptVoiceConfirmation(String text) async {
    final plan = _confirmingPlan;
    if (plan == null || plan != _currentPlan || _isProcessing) return;
    final word = text.trim().replaceAll(RegExp(r'[.!،؟?]'), '');
    final confirm = [
      'تمام', 'أكد', 'اكد', 'تأكيد', 'ماشي', 'أيوه', 'ايوه',
    ].contains(word);
    final cancel = ['إلغاء', 'الغاء', 'لأ', 'لا', 'سيبك'].contains(word);
    if (!confirm && !cancel && word != 'تعديل') return;
    await _cancelConfirmation();
    if (!mounted || _currentPlan != plan) return;
    if (confirm) {
      await _executeCurrentPlan();
    } else if (cancel) {
      setState(() => _currentPlan = null);
    } else {
      _handleEdit();
    }
  }

  Future<void> _speakAnswer(AnswerCardData answer) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool('assistant_spoken') == false) return;
    final kind = answer.intent.type.name;
    final sensitive = [
      'spending',
      'obligations',
      'wishlist',
      'healthPending',
      'recap',
      'agenda',
    ].contains(kind);
    final restrictSensitive = sensitive &&
        (prefs.getBool('assistant_sensitive') != true ||
            ref.read(financeMaskedProvider));
    final speech = restrictSensitive ? answer.nonSensitiveSpeechText : answer.speechText;
    if (speech == null || speech.isEmpty) return;
    await _cancelConfirmation();
    if (!mounted) return;
    setState(() => _speaking = true);
    final ok = await _tts.speak(
      speech,
      rate: prefs.getDouble('assistant_rate') ?? 0.5,
    );
    if (mounted)
      setState(() {
        _speaking = false;
        if (!ok) _statusFeedback = 'الصوت العربي المحلي غير متاح. ثبّته من إعدادات تحويل النص إلى كلام في الهاتف.';
      });
  }

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

    _finalSub = _voiceService.finalTranscriptStream.listen(
      _acceptVoiceConfirmation,
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
          _statusFeedback = speechFailureText(context, error);
        });
      }
    });
  }

  @override
  void dispose() {
    _confirmationTimer?.cancel();
    _tts.dispose();
    _transcriptSub?.cancel();
    _stateSub?.cancel();
    _errorSub?.cancel();
    _finalSub?.cancel();
    _pulseController.dispose();
    _voiceService.cancel();
    if (widget.voiceService == null) _voiceService.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceListening() async {
    await _tts.stop();
    if (_confirmingPlan != null) {
      await _cancelConfirmation();
      return;
    }
    if (_voiceService.isListening) {
      // Tap to stop
      final finalTranscript = await _voiceService.stopListening();
      final textToProcess = finalTranscript.isNotEmpty
          ? finalTranscript
          : _liveVoiceTranscript;
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
          _statusFeedback = speechFailureText(context, _voiceService.lastErrorCode ?? 'speech_failed');
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
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const FinanceScreen()));
        break;
      case 'habits':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HabitsScreen()));
        break;
      case 'health':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HealthScreen()));
        break;
      case 'tasks':
      default:
        break;
    }
  }

  Future<void> _handleInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
    await _cancelConfirmation();
    await _tts.stop();
    if (!mounted) return;

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
      if (!mounted) return;
      setState(() {
        _currentAnswer = answerData;
        _isProcessing = false;
      });
      _speakAnswer(answerData);
      return;
    }

    // Fetch open tasks for status matching
    final activeTasks = await (db.select(
      db.tasks,
    )..where((t) => t.deletedAt.isNull())).get();
    final openTasks = activeTasks.where((t) => t.status != 'done').toList();

    final candidateTasks = openTasks
        .map(
          (t) => CandidateTask(
            id: t.id,
            title: t.title,
            dueDate: t.dueDate,
            status: t.status,
          ),
        )
        .toList();

    final planner = ActionPlanner();
    final plan = planner.plan(intent, existingOpenTasks: candidateTasks);
    if (plan.isUnrecognized && (await SharedPreferences.getInstance()).getBool('assistant_log') != false) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.unrecognizedPhrases).insert(UnrecognizedPhrasesCompanion.insert(phrase: trimmed, at: now, createdAt: now, updatedAt: now));
    }
    if (!mounted) return;

    setState(() {
      _currentPlan = plan;
      _isProcessing = false;
    });
    _startConfirmation(plan);
    } catch (_) {
      if (mounted) setState(() => _statusFeedback = 'تعذر معالجة الأمر. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _executeCurrentPlan() async {
    if (_currentPlan == null || _isProcessing) return;
    final plan = _currentPlan!;
    setState(() => _isProcessing = true);
    try {
    await _cancelConfirmation();
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    if (plan.actionType == 'record_voice_note') {
      setState(() => _isProcessing = true);
      final kind = plan.slots['voiceNoteKind'] == 'idea' ? 'idea' : 'note';
      final recording = await VoiceRecorderSheet.show(context);
      if (!mounted) return;
      if (recording != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await db.transaction(() async {
          final id = kind == 'idea'
            ? await db.into(db.ideas).insert(IdeasCompanion.insert(title: 'فكرة صوتية', createdAt: now, updatedAt: now))
            : await db.insertNote(NotesCompanion.insert(body: 'ملاحظة صوتية', createdAt: now, updatedAt: now));
          await db.insertVoiceNote(VoiceNotesCompanion.insert(parentType: kind, parentId: id,
            fileName: recording.relativeFileName, durationMs: drift.Value(recording.durationMs), sizeBytes: drift.Value(recording.sizeBytes),
            recordedAt: now, createdAt: now, updatedAt: now));
        });
      }
      if (mounted) setState(() { _isProcessing = false; _currentPlan = null; _statusFeedback = recording == null ? 'تم إلغاء التسجيل' : 'تم حفظ التسجيل'; });
      return;
    }
    final executor = ActionExecutor(db: db);

    setState(() {
      _isProcessing = true;
    });

    final result = await executor.execute(plan);
    if (!mounted) return;

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
                        final l10n = AppLocalizations.of(context);
                        final isAr = Localizations.localeOf(context).languageCode == 'ar';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n?.assistantUndoSuccess ?? (isAr ? 'تم التراجع عن العملية بنجاح' : 'Undone successfully')),
                            duration: const Duration(seconds: 3),
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
    } catch (_) {
      if (mounted) setState(() => _statusFeedback = 'تعذر حفظ العملية. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleEdit() {
    _cancelConfirmation();
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
        final amountNum = slots['amount'] as num?;
        final amountMinor = amountNum != null ? (amountNum * 100).round() : null;
        final dateStr = slots['date'] as String?;
        final nature = slots['nature'] as String?;
        final note = slots['title'] as String?;
        AddTransactionSheet.show(
          context,
          initialKind: plan.actionType == 'expense' ? 'expense' : 'income',
          initialAmountMinor: amountMinor,
          initialDate: dateStr,
          initialNote: note,
          initialNature: nature,
        );
        break;

      case 'note':
        final title = slots['title'] as String?;
        final noteKind = slots['noteKind'] as String?;
        AddNoteSheet.show(
          context,
          initialTitle: title,
          initialKind: noteKind,
        );
        break;

      case 'idea':
        final title = slots['title'] as String?;
        AddIdeaSheet.show(
          context,
          initialTitle: title,
        );
        break;

      default:
        QuickAddSheet.show(context, initialTitle: plan.intent.rawText);
    }
  }

  void _handleDateChipSelected(String chip) {
    if (_currentPlan == null) return;
    final now = DateTime.now();
    String? newDate;

    if (chip == 'today') {
      newDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    } else if (chip == 'tomorrow') {
      final tomorrow = now.add(const Duration(days: 1));
      newDate =
          '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    } else if (chip == 'custom') {
      showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now.add(const Duration(days: 365 * 5)),
      ).then((selected) {
        if (selected != null) {
          final customDateStr =
              '${selected.year.toString().padLeft(4, '0')}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
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
    final dateWords = newDate != null
        ? ActionPlanner.formatDateInArabicWords(newDate)
        : null;
    final timeStr = updatedSlots['time'] as String?;
    final timeWords = timeStr != null
        ? ActionPlanner.formatTimeInArabic(timeStr)
        : null;

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
    final dateWords = dateStr != null
        ? ActionPlanner.formatDateInArabicWords(dateStr)
        : null;

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
    final dateWords = dateStr != null
        ? ActionPlanner.formatDateInArabicWords(dateStr)
        : null;

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
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
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
                          color: isListening
                              ? Colors.red.shade100
                              : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isListening
                              ? Icons.mic_rounded
                              : Icons.graphic_eq_rounded,
                          color: isListening
                              ? Colors.red
                              : colorScheme.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المساعد الصوتي',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isListening
                                ? 'جارِ الاستماع... اضغط لإيقاف التسجيل'
                                : 'تحدث أو اكتب الأمر',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isListening
                                  ? Colors.red
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isListening
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.help_outline_rounded),
                        tooltip: 'دليل الأوامر',
                        onPressed: () async {
                          await _cancelConfirmation();
                          await _tts.stop();
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AssistantHelpScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_voice),
                        tooltip: 'إعدادات المساعد',
                        onPressed: () async {
                          await _cancelConfirmation();
                          await _tts.stop();
                          if (context.mounted)
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AssistantSettingsScreen(),
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
                      scale: isListening
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      child: GestureDetector(
                        onTap: _toggleVoiceListening,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isListening
                                ? Colors.red
                                : colorScheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isListening
                                            ? Colors.red
                                            : colorScheme.primary)
                                        .withValues(alpha: 0.35),
                                blurRadius: isListening ? 20 : 10,
                                spreadRadius: isListening ? 6 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isListening
                          ? 'اضغط للإيقاف والمعالجة'
                          : 'اضغط على المايك وابدأ الكلام',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isListening
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
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
                    color: isListening
                        ? Colors.red.shade50
                        : colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isListening
                          ? Colors.red.shade300
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isListening
                            ? Icons.hearing_rounded
                            : Icons.record_voice_over_rounded,
                        size: 20,
                        color: isListening ? Colors.red : colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _liveVoiceTranscript.isEmpty
                              ? 'جاري الاستماع إليك...'
                              : _liveVoiceTranscript,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isListening
                                ? Colors.red.shade900
                                : colorScheme.onSurface,
                            fontStyle: _liveVoiceTranscript.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
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
                  hintText:
                      'أو اكتب أمراً هنا (مثال: سجل شاي وقهوة بـ 25 جنيه)...',
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
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
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
                      label: Text(phrase, style: const TextStyle(fontSize: 12)),
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(AppLocalizations.of(context)?.assistantProcessingLocally ?? (Localizations.localeOf(context).languageCode == 'ar' ? 'جاري المعالجة محلياً...' : 'Processing locally...')),
                      ],
                    ),
                  ),
                ),

              // Feedback message
              if (_voiceService.lastErrorCode != null)
                SpeechSettingsButton(code: _voiceService.lastErrorCode!),
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
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onErrorContainer,
                      ),
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

              if (_speaking)
                TextButton.icon(
                  onPressed: () async {
                    await _tts.stop();
                    if (mounted) setState(() => _speaking = false);
                  },
                  icon: const Icon(Icons.stop),
                  label: Text(AppLocalizations.of(context)?.assistantStopSpeaking ?? (Localizations.localeOf(context).languageCode == 'ar' ? 'إيقاف القراءة' : 'Stop Speaking')),
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
                    _cancelConfirmation();
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
