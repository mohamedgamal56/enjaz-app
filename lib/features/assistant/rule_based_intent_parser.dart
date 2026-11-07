import 'assistant_dictionary.dart';
import 'assistant_intent.dart';
import 'date_time_resolver.dart';
import 'intent_parser.dart';
import 'number_words_ar.dart';
import 'text_normalizer.dart';

/// Rule-based intent parser implementation (VOICE.md Section 4 & 5 & 6).
/// Maps Egyptian Arabic transcripts or typed sentences to one of the 16 intents,
/// extracting required slots (titles, amounts, categories, dates, times, reasons).
class RuleBasedIntentParser implements IntentParser {
  final DateTime Function()? _nowProvider;
  final int weekStartWeekday;

  static const List<String> _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'ابريل',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'اغسطس',
    'أغسطس',
    'سبتمبر',
    'اكتوبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  const RuleBasedIntentParser({
    DateTime Function()? nowProvider,
    this.weekStartWeekday = DateTime.saturday,
  }) : _nowProvider = nowProvider;

  DateTime _getNow(DateTime? referenceNow) {
    if (referenceNow != null) return referenceNow;
    if (_nowProvider != null) return _nowProvider!();
    return DateTime.now();
  }

  @override
  AssistantIntent parse(String text, {DateTime? referenceNow}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const AssistantIntent(
        type: AssistantIntentType.unrecognized,
        rawText: '',
        normalizedText: '',
        confidence: 0.0,
      );
    }

    final normalized = TextNormalizer.normalize(trimmed);
    final now = _getNow(referenceNow);
    final dtResolver = DateTimeResolver(
      nowProvider: () => now,
      weekStartWeekday: weekStartWeekday,
    );

    // -------------------------------------------------------------
    // 1. SAFETY & BLOCKED COMMANDS (VOICE.md Section 7 & 11 #12)
    // Deleting anything by voice is strictly forbidden.
    // -------------------------------------------------------------
    if (_isDeleteCommand(normalized)) {
      return AssistantIntent(
        type: AssistantIntentType.unsupportedDelete,
        rawText: trimmed,
        normalizedText: normalized,
        confidence: 1.0,
      );
    }

    // -------------------------------------------------------------
    // 2. VOICE NOTES / AUDIO RECORDING COMMAND (Section 5.2 & 6)
    // "سجل فكرة صوتية", "سجل ملاحظة صوتية"
    // -------------------------------------------------------------
    if (_isVoiceNoteCommand(normalized)) {
      final isIdea = normalized.contains('فكرة') || normalized.contains('فكره');
      return AssistantIntent(
        type: AssistantIntentType.recordVoiceNote,
        rawText: trimmed,
        normalizedText: normalized,
        slots: {
          'voiceNoteKind': isIdea ? 'idea' : 'note',
        },
        confidence: 0.95,
      );
    }

    // -------------------------------------------------------------
    // 3. QUESTIONS (Section 6)
    // Must be an actual question (e.g. contains question marker or interrogative)
    // -------------------------------------------------------------
    if (_isQuestionText(trimmed, normalized)) {
      final questionIntent = _parseQuestion(trimmed, normalized, dtResolver);
      if (questionIntent != null) {
        return questionIntent;
      }
    }

    // -------------------------------------------------------------
    // 4. STATUS UPDATES (Section 5.2: update_status)
    // "خلصت مهمة التقرير", "ابتديت المونتاج", "اجل مهمة التقرير لبكرة لان مفيش فلوس",
    // "مهمة العميل مستنية رد الدكتور", "وقفت مهمة الاعلان بسبب الميزانية",
    // "عملت نص مهمة التصميم لاني تعبت"
    // -------------------------------------------------------------
    final statusIntent = _parseStatusUpdate(trimmed, normalized, dtResolver);
    if (statusIntent != null) {
      return statusIntent;
    }

    // -------------------------------------------------------------
    // 5. WISHLIST ITEMS (Section 5.2 / 6: create_wishlist_item)
    // "ضيف للمشتريات سماعة بألف وخمسمية", "عايز اشتري كاميرا"
    // Check wishlist before expense so "ضيف للمشتريات ... بـ 2000 جنيه" is a wishlist item
    // -------------------------------------------------------------
    if (_isWishlistCommand(normalized)) {
      return _parseWishlistItem(trimmed, normalized);
    }

    // -------------------------------------------------------------
    // 6. EXPENSE LOG (Section 5.2: log_expense)
    // Check expenses before errands so "صرفت 80 جنيه اوبر مشوار الجامعة" is an expense
    // -------------------------------------------------------------
    if (_isExpenseCommand(normalized)) {
      return _parseExpense(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 7. ERRANDS (Section 5.2: create_errand)
    // Word "مشوار" is required.
    // -------------------------------------------------------------
    if (_isErrandCommand(normalized)) {
      return _parseErrand(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 8. HEALTH ITEMS (Section 5.2 / 6: create_health_item)
    // Medical appointments, tests, checkups.
    // -------------------------------------------------------------
    if (_isHealthCommand(normalized)) {
      return _parseHealthItem(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 9. REMINDERS (Section 5.2: create_reminder)
    // "فكرني بكرة الساعة 9 اكلم احمد", "نبهني بعد يومين ادفع الفاتورة"
    // -------------------------------------------------------------
    if (_isReminderCommand(normalized)) {
      return _parseReminder(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 10. INCOME LOG (Section 5.2: log_income)
    // "دخل 5000 من عميل", "قبضت 8000 مرتب"
    // -------------------------------------------------------------
    if (_isIncomeCommand(normalized)) {
      return _parseIncome(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 11. HABIT LOG (Section 5.2: log_habit)
    // "شربت قهوة", "كوبايتين قهوة", "قريت 5 صفحات قران", "صليت الفجر"
    // -------------------------------------------------------------
    if (_isHabitCommand(normalized)) {
      final habitIntent = _parseHabit(trimmed, normalized);
      if (habitIntent != null) return habitIntent;
    }

    // -------------------------------------------------------------
    // 12. NOTES & QUOTES (Section 5.2: create_note)
    // "ملاحظة اللي بيذاكر بيتعلم الصبر", "حكمة...", "اقتباس..."
    // -------------------------------------------------------------
    if (_isNoteCommand(normalized)) {
      return _parseNote(trimmed, normalized);
    }

    // -------------------------------------------------------------
    // 13. IDEAS (Section 5.2 / 6: create_idea)
    // "فكرة تطبيق للمشاوير", "سجل فكرة متجر الكتروني"
    // -------------------------------------------------------------
    if (_isIdeaCommand(normalized)) {
      return _parseIdea(trimmed, normalized);
    }

    // -------------------------------------------------------------
    // 14. TASK CREATION (Section 5.1 & 5.2: create_task)
    // "سجل بكرة اكلم العميل الساعة 5", "انا بكرة عايز اعمل مونتاج الاعلان",
    // "يوم الخميس هقابل الدكتور", "ضيف مهمة اراجع الفاتورة"
    // -------------------------------------------------------------
    if (_isTaskCommand(normalized)) {
      return _parseTask(trimmed, normalized, dtResolver);
    }

    // -------------------------------------------------------------
    // 15. UNRECOGNIZED / FALLBACK
    // -------------------------------------------------------------
    return AssistantIntent(
      type: AssistantIntentType.unrecognized,
      rawText: trimmed,
      normalizedText: normalized,
      confidence: 0.0,
    );
  }

  // =========================================================================
  // MATCHER HELPERS
  // =========================================================================

  bool _isDeleteCommand(String norm) {
    return norm.startsWith('امسح') ||
        norm.startsWith('احذف') ||
        norm.startsWith('شيل مهمة') ||
        norm.startsWith('شيل مهمة ') ||
        norm.startsWith('شيل ') ||
        norm.startsWith('حذف') ||
        norm.startsWith('مسح') ||
        norm.contains('امسح كل') ||
        norm.contains('احذف كل');
  }

  bool _isVoiceNoteCommand(String norm) {
    return norm.contains('صوتيه') || norm.contains('صوتية');
  }

  bool _isQuestionText(String raw, String norm) {
    if (raw.contains('؟') || raw.contains('?')) return true;
    if (norm.startsWith('ملخص ') || norm.contains(' ملخص ')) return true;
    if (norm.startsWith('جدول ') || norm.contains(' جدول ')) return true;
    if (norm.startsWith('تقرير ') || norm.contains(' تقرير ')) return true;
    if (norm.contains('ايه') ||
        norm.contains('إيه') ||
        norm.contains('كام') ||
        norm.contains('بكام') ||
        norm.contains('التزامي') ||
        norm.contains('ورايا ايه') ||
        norm.contains('ورايا إيه') ||
        norm.contains('اكتر حاجه') ||
        norm.contains('اكتر حاجة') ||
        norm.contains('أكتر حاجة')) {
      return true;
    }
    return false;
  }

  bool _isErrandCommand(String norm) {
    // "The word مشوار is required."
    return norm.contains('مشوار');
  }

  bool _isReminderCommand(String norm) {
    return norm.startsWith('فكرني') ||
        norm.startsWith('نبهني') ||
        norm.startsWith('ذكرني') ||
        norm.contains(' فكرني ') ||
        norm.contains(' نبهني ') ||
        norm.contains(' ذكرني ');
  }

  bool _isHealthCommand(String norm) {
    final healthKeywords = [
      'كشف',
      'تحليل',
      'فحص',
      'اشعة',
      'اشعه',
      'اسنان',
      'أسنان',
      'رمد',
      'باطنة',
      'باطنه',
      'عيادة',
      'علاج الصداع',
      'روشتة',
      'روشته',
    ];
    final hasHealthWord = healthKeywords.any((k) => norm.contains(k));
    if (!hasHealthWord) return false;

    // Must be health action/intent
    return norm.contains('محتاج') ||
        norm.contains('عايز') ||
        norm.contains('عاوز') ||
        norm.contains('فكرني') ||
        norm.contains('نبهني') ||
        norm.contains('اروح') ||
        norm.contains('اعمل') ||
        norm.contains('معاد') ||
        norm.contains('موعد');
  }

  bool _isWishlistCommand(String norm) {
    return norm.contains('للمشتريات') ||
        norm.contains('في المشتريات') ||
        norm.contains('قائمة الامنيات') ||
        norm.contains('قائمه الامنيات') ||
        norm.contains('عايز اشتري') ||
        norm.contains('عاوز اشتري') ||
        norm.contains('عايز اجيب') ||
        norm.contains('عاوز اجيب') ||
        norm.contains('نفسي اشتري') ||
        norm.contains('ناوي اشتري');
  }

  bool _isIncomeCommand(String norm) {
    return norm.startsWith('دخل ') ||
        norm.contains(' دخل ') ||
        norm.startsWith('قبضت') ||
        norm.startsWith('استلمت') ||
        norm.startsWith('جالي') ||
        norm.startsWith('ايراد') ||
        norm.startsWith('إيراد') ||
        norm.contains(' مرتب ') ||
        norm.endsWith(' مرتب');
  }

  bool _isExpenseCommand(String norm) {
    if (norm.startsWith('صرفت') ||
        norm.contains(' صرفت ') ||
        norm.startsWith('دفعت') ||
        norm.contains(' دفعت ') ||
        norm.startsWith('اشتريت') ||
        norm.contains(' اشتريت ') ||
        norm.startsWith('مصروف')) {
      return true;
    }

    // Explicit currency token check
    final hasCurrency = RegExp(r'(?:^|[\s،,])(?:جنيه|جنية|ج\.م|egp|قرش|قروش)(?:[\s،,]|\$)').hasMatch(norm);

    // "سجل شاي بـ 25 جنيه", "سجل قهوة بـ 15 جنيه", "سجل شاي بعشرة جنيه"
    if ((norm.startsWith('سجل') || norm.startsWith('ضيف')) &&
        hasCurrency &&
        (AssistantDictionary.matchCategory(norm) != null || RegExp(r'\b\d+\b').hasMatch(norm))) {
      return true;
    }

    // Direct mention of money amount + known expense category
    final moneyRec = NumberWordsAr.extractMoney(norm);
    if (moneyRec != null && AssistantDictionary.matchCategory(norm) != null) {
      return true;
    }

    return false;
  }

  bool _isHabitCommand(String norm) {
    return norm.startsWith('شربت') ||
        norm.startsWith('صليت') ||
        norm.startsWith('قريت') ||
        norm.startsWith('عملت اذكار') ||
        norm.startsWith('كوبايتين') ||
        norm.startsWith('كوبايه') ||
        norm.startsWith('كوباية') ||
        norm.startsWith('فنجان') ||
        norm.contains('صفحات قران') ||
        norm.contains('صفحات قرآن') ||
        norm.contains('ورد القران') ||
        norm.contains('ورد القرآن') ||
        norm.contains('اذكار الصباح') ||
        norm.contains('اذكار المساء') ||
        norm.startsWith('اتمرنت');
  }

  bool _isNoteCommand(String norm) {
    return norm.startsWith('ملاحظه') ||
        norm.startsWith('ملاحظة') ||
        norm.startsWith('سجل ملاحظه') ||
        norm.startsWith('سجل ملاحظة') ||
        norm.startsWith('حكمه') ||
        norm.startsWith('حكمة') ||
        norm.startsWith('اقتباس');
  }

  bool _isIdeaCommand(String norm) {
    return norm.startsWith('فكره') ||
        norm.startsWith('فكرة') ||
        norm.startsWith('سجل فكره') ||
        norm.startsWith('سجل فكرة') ||
        norm.contains('فكرة تطبيق') ||
        norm.contains('فكره تطبيق') ||
        norm.contains('فكرة مشروع') ||
        norm.contains('فكره مشروع');
  }

  bool _isTaskCommand(String norm) {
    // Explicit triggers
    if (norm.startsWith('سجل') ||
        norm.startsWith('سجّل') ||
        norm.startsWith('ضيف مهمة') ||
        norm.startsWith('ضيف مهمه') ||
        norm.startsWith('مهمة') ||
        norm.startsWith('مهمه') ||
        norm.startsWith('هعمل') ||
        norm.startsWith('ناوي')) {
      return true;
    }

    // Spec 5.1: "A command word is optional when the sentence has a date and an intent verb."
    final hasDateWord = norm.contains('بكرة') ||
        norm.contains('النهارده') ||
        norm.contains('السبت') ||
        norm.contains('الاحد') ||
        norm.contains('الاتنين') ||
        norm.contains('التلات') ||
        norm.contains('الاربع') ||
        norm.contains('الخميس') ||
        norm.contains('الجمعه') ||
        norm.contains('بعد يومين') ||
        norm.contains('بعد بكره') ||
        norm.contains('بعد بكرة') ||
        RegExp(r'\d{1,2}/\d{1,2}').hasMatch(norm) ||
        _arabicMonths.any((m) => norm.contains(m));

    final hasIntentVerb = norm.contains('اعمل') ||
        norm.contains('أعمل') ||
        norm.contains('هعمل') ||
        norm.contains('اقابل') ||
        norm.contains('أقابل') ||
        norm.contains('هقابل') ||
        norm.contains('اكلم') ||
        norm.contains('أكلم') ||
        norm.contains('هكلم') ||
        norm.contains('اروح') ||
        norm.contains('أروح') ||
        norm.contains('هروح') ||
        norm.contains('اجدد') ||
        norm.contains('أجدد') ||
        norm.contains('هجدد') ||
        norm.contains('اراجع') ||
        norm.contains('أراجع') ||
        norm.contains('هراجع') ||
        norm.contains('اسلم') ||
        norm.contains('أسلم') ||
        norm.contains('هسلم') ||
        norm.contains('اكتب') ||
        norm.contains('أكتب') ||
        norm.contains('هكتب') ||
        norm.contains('اذاكر') ||
        norm.contains('أذاكر') ||
        norm.contains('هذاكر') ||
        norm.contains('اشتغل') ||
        norm.contains('عايز') ||
        norm.contains('عاوز') ||
        norm.contains('لازم') ||
        norm.contains('ضروري');

    return hasDateWord && hasIntentVerb;
  }

  // =========================================================================
  // QUESTION PARSER (Section 6)
  // =========================================================================

  AssistantIntent? _parseQuestion(String raw, String norm, DateTimeResolver dtResolver) {
    // 1. Pending questions (Section 6: pending)
    // "ايه المتأخر عندي؟", "إيه المهام المتأخرة عندي؟", "ايه المؤجل؟", "ايه اللي مستنيه؟"
    if (norm.contains('متاخر') ||
        norm.contains('متأخر') ||
        norm.contains('متاخره') ||
        norm.contains('متأخرة') ||
        norm.contains('المؤجل') ||
        norm.contains('الموجل') ||
        norm.contains('المؤجله') ||
        norm.contains('الموجله') ||
        norm.contains('مستنيه') ||
        norm.contains('مستني ايه') ||
        norm.contains('ايه المعلق') ||
        norm.contains('المعلق') ||
        norm.contains('معلق')) {
      if (!norm.contains('الالتزامات') &&
          !norm.contains('اقساط') &&
          !norm.contains('أقساط') &&
          !norm.contains('كشوفات') &&
          !norm.contains('تحاليل')) {
        String filter = 'overdue';
        if (norm.contains('مؤجل') || norm.contains('موجل') || norm.contains('المؤجلة')) {
          filter = 'postponed';
        } else if (norm.contains('مستني') || norm.contains('معلق')) {
          filter = 'waiting';
        }
        return AssistantIntent(
          type: AssistantIntentType.pending,
          rawText: raw,
          normalizedText: norm,
          slots: {
            'statusFilter': filter,
          },
          confidence: 0.95,
        );
      }
    }

    // 2. Health pending (Section 6: health_pending)
    // "ايه الكشوفات المؤجلة؟", "عندي كشوفات ايه متأخرة؟"
    if ((norm.contains('كشوفات') || norm.contains('تحاليل')) &&
        (norm.contains('مؤجل') || norm.contains('متاخر') || norm.contains('متأخر') || norm.contains('ايه'))) {
      return AssistantIntent(
        type: AssistantIntentType.healthPending,
        rawText: raw,
        normalizedText: norm,
        slots: {
          'statusFilter': 'pending',
        },
        confidence: 0.95,
      );
    }

    // 3. Obligations questions (Section 6: obligations)
    // "ايه عليا الشهر ده؟", "ايه الالتزامات المتأخرة؟", "عليا ايه"
    if (norm.contains('عليا ايه') ||
        norm.contains('عليا إيه') ||
        norm.contains('ايه عليا') ||
        norm.contains('إيه عليا') ||
        norm.contains('الالتزامات') ||
        norm.contains('الاقساط') ||
        norm.contains('الأقساط') ||
        norm.contains('الديون')) {
      final periodRes = dtResolver.resolvePeriod(norm);
      final isOverdue = norm.contains('المتاخر') || norm.contains('المتأخر');
      return AssistantIntent(
        type: AssistantIntentType.obligations,
        rawText: raw,
        normalizedText: norm,
        slots: {
          if (periodRes != null) 'period': periodRes.toString(),
          if (isOverdue) 'statusFilter': 'overdue',
        },
        confidence: 0.95,
      );
    }

    // 4. Wishlist total question (Section 6: wishlist)
    // "اجمالي المشتريات اللي عايزها كام؟", "عايز اشتري حاجات بكام؟"
    if (norm.contains('المشتريات') && (norm.contains('كام') || norm.contains('بكام') || norm.contains('اجمالي'))) {
      return AssistantIntent(
        type: AssistantIntentType.wishlist,
        rawText: raw,
        normalizedText: norm,
        slots: const {},
        confidence: 0.95,
      );
    }

    // 5. Spending questions (Section 6: spending)
    // "صرفت كام الشهر ده؟", "صرفت كام على اكل بره الشهر ده؟", "اكتر حاجة بصرف عليها؟", "مصروف النهارده كام؟"
    if (norm.contains('صرفت كام') ||
        norm.contains('كام صرفت') ||
        norm.contains('مصروف النهارده كام') ||
        norm.contains('اكتر حاجه بصرف عليها') ||
        norm.contains('اكتر حاجة بصرف عليها') ||
        norm.contains('أكتر حاجة بصرف عليها') ||
        norm.contains('مصاريفي') ||
        (norm.contains('صرفت') && (norm.contains('كام') || norm.contains('قد ايه')))) {
      final category = AssistantDictionary.matchCategory(norm);
      final periodRes = dtResolver.resolvePeriod(norm);
      final dateRes = dtResolver.resolveDate(norm);
      final isTopQuery = norm.contains('اكتر') || norm.contains('أكتر');

      return AssistantIntent(
        type: AssistantIntentType.spending,
        rawText: raw,
        normalizedText: norm,
        slots: {
          if (category != null) 'category': category,
          if (periodRes != null) 'period': periodRes.toString(),
          if (dateRes != null) 'date': dateRes.dateStr,
          if (isTopQuery) 'query': 'top_category',
        },
        confidence: 0.95,
      );
    }

    // 6. Habit status questions (Section 6: habit_status)
    // "شربت كام قهوة النهارده؟", "صليت ايه النهارده؟", "التزامي بالقران الاسبوع ده؟"
    if (norm.contains('شربت كام') ||
        norm.contains('كام شربت') ||
        norm.contains('صليت ايه') ||
        norm.contains('صليت إيه') ||
        norm.contains('التزامي') ||
        norm.contains('قريت كام') ||
        (norm.contains('عادات') && norm.contains('ايه'))) {
      final habitKey = AssistantDictionary.matchHabitKey(norm);
      final dateRes = dtResolver.resolveDate(norm);
      final periodRes = dtResolver.resolvePeriod(norm);

      return AssistantIntent(
        type: AssistantIntentType.habitStatus,
        rawText: raw,
        normalizedText: norm,
        slots: {
          if (habitKey != null) 'habitKey': habitKey,
          if (dateRes != null) 'date': dateRes.dateStr,
          if (periodRes != null) 'period': periodRes.toString(),
        },
        confidence: 0.95,
      );
    }

    // 7. Recap questions (Section 6: recap)
    // "ايه عملت امبارح؟", "الاسبوع اللي فات عملت ايه؟", "ايه اللي حصل يوم 12/9؟", "ملخص الشهر ده"
    if (norm.contains('عملت ايه') ||
        norm.contains('عملت إيه') ||
        norm.contains('ايه عملت') ||
        norm.contains('إيه عملت') ||
        norm.contains('ايه اللي حصل') ||
        norm.contains('إيه اللي حصل') ||
        norm.startsWith('ملخص ') ||
        norm.contains(' ملخص ') ||
        norm.startsWith('تقرير ') ||
        norm.contains(' تقرير ')) {
      final dateRes = dtResolver.resolveDate(norm);
      final periodRes = dtResolver.resolvePeriod(norm);

      return AssistantIntent(
        type: AssistantIntentType.recap,
        rawText: raw,
        normalizedText: norm,
        slots: {
          if (dateRes != null) 'date': dateRes.dateStr,
          if (periodRes != null) 'period': periodRes.toString(),
        },
        confidence: 0.95,
      );
    }

    // 8. Agenda questions (Section 6: agenda)
    // "ورايا ايه النهارده؟", "ايه ورايا بعد يومين؟", "ايه عندي يوم الخميس؟", "ايه ورايا الاسبوع ده؟"
    if (norm.contains('ورايا ايه') ||
        norm.contains('ورايا إيه') ||
        norm.contains('ايه ورايا') ||
        norm.contains('إيه ورايا') ||
        norm.contains('ايه عندي') ||
        norm.contains('إيه عندي') ||
        norm.contains('عندي ايه') ||
        norm.contains('عندي إيه') ||
        norm.contains('جدول') ||
        norm.contains('مواعيدي') ||
        norm.contains('ورايا ايه النهارده')) {
      final dateRes = dtResolver.resolveDate(norm);
      final periodRes = dtResolver.resolvePeriod(norm);
      final finalDate = (dateRes == null && periodRes == null) ? dtResolver.resolveDate('النهارده') : dateRes;

      return AssistantIntent(
        type: AssistantIntentType.agenda,
        rawText: raw,
        normalizedText: norm,
        slots: {
          if (finalDate != null) 'date': finalDate.dateStr,
          if (periodRes != null) 'period': periodRes.toString(),
        },
        confidence: 0.95,
      );
    }

    return null;
  }

  // =========================================================================
  // COMMAND PARSERS (Section 5)
  // =========================================================================

  AssistantIntent? _parseStatusUpdate(String raw, String norm, DateTimeResolver dtResolver) {
    String? status;
    double? progress;

    if (norm.contains('عملت نص') || norm.contains('نص مهمة') || norm.contains('نص مهمه')) {
      status = 'partial';
      progress = 0.5;
    } else if (norm.startsWith('خلصت') ||
        norm.contains(' خلصت ') ||
        norm.startsWith('انهيت') ||
        norm.startsWith('انجزت') ||
        norm.startsWith('تميت') ||
        norm.startsWith('كملت')) {
      status = 'done';
    } else if (norm.startsWith('ابتديت') ||
        norm.contains(' ابتديت ') ||
        norm.startsWith('بدات') ||
        norm.startsWith('بدأت') ||
        norm.contains('شغال في')) {
      status = 'in_progress';
    } else if (norm.startsWith('اجل') ||
        norm.startsWith('أجل') ||
        norm.contains(' اجل ') ||
        norm.contains(' أجل ') ||
        norm.startsWith('اخر') ||
        norm.startsWith('أخر') ||
        norm.startsWith('رحل')) {
      status = 'postponed';
    } else if (norm.contains('مستنيه') ||
        norm.contains('مستني') ||
        norm.contains('منتظر') ||
        norm.contains('معلقه')) {
      status = 'waiting';
    } else if (norm.startsWith('وقفت') ||
        norm.contains(' وقفت ') ||
        norm.startsWith('اتوقفت') ||
        norm.startsWith('لغيت مهمة')) {
      status = 'stopped';
    }

    if (status == null) return null;

    // Reason extraction (Section 5.3): after "لان", "لاني", "عشان", "علشان", "بسبب"
    String? reason;
    final reasonMatch = RegExp(r'(?:لاني|لأني|لان|لأن|عشان|علشان|بسبب)\s+(.+)$').firstMatch(raw);
    if (reasonMatch != null) {
      reason = reasonMatch.group(1)!.trim();
    } else if (status == 'waiting') {
      final waitMatch = RegExp(r'(?:مستنية|مستني|منتظر)\s+(.+)$').firstMatch(raw);
      if (waitMatch != null) {
        reason = waitMatch.group(1)!.trim();
      }
    }

    // Target date for postponement (e.g. "لبكرة", "ليوم الخميس")
    String? targetDateStr;
    if (status == 'postponed') {
      final dateRes = dtResolver.resolveDate(norm);
      if (dateRes != null) {
        targetDateStr = dateRes.dateStr;
      }
    }

    // Extract title: remove command words, "مهمة", date words, and the reason clause
    var title = raw;
    if (reason != null && reason.isNotEmpty) {
      final rawReasonMatch = RegExp(r'(?:لاني|لأني|لان|لأن|عشان|علشان|بسبب|مستنية|مستني)\s+.+$').firstMatch(title);
      if (rawReasonMatch != null) {
        title = title.substring(0, rawReasonMatch.start).trim();
      }
    }

    title = _stripWords(title, [
      'خلصت',
      'انهيت',
      'ابتديت',
      'بدأت',
      'بدات',
      'اجل',
      'أجل',
      'أجّل',
      'اجّل',
      'وقفت',
      'اتوقفت',
      'عملت نص',
      'نص',
      'مهمة',
      'مهمه',
      'مستنية',
      'مستني',
      'رد',
      'لبكرة',
      'لبكره',
      'لغدا',
    ]);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.updateStatus,
      rawText: raw,
      normalizedText: norm,
      slots: {
        'status': status,
        if (title.isNotEmpty) 'title': title,
        if (targetDateStr != null) 'date': targetDateStr,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (progress != null) 'progress': progress,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseErrand(String raw, String norm, DateTimeResolver dtResolver) {
    final dateRes = dtResolver.resolveDate(norm);
    final timeRes = dtResolver.resolveTime(norm);

    // Location extraction: text after "من" or "عند"
    String? location;
    final locMatch = RegExp(r'(?:من|عند)\s+([أ-ي\w\s]+?)(?=\s+(?:الساعة|الساعه|\d|النهارده|بكرة|$))').firstMatch(raw);
    if (locMatch != null) {
      location = locMatch.group(1)!.trim();
    }

    // Title extraction: remove "سجل", "مشوار", date, time
    var title = raw;
    title = _stripWords(title, ['سجل', 'سجّل', 'مشوار', 'المشوار', 'عندي مشوار']);
    title = _stripDatesAndTimes(title, norm);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createErrand,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
        if (location != null) 'location': location,
        if (dateRes != null) 'date': dateRes.dateStr,
        if (timeRes != null) 'time': timeRes.timeStr,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseHealthItem(String raw, String norm, DateTimeResolver dtResolver) {
    final dateRes = dtResolver.resolveDate(norm);
    final isScheduled = norm.contains('فكرني') || norm.contains('معاد') || norm.contains('موعد');

    var title = raw;
    title = _stripWords(title, [
      'فكرني',
      'فكّرني',
      'اروح',
      'أروح',
      'اعمل',
      'أعمل',
      'محتاج',
      'عايز',
      'عاوز',
      'اني',
      'إني',
      'معاد',
      'موعد',
    ]);
    title = _stripDatesAndTimes(title, norm);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createHealthItem,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
        if (dateRes != null) 'date': dateRes.dateStr,
        'healthStatus': isScheduled ? 'scheduled' : 'needed',
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseReminder(String raw, String norm, DateTimeResolver dtResolver) {
    final dateRes = dtResolver.resolveDate(norm);
    final timeRes = dtResolver.resolveTime(norm);
    final reminderOffset = dtResolver.resolveReminderOffsetMinutes(norm);

    var title = raw;
    title = _stripWords(title, ['فكرني', 'فكّرني', 'نبهني', 'نبّهني', 'ذكرني', 'ذكّرني']);
    title = _stripDatesAndTimes(title, norm);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createReminder,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
        if (dateRes != null) 'date': dateRes.dateStr,
        if (timeRes != null) 'time': timeRes.timeStr,
        if (reminderOffset != null) 'reminderOffsetMinutes': reminderOffset,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseWishlistItem(String raw, String norm) {
    final moneyRec = NumberWordsAr.extractMoney(norm);
    double? money = moneyRec?.amount;

    if (money == null) {
      // Look for price phrases like "بألف وخمسمية", "بـ 2000"
      final bMatch = RegExp(r'بـ?\s*([أ-ي\s\d]+?)(?:\s*(?:جنيه|جنية|ج|EGP|قرش|$))').firstMatch(norm);
      if (bMatch != null) {
        final phrase = bMatch.group(1)!.trim();
        money = NumberWordsAr.parseNumber(phrase) ?? double.tryParse(phrase);
      }
    }

    var title = raw;
    title = _stripWords(title, [
      'ضيف للمشتريات',
      'للمشتريات',
      'في المشتريات',
      'قائمة الامنيات',
      'قائمه الامنيات',
      'عايز اشتري',
      'عاوز اشتري',
      'عايز اجيب',
      'عاوز اجيب',
      'نفسي اشتري',
      'ناوي اشتري',
      'اشتري',
      'ضيف',
    ]);
    if (money != null) {
      title = _stripMoneyPhrase(title);
    }
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createWishlistItem,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
        if (money != null) 'amount': money,
        if (money != null) 'currency': 'EGP',
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseIncome(String raw, String norm, DateTimeResolver dtResolver) {
    final moneyRec = NumberWordsAr.extractMoney(norm);
    final double? money = moneyRec?.amount ?? _extractFirstNumber(norm);
    final dateRes = dtResolver.resolveDate(norm) ?? dtResolver.resolveDate('النهارده');

    String? source;
    final sourceMatch = RegExp(r'(?:من)\s+([أ-ي\w\s]+)').firstMatch(raw);
    if (sourceMatch != null) {
      source = sourceMatch.group(1)!.trim();
    } else {
      var s = raw;
      s = _stripWords(s, ['دخل', 'قبضت', 'استلمت', 'جالي', 'ايراد', 'إيراد']);
      if (money != null) s = _stripMoneyPhrase(s);
      s = _stripDatesAndTimes(s, norm);
      source = _cleanExtraPunctuation(s);
    }

    return AssistantIntent(
      type: AssistantIntentType.logIncome,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (money != null) 'amount': money,
        'currency': 'EGP',
        if (source != null && source.isNotEmpty) 'title': source,
        if (dateRes != null) 'date': dateRes.dateStr,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseExpense(String raw, String norm, DateTimeResolver dtResolver) {
    final moneyRec = NumberWordsAr.extractMoney(norm);
    final double? money = moneyRec?.amount ?? _extractFirstNumber(norm);
    final category = AssistantDictionary.matchCategory(norm) ?? 'أخرى';
    final isEssential = AssistantDictionary.isEssential(category);
    final dateRes = dtResolver.resolveDate(norm) ?? dtResolver.resolveDate('النهارده');

    var title = raw;
    title = _stripWords(title, ['صرفت', 'دفعت', 'اشتريت', 'سجل', 'سجّل', 'مصروف', 'على']);
    if (money != null) {
      title = _stripMoneyPhrase(title);
    }
    title = _stripDatesAndTimes(title, norm);
    title = _cleanExtraPunctuation(title);

    if (title.isEmpty) {
      title = category;
    }

    return AssistantIntent(
      type: AssistantIntentType.logExpense,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (money != null) 'amount': money,
        'currency': 'EGP',
        'category': category,
        'isEssential': isEssential,
        if (title.isNotEmpty) 'title': title,
        if (dateRes != null) 'date': dateRes.dateStr,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent? _parseHabit(String raw, String norm) {
    final habitKey = AssistantDictionary.matchHabitKey(norm);
    if (habitKey == null) return null;

    double quantity = 1.0;
    String action = 'add';

    if (norm.contains('كوبايتين') || norm.contains('فنجانين') || norm.contains('مرتين')) {
      quantity = 2.0;
    } else {
      final numVal = _extractFirstNumber(norm);
      if (numVal != null && numVal > 0) {
        quantity = numVal;
      }
    }

    if (habitKey == 'fajr' || habitKey == 'prayers' || habitKey == 'azkar' || habitKey == 'exercise') {
      action = 'tick';
    }

    return AssistantIntent(
      type: AssistantIntentType.logHabit,
      rawText: raw,
      normalizedText: norm,
      slots: {
        'habitKey': habitKey,
        'quantity': quantity,
        'action': action,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseNote(String raw, String norm) {
    final isQuote = norm.startsWith('حكمه') || norm.startsWith('حكمة') || norm.startsWith('اقتباس');
    var title = raw;
    title = _stripWords(title, ['سجل ملاحظة', 'سجل ملاحظه', 'ملاحظة', 'ملاحظه', 'حكمة', 'حكمه', 'اقتباس']);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createNote,
      rawText: raw,
      normalizedText: norm,
      slots: {
        'noteKind': isQuote ? 'quote' : 'note',
        if (title.isNotEmpty) 'title': title,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseIdea(String raw, String norm) {
    var title = raw;
    title = _stripWords(title, ['سجل فكرة', 'سجل فكره', 'فكرة', 'فكره']);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createIdea,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
      },
      confidence: 0.95,
    );
  }

  AssistantIntent _parseTask(String raw, String norm, DateTimeResolver dtResolver) {
    final dateRes = dtResolver.resolveDate(norm);
    final timeRes = dtResolver.resolveTime(norm);
    final reminderOffset = dtResolver.resolveReminderOffsetMinutes(norm);

    var title = raw;
    title = _stripWords(title, [
      'سجل',
      'سجّل',
      'ضيف مهمة',
      'ضيف مهمه',
      'مهمة جديدة',
      'مهمه جديده',
      'مهمة',
      'مهمه',
      'أنا',
      'انا',
      'عايز',
      'عاوز',
      'لازم',
      'ضروري',
      'إني',
      'اني',
      'أن',
      'ان',
    ]);
    title = _stripDatesAndTimes(title, norm);
    title = _cleanExtraPunctuation(title);

    return AssistantIntent(
      type: AssistantIntentType.createTask,
      rawText: raw,
      normalizedText: norm,
      slots: {
        if (title.isNotEmpty) 'title': title,
        if (dateRes != null) 'date': dateRes.dateStr,
        if (timeRes != null) 'time': timeRes.timeStr,
        if (reminderOffset != null) 'reminderOffsetMinutes': reminderOffset,
      },
      confidence: 0.9,
    );
  }

  // =========================================================================
  // UTILITY HELPERS FOR TITLE CLEANING & SLOT EXTRACTION
  // =========================================================================

  /// Strips specific words at word boundaries
  String _stripWords(String text, List<String> words) {
    var result = text;
    for (final w in words) {
      final reg = RegExp('(?<=^|[\\s،,])' + RegExp.escape(w) + '(?=[\\s،,]|\$)', caseSensitive: false);
      result = result.replaceAll(reg, ' ');
    }
    return result;
  }

  /// Strips date and time phrases from the raw transcript title
  String _stripDatesAndTimes(String text, String norm) {
    var result = text;

    // Time phrases
    final timePatterns = [
      r'الساعة\s*\d+(?::\d+)?(?:\s*(?:الصبح|صباحا|صباحاً|العصر|الضهر|الظهر|بالليل|مساء|مساءً|ونص|وربع|وتلت|الا ربع|الا تلت))?',
      r'الساعه\s*\d+(?::\d+)?(?:\s*(?:الصبح|صباحا|صباحاً|العصر|الضهر|الظهر|بالليل|مساء|مساءً|ونص|وربع|وتلت|الا ربع|الا تلت))?',
      r'\d{1,2}:\d{2}',
      r'\d+\s*(?:الصبح|صباحا|صباحاً|العصر|الضهر|الظهر|بالليل|مساء|مساءً)',
      r'(?:الساعة|الساعه)\s*(?:واحد|اتنين|تلاته|تلاتة|اربعه|اربعة|خمسه|خمسة|سته|ستة|سبعه|سبعة|تمانيه|تمانية|تسعه|تسعة|عشره|عشرة|حداشر|اتناشر)(?:\s*(?:الصبح|صباحا|صباحاً|العصر|الضهر|الظهر|بالليل|مساء|مساءً|ونص|وربع|وتلت|الا ربع|الا تلت))?',
      r'قبلها\s*(?:بساعة|بساعه|بنص ساعة|بنص ساعه|بربع ساعة|بربع ساعه|بساعتين|بيوم|بيومين)',
    ];

    for (final p in timePatterns) {
      result = result.replaceAll(RegExp('(?<=^|[\\s،,])(?:' + p + ')(?=[\\s،,]|\$)', caseSensitive: false), ' ');
    }

    // Date phrases
    final datePatterns = [
      r'النهارده',
      r'النهاردة',
      r'اليوم',
      r'بكرة',
      r'بكره',
      r'غدا',
      r'غداً',
      r'بعد بكرة',
      r'بعد بكره',
      r'بعد يومين',
      r'بعد اسبوع',
      r'بعد أسبوع',
      r'بعد\s*\d+\s*(?:يوم|ايام|أيام)',
      r'بعد\s*[أ-ي]+\s*(?:يوم|ايام|أيام)',
      r'امبارح',
      r'أمس',
      r'اول امبارح',
      r'أول امبارح',
      r'يوم\s*(?:السبت|الاحد|الأحد|الاتنين|الإثنين|التلات|الثلاثاء|الاربع|الأربعاء|الخميس|الجمعه|الجمعة)',
      r'(?:السبت|الاحد|الأحد|الاتنين|الإثنين|التلات|الثلاثاء|الاربع|الأربعاء|الخميس|الجمعه|الجمعة)(?:\s*(?:اللي فات|الماضي|الجاي|القادم))?',
      r'يوم\s*\d{1,2}\s*[\/\-\.]\s*\d{1,2}(?:\s*[\/\-\.]\s*\d{4})?',
      r'\d{1,2}\s*[\/\-\.]\s*\d{1,2}(?:\s*[\/\-\.]\s*\d{4})?',
      r'(?:يوم\s*)?\d{1,2}\s*(?:يناير|فبراير|مارس|ابريل|أبريل|مايو|يونيو|يوليو|اغسطس|أغسطس|سبتمبر|اكتوبر|أكتوبر|نوفمبر|ديسمبر)(?:\s*\d{4})?',
    ];

    for (final p in datePatterns) {
      result = result.replaceAll(RegExp('(?<=^|[\\s،,])(?:' + p + ')(?=[\\s،,]|\$)', caseSensitive: false), ' ');
    }

    return result;
  }

  /// Strips money expressions from string (e.g. "بـ 25 جنيه", "بعشرة جنيه", "100 جنيه")
  String _stripMoneyPhrase(String text) {
    var result = text;
    final patterns = [
      r'بـ?\s*\d+\s*(?:جنيه|جنية|ج|EGP|قرش)?',
      r'بـ?\s*[أ-ي\s]+\s*(?:جنيه|جنية|ج|EGP|قرش)',
      r'\d+\s*(?:جنيه|جنية|ج|EGP|قرش)',
    ];
    for (final p in patterns) {
      result = result.replaceAll(RegExp('(?<=^|[\\s،,])(?:' + p + ')(?=[\\s،,]|\$)', caseSensitive: false), ' ');
    }
    return result;
  }

  /// Cleans redundant whitespaces and trailing/leading punctuation
  String _cleanExtraPunctuation(String text) {
    var res = text.replaceAll(RegExp(r'[\u060C\u061B\u061F\.,;?!\x27\x22\(\)\[\]{}<>\-_~#@*^+=]'), ' ');
    res = res.replaceAll(RegExp(r'\s+'), ' ').trim();
    return res;
  }

  /// Extracts the first standalone number in text
  double? _extractFirstNumber(String text) {
    final match = RegExp(r'\b\d+(?:\.\d+)?\b').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(0)!);
    }
    return null;
  }
}
