import 'action_plan.dart';
import 'assistant_intent.dart';
import 'text_normalizer.dart';

/// Transforms an [AssistantIntent] into an [ActionPlan] with formatted descriptions,
/// validated slots, and missing/ambiguous resolution (VOICE.md Section 2.4, 5.1-5.3, 7).
class ActionPlanner {
  final DateTime Function()? _nowProvider;

  static const List<String> _arabicMonths = [
    '',
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  static const List<String> _arabicWeekdays = [
    '',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const Map<String, String> _habitDisplayNames = {
    'coffee': 'شرب القهوة',
    'water': 'شرب الماء',
    'quran': 'ورد القرآن',
    'fajr': 'صلاة الفجر',
    'prayers': 'الصلوات الخمس',
    'azkar': 'الأذكار',
    'reading': 'القراءة',
    'exercise': 'الرياضة',
  };

  static const List<String> defaultReasonChips = [
    'مضغوط في الشغل',
    'مفيش فلوس',
    'تعبت',
    'مستني رد',
    'مشوار طارئ',
  ];

  const ActionPlanner({DateTime Function()? nowProvider}) : _nowProvider = nowProvider;

  DateTime _getNow(DateTime? referenceNow) {
    if (referenceNow != null) return referenceNow;
    if (_nowProvider != null) return _nowProvider();
    return DateTime.now();
  }

  /// Formats date string (YYYY-MM-DD) into full Arabic words (e.g. "الأحد 8 نوفمبر 2026")
  static String formatDateInArabicWords(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return dateStr;

    final dt = DateTime(year, month, day);
    final weekdayName = _arabicWeekdays[dt.weekday];
    final monthName = _arabicMonths[month];
    return '$weekdayName $day $monthName $year';
  }

  /// Formats time string (HH:mm) into Arabic AM/PM (e.g. "5:00 م")
  static String formatTimeInArabic(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return timeStr;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return timeStr;

    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Formats reminder offset minutes into plain Arabic words
  static String formatReminderOffset(int offsetMinutes) {
    if (offsetMinutes == 0) return 'تنبيه في نفس الوقت';
    if (offsetMinutes == 10) return 'منبه قبلها 10 دقايق';
    if (offsetMinutes == 30) return 'منبه قبلها نص ساعة';
    if (offsetMinutes == 60) return 'منبه قبلها بساعة';
    if (offsetMinutes == 1440) return 'منبه قبلها بيوم';
    return 'منبه قبلها بـ $offsetMinutes دقيقة';
  }

  /// Main planning entry point
  ActionPlan plan(
    AssistantIntent intent, {
    List<CandidateTask> existingOpenTasks = const [],
    DateTime? referenceNow,
  }) {
    final now = _getNow(referenceNow);

    // 1. Safety check / blocked command
    if (intent.type == AssistantIntentType.unsupportedDelete) {
      return ActionPlan(
        intent: intent,
        actionType: 'blocked',
        actionTitle: 'إجراء محظور',
        descriptionInWords: 'ده مش متاح بالصوت: حذف العناصر غير متاح لحماية بياناتك',
        slots: const {},
        isBlocked: true,
        blockedMessage: 'ده مش متاح بالصوت: حذف العناصر غير متاح لحماية بياناتك',
      );
    }

    // 2. Unrecognized fallback
    if (intent.type == AssistantIntentType.unrecognized) {
      final raw = intent.rawText;
      return ActionPlan(
        intent: intent,
        actionType: 'unrecognized',
        actionTitle: 'لم يتم الفهم',
        descriptionInWords: raw.isNotEmpty
            ? 'سمعت: "$raw" — مفهمتش، تقدر تفتح الإضافة السريعة ده بالنص'
            : 'لم يتم التقاط أي كلام واضح',
        slots: const {},
        isUnrecognized: true,
        fallbackTitle: raw,
      );
    }

    // 3. Command planning
    switch (intent.type) {
      case AssistantIntentType.createTask:
        return _planCreateTask(intent, now);

      case AssistantIntentType.createErrand:
        return _planCreateErrand(intent, now);

      case AssistantIntentType.createReminder:
        return _planCreateReminder(intent, now);

      case AssistantIntentType.updateStatus:
        return _planUpdateStatus(intent, existingOpenTasks, now);

      case AssistantIntentType.logExpense:
        return _planLogExpense(intent);

      case AssistantIntentType.logIncome:
        return _planLogIncome(intent);

      case AssistantIntentType.logHabit:
        return _planLogHabit(intent);

      case AssistantIntentType.createNote:
        return _planCreateNote(intent);

      case AssistantIntentType.createIdea:
        return _planCreateIdea(intent);

      case AssistantIntentType.recordVoiceNote:
        return _planRecordVoiceNote(intent);

      case AssistantIntentType.createWishlistItem:
        return _planCreateWishlistItem(intent);

      case AssistantIntentType.createHealthItem:
        return _planCreateHealthItem(intent);

      default:
        // Questions will be planned as answer cards in Step 4
        return ActionPlan(
          intent: intent,
          actionType: 'question',
          actionTitle: 'استفسار',
          descriptionInWords: 'سؤال: "${intent.rawText}"',
          slots: intent.slots,
        );
    }
  }

  ActionPlan _planCreateTask(AssistantIntent intent, DateTime now) {
    final title = intent.title ?? 'مهمة جديدة';
    final dateStr = intent.dateStr;
    final timeStr = intent.timeStr;
    final offset = intent.reminderOffsetMinutes ?? 10; // Default 10 min alarm from Settings

    final hasMissingDate = (dateStr == null);
    final dateWords = dateStr != null ? formatDateInArabicWords(dateStr) : null;
    final timeWords = timeStr != null ? formatTimeInArabic(timeStr) : null;
    final remWords = formatReminderOffset(offset);

    final buffer = StringBuffer('مهمة — $title');
    if (dateWords != null) buffer.write(' — $dateWords');
    if (timeWords != null) buffer.write(' — $timeWords');
    buffer.write(' — $remWords');

    return ActionPlan(
      intent: intent,
      actionType: 'task',
      actionTitle: 'إنشاء مهمة جديدة',
      descriptionInWords: buffer.toString(),
      slots: {
        'title': title,
        if (dateStr != null) 'date': dateStr,
        if (timeStr != null) 'time': timeStr,
        'reminderOffsetMinutes': offset,
        'kind': 'task',
      },
      hasMissingDate: hasMissingDate,
      selectedDateChip: hasMissingDate ? 'none' : 'custom',
    );
  }

  ActionPlan _planCreateErrand(AssistantIntent intent, DateTime now) {
    final title = intent.title ?? 'مشوار جديد';
    final dateStr = intent.dateStr;
    final timeStr = intent.timeStr;
    final location = intent.slots['location']?.toString();
    final offset = intent.reminderOffsetMinutes ?? 10;

    final dateWords = dateStr != null ? formatDateInArabicWords(dateStr) : null;
    final timeWords = timeStr != null ? formatTimeInArabic(timeStr) : null;

    final buffer = StringBuffer('مشوار — $title');
    if (location != null && location.isNotEmpty) buffer.write(' ($location)');
    if (dateWords != null) buffer.write(' — $dateWords');
    if (timeWords != null) buffer.write(' — $timeWords');

    return ActionPlan(
      intent: intent,
      actionType: 'errand',
      actionTitle: 'تسجيل مشوار',
      descriptionInWords: buffer.toString(),
      slots: {
        'title': title,
        if (dateStr != null) 'date': dateStr,
        if (timeStr != null) 'time': timeStr,
        if (location != null) 'location': location,
        'reminderOffsetMinutes': offset,
        'kind': 'errand',
      },
      hasMissingDate: dateStr == null,
    );
  }

  ActionPlan _planCreateReminder(AssistantIntent intent, DateTime now) {
    final title = intent.title ?? 'تذكير';
    final dateStr = intent.dateStr;
    final timeStr = intent.timeStr;
    final offset = intent.reminderOffsetMinutes ?? 10;

    final dateWords = dateStr != null ? formatDateInArabicWords(dateStr) : null;
    final timeWords = timeStr != null ? formatTimeInArabic(timeStr) : null;
    final remWords = formatReminderOffset(offset);

    final buffer = StringBuffer('تذكير — $title');
    if (dateWords != null) buffer.write(' — $dateWords');
    if (timeWords != null) buffer.write(' — $timeWords');
    buffer.write(' — $remWords');

    return ActionPlan(
      intent: intent,
      actionType: 'reminder',
      actionTitle: 'إنشاء تذكير',
      descriptionInWords: buffer.toString(),
      slots: {
        'title': title,
        if (dateStr != null) 'date': dateStr,
        if (timeStr != null) 'time': timeStr,
        'reminderOffsetMinutes': offset,
        'kind': 'task',
      },
    );
  }

  ActionPlan _planUpdateStatus(AssistantIntent intent, List<CandidateTask> openTasks, DateTime now) {
    final requestedTitle = intent.title ?? '';
    final status = intent.status ?? 'done';
    final dateStr = intent.dateStr;
    final reason = intent.reason;
    final progress = intent.progress;

    // Map status to Arabic
    String statusLabel = 'تمت';
    if (status == 'in_progress') statusLabel = 'جارية';
    if (status == 'postponed') statusLabel = 'مؤجلة';
    if (status == 'waiting') statusLabel = 'معلقة';
    if (status == 'stopped') statusLabel = 'متوقفة';
    if (status == 'partial') {
      final pct = ((progress ?? 0.5) * 100).round();
      statusLabel = 'مكتملة جزئياً ($pct%)';
    }

    // Match task from open tasks
    final matchResult = _findMatchingTasks(requestedTitle, openTasks, now);
    final matchedTask = matchResult.bestTask;
    final isAmbiguous = matchResult.isAmbiguous;
    final candidates = matchResult.candidates;

    final displayTitle = matchedTask?.title ?? (requestedTitle.isNotEmpty ? requestedTitle : 'مهمة');
    final dateWords = dateStr != null ? formatDateInArabicWords(dateStr) : null;

    final buffer = StringBuffer('تحديث مهمة — $displayTitle — $statusLabel');
    if (dateWords != null) buffer.write(' إلى $dateWords');
    if (reason != null && reason.isNotEmpty) buffer.write(' ($reason)');

    // Reason required for postponed, waiting, stopped, partial
    final needsReason = (status == 'postponed' || status == 'waiting' || status == 'stopped' || status == 'partial');
    final hasMissingReason = needsReason && (reason == null || reason.trim().isEmpty);

    return ActionPlan(
      intent: intent,
      actionType: 'status_update',
      actionTitle: 'تحديث حالة مهمة',
      descriptionInWords: buffer.toString(),
      slots: {
        'status': status,
        'title': displayTitle,
        if (matchedTask != null) 'taskId': matchedTask.id,
        if (dateStr != null) 'date': dateStr,
        if (reason != null) 'reason': reason,
        if (progress != null) 'progress': progress,
      },
      isAmbiguous: isAmbiguous,
      candidateTasks: candidates,
      hasMissingReason: hasMissingReason,
      reasonChips: defaultReasonChips,
    );
  }

  ActionPlan _planLogExpense(AssistantIntent intent) {
    final amount = intent.amount ?? 0.0;
    final category = intent.category ?? 'طعام ومطاعم';
    final isEssential = intent.isEssential ?? false;
    final title = intent.title ?? category;
    final dateStr = intent.dateStr;

    final natureLabel = isEssential ? 'أساسي' : 'جانبي';
    final amountInt = amount.round();

    final buffer = StringBuffer('مصروف — $category — $amountInt جنيه — $natureLabel');
    if (title.isNotEmpty && title != category) {
      buffer.write(' ($title)');
    }

    return ActionPlan(
      intent: intent,
      actionType: 'expense',
      actionTitle: 'تسجيل مصروف',
      descriptionInWords: buffer.toString(),
      slots: {
        'amount': amount,
        'currency': 'EGP',
        'category': category,
        'isEssential': isEssential,
        'nature': isEssential ? 'essential' : 'side',
        'title': title,
        if (dateStr != null) 'date': dateStr,
      },
    );
  }

  ActionPlan _planLogIncome(AssistantIntent intent) {
    final amount = intent.amount ?? 0.0;
    final title = intent.title ?? 'مرتب / دخل';
    final dateStr = intent.dateStr;
    final amountInt = amount.round();

    final buffer = StringBuffer('دخل — $title — $amountInt جنيه');

    return ActionPlan(
      intent: intent,
      actionType: 'income',
      actionTitle: 'تسجيل دخل',
      descriptionInWords: buffer.toString(),
      slots: {
        'amount': amount,
        'currency': 'EGP',
        'title': title,
        if (dateStr != null) 'date': dateStr,
      },
    );
  }

  ActionPlan _planLogHabit(AssistantIntent intent) {
    final habitKey = intent.habitKey ?? 'coffee';
    final habitName = _habitDisplayNames[habitKey] ?? habitKey;
    final quantity = intent.quantity ?? 1.0;
    final action = intent.slots['action'] as String? ?? 'add';

    final buffer = StringBuffer('عادة — $habitName');
    if (action == 'tick') {
      buffer.write(' (تم الإنجاز)');
    } else {
      buffer.write(' (+${quantity.round()})');
    }

    return ActionPlan(
      intent: intent,
      actionType: 'habit',
      actionTitle: 'تسجيل عادة',
      descriptionInWords: buffer.toString(),
      slots: {
        'habitKey': habitKey,
        'habitName': habitName,
        'quantity': quantity,
        'action': action,
      },
    );
  }

  ActionPlan _planCreateNote(AssistantIntent intent) {
    final title = intent.title ?? '';
    final isQuote = intent.noteKind == 'quote';
    final kindLabel = isQuote ? 'حكمة / اقتباس' : 'ملاحظة';

    return ActionPlan(
      intent: intent,
      actionType: 'note',
      actionTitle: 'تدوين $kindLabel',
      descriptionInWords: '$kindLabel — $title',
      slots: {
        'title': title,
        'noteKind': isQuote ? 'quote' : 'note',
      },
    );
  }

  ActionPlan _planCreateIdea(AssistantIntent intent) {
    final title = intent.title ?? 'فكرة جديدة';

    return ActionPlan(
      intent: intent,
      actionType: 'idea',
      actionTitle: 'تسجيل فكرة',
      descriptionInWords: 'فكرة — $title',
      slots: {
        'title': title,
      },
    );
  }

  ActionPlan _planRecordVoiceNote(AssistantIntent intent) {
    final isIdea = intent.voiceNoteKind == 'idea';
    final kindLabel = isIdea ? 'فكرة صوتية' : 'ملاحظة صوتية';

    return ActionPlan(
      intent: intent,
      actionType: 'record_voice_note',
      actionTitle: 'تسجيل $kindLabel',
      descriptionInWords: 'تسجيل — $kindLabel (فتح مسجل الصوت)',
      slots: {
        'voiceNoteKind': isIdea ? 'idea' : 'note',
      },
    );
  }

  ActionPlan _planCreateWishlistItem(AssistantIntent intent) {
    final title = intent.title ?? 'عنصر أمنيات';
    final amount = intent.amount;

    final buffer = StringBuffer('مشتريات — $title');
    if (amount != null) {
      buffer.write(' (${amount.round()} جنيه)');
    }

    return ActionPlan(
      intent: intent,
      actionType: 'wishlist',
      actionTitle: 'إضافة لقائمة المشتريات',
      descriptionInWords: buffer.toString(),
      slots: {
        'title': title,
        if (amount != null) 'amount': amount,
        'currency': 'EGP',
      },
    );
  }

  ActionPlan _planCreateHealthItem(AssistantIntent intent) {
    final title = intent.title ?? 'كشف طبي';
    final dateStr = intent.dateStr;

    final buffer = StringBuffer('كشف طبي — $title');
    if (dateStr != null) {
      buffer.write(' — ${formatDateInArabicWords(dateStr)}');
    }

    return ActionPlan(
      intent: intent,
      actionType: 'health',
      actionTitle: 'تسجيل فحص طبي',
      descriptionInWords: buffer.toString(),
      slots: {
        'title': title,
        'status': 'needed',
        if (dateStr != null) 'date': dateStr,
      },
    );
  }

  // =========================================================================
  // TASK LOOKUP & SCORING (VOICE.md Section 5.3)
  // =========================================================================

  static Set<String> _extractTokens(String text) {
    final tokens = <String>{};
    for (final raw in text.split(' ')) {
      final t = raw.trim();
      if (t.length > 1) {
        tokens.add(t);
        if (t.startsWith('ال') && t.length > 3) {
          tokens.add(t.substring(2));
        }
      }
    }
    return tokens;
  }

  static String _stripArticle(String text) {
    return text.split(' ').map((w) {
      if (w.startsWith('ال') && w.length > 3) {
        return w.substring(2);
      }
      return w;
    }).join(' ');
  }

  _TaskMatchResult _findMatchingTasks(String requestedTitle, List<CandidateTask> openTasks, DateTime now) {
    if (openTasks.isEmpty || requestedTitle.isEmpty) {
      return const _TaskMatchResult(bestTask: null, isAmbiguous: false, candidates: []);
    }

    final queryNorm = TextNormalizer.normalize(requestedTitle);
    final queryTokens = _extractTokens(queryNorm);
    if (queryTokens.isEmpty) {
      return const _TaskMatchResult(bestTask: null, isAmbiguous: false, candidates: []);
    }

    final strippedQuery = _stripArticle(queryNorm);
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final scored = <({CandidateTask task, double score})>[];

    for (final task in openTasks) {
      final taskNorm = TextNormalizer.normalize(task.title);
      final taskTokens = _extractTokens(taskNorm);
      if (taskTokens.isEmpty) continue;

      // Jaccard similarity across expanded tokens
      final intersection = queryTokens.intersection(taskTokens).length;
      final union = queryTokens.union(taskTokens).length;
      double score = union > 0 ? (intersection / union) : 0.0;

      // Substring bonus (checking both raw normalized and stripped article)
      final strippedTask = _stripArticle(taskNorm);
      if (taskNorm.contains(queryNorm) ||
          queryNorm.contains(taskNorm) ||
          strippedTask.contains(strippedQuery) ||
          strippedQuery.contains(strippedTask)) {
        score = (score + 0.5).clamp(0.0, 1.0);
      }

      // Priority bonus: today's tasks (+0.2), overdue (+0.1)
      if (task.dueDate == todayStr) {
        score += 0.2;
      } else if (task.dueDate != null && task.dueDate!.compareTo(todayStr) < 0) {
        score += 0.1;
      }

      if (score >= 0.3) {
        scored.add((task: task, score: score));
      }
    }

    if (scored.isEmpty) {
      return const _TaskMatchResult(bestTask: null, isAmbiguous: false, candidates: []);
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    final best = scored.first;
    // Check if second best is within 10%
    if (scored.length > 1) {
      final second = scored[1];
      if ((best.score - second.score) / best.score <= 0.10) {
        final ambiguousCandidates = scored
            .where((s) => (best.score - s.score) / best.score <= 0.10)
            .map((s) => s.task)
            .toList();
        return _TaskMatchResult(
          bestTask: best.task,
          isAmbiguous: true,
          candidates: ambiguousCandidates,
        );
      }
    }

    return _TaskMatchResult(
      bestTask: best.task,
      isAmbiguous: false,
      candidates: [best.task],
    );
  }
}

class _TaskMatchResult {
  final CandidateTask? bestTask;
  final bool isAmbiguous;
  final List<CandidateTask> candidates;

  const _TaskMatchResult({
    required this.bestTask,
    required this.isAmbiguous,
    required this.candidates,
  });
}
