import 'package:flutter/material.dart';
import '../../core/db/app_database.dart';
import '../finance/domain/finance_service.dart';
import '../health/domain/health_service.dart';
import '../habits/domain/habits_service.dart';
import 'action_planner.dart';
import 'assistant_intent.dart';
import 'speech_composer.dart';
import 'plural_ar.dart';

/// Data model representing the rendered answer card (VOICE.md Section 6).
class AnswerCardData {
  final AssistantIntent intent;
  final String title;
  final String speechText;
  final List<String> metricChips;
  final List<String> detailItems;
  final String? navTarget;
  final String? navLabel;
  final IconData icon;

  const AnswerCardData({
    required this.intent,
    required this.title,
    required this.speechText,
    this.metricChips = const [],
    this.detailItems = const [],
    this.navTarget,
    this.navLabel,
    this.icon = Icons.info_outline_rounded,
  });
}

/// Service that builds structured AnswerCardData for all 8 voice assistant questions (VOICE.md Section 6).
///
/// Uses the exact same calculations and services as dashboards to ensure 100% data consistency.
class AnswerService {
  final AppDatabase db;
  final DateTime Function() nowProvider;
  final SpeechComposer speechComposer;
  final FinanceService financeService;
  final HealthService healthService;

  AnswerService({
    required this.db,
    DateTime Function()? nowProvider,
    SpeechComposer? speechComposer,
    FinanceService? financeService,
    HealthService? healthService,
  })  : nowProvider = nowProvider ?? DateTime.now,
        speechComposer = speechComposer ?? const SpeechComposer(),
        financeService = financeService ?? const FinanceService(),
        healthService = healthService ?? const HealthService();

  /// Builds answer card data based on the question intent
  Future<AnswerCardData> buildAnswer(AssistantIntent intent) async {
    final now = nowProvider();
    final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    switch (intent.type) {
      case AssistantIntentType.agenda:
        return _buildAgendaAnswer(intent, now, todayStr);

      case AssistantIntentType.recap:
        return _buildRecapAnswer(intent, now, todayStr);

      case AssistantIntentType.spending:
        return _buildSpendingAnswer(intent, now, todayStr);

      case AssistantIntentType.habitStatus:
        return _buildHabitStatusAnswer(intent, now, todayStr);

      case AssistantIntentType.pending:
        return _buildPendingAnswer(intent, now, todayStr);

      case AssistantIntentType.obligations:
        return _buildObligationsAnswer(intent, now, todayStr);

      case AssistantIntentType.healthPending:
        return _buildHealthPendingAnswer(intent, now, todayStr);

      case AssistantIntentType.wishlist:
        return _buildWishlistAnswer(intent, now, todayStr);

      default:
        return AnswerCardData(
          intent: intent,
          title: 'إجابة',
          speechText: 'هذا السؤال غير مدعوم حالياً.',
          icon: Icons.help_outline_rounded,
        );
    }
  }

  // =========================================================================
  // 1. AGENDA
  // =========================================================================

  Future<AnswerCardData> _buildAgendaAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final targetDateStr = intent.dateStr ?? todayStr;
    final isToday = targetDateStr == todayStr;
    final dateWords = isToday ? 'النهارده' : ActionPlanner.formatDateInArabicWords(targetDateStr);

    // 1. Fetch tasks for target date
    final allTasks = await (db.select(db.tasks)
          ..where((t) => t.dueDate.equals(targetDateStr) & t.deletedAt.isNull()))
        .get();

    // Sort by dueTime
    allTasks.sort((a, b) {
      if (a.dueTime != null && b.dueTime != null) {
        return a.dueTime!.compareTo(b.dueTime!);
      }
      if (a.dueTime != null) return -1;
      if (b.dueTime != null) return 1;
      return a.createdAt.compareTo(b.createdAt);
    });

    final taskTitles = allTasks.map((t) {
      if (t.dueTime != null && t.dueTime!.isNotEmpty) {
        return '${t.title} (${ActionPlanner.formatTimeInArabic(t.dueTime!)})';
      }
      return t.title;
    }).toList();

    // 2. Overdue count (only if viewing today or future)
    int overdueCount = 0;
    if (targetDateStr.compareTo(todayStr) >= 0) {
      final activeTasks = await (db.select(db.tasks)
            ..where((t) => t.deletedAt.isNull()))
          .get();
      overdueCount = activeTasks.where((t) => t.status != 'done' && t.dueDate != null && t.dueDate!.compareTo(todayStr) < 0).length;
    }

    // 3. Obligations due
    final instances = await db.getObligationInstancesForRange(targetDateStr, targetDateStr);
    final pendingObs = instances.where((i) => i.status == 'pending').toList();

    // 4. Health appointments due
    final allHealth = await (db.select(db.healthItems)..where((h) => h.deletedAt.isNull())).get();
    final healthDue = allHealth.where((h) => h.dueBy == targetDateStr || h.localDate == targetDateStr).toList();

    // 5. Habits pending (for today only)
    final pendingHabits = <String>[];
    if (isToday) {
      final activeHabits = await (db.select(db.habits)..where((h) => h.deletedAt.isNull())).get();
      final allLogs = await (db.select(db.habitLogs)
            ..where((l) => l.logDate.equals(todayStr)))
          .get();
      final todayLogs = allLogs.where((l) => l.deletedAt == null).toList();
      final loggedIds = todayLogs.map((l) => l.habitId).toSet();
      for (final h in activeHabits) {
        if (!loggedIds.contains(h.id)) {
          pendingHabits.add(h.nameAr);
        }
      }
    }

    final speech = speechComposer.composeAgenda(
      targetDateWords: dateWords,
      taskTitles: taskTitles,
      overdueCount: overdueCount,
      obligationsCount: pendingObs.length,
      healthCount: healthDue.length,
      pendingHabits: pendingHabits,
    );

    final metricChips = <String>[
      PluralAr.formatTasks(allTasks.length),
      if (overdueCount > 0) '${PluralAr.formatTasks(overdueCount)} متأخرة',
      if (pendingObs.isNotEmpty) '${PluralAr.formatObligations(pendingObs.length)} مستحقة',
      if (healthDue.isNotEmpty) '${PluralAr.formatCheckups(healthDue.length)} طبية',
    ];

    return AnswerCardData(
      intent: intent,
      title: 'جدول المواعيد ($dateWords)',
      speechText: speech,
      metricChips: metricChips,
      detailItems: taskTitles,
      navTarget: 'tasks',
      navLabel: 'فتح قائمة المهام',
      icon: Icons.calendar_today_rounded,
    );
  }

  // =========================================================================
  // 2. RECAP
  // =========================================================================

  Future<AnswerCardData> _buildRecapAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    // Determine period: yesterday, specific date, last week, this month
    final rawText = intent.rawText;
    String startDate = todayStr;
    String endDate = todayStr;
    String periodWords = 'النهارده';

    if (rawText.contains('امبارح') || rawText.contains('أمس') || rawText.contains('مبارح')) {
      final yest = now.subtract(const Duration(days: 1));
      startDate = '${yest.year.toString().padLeft(4, '0')}-${yest.month.toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';
      endDate = startDate;
      periodWords = 'إمبارح';
    } else if (rawText.contains('الاسبوع اللي فات') || rawText.contains('الأسبوع الماضي')) {
      final weekAgo = now.subtract(const Duration(days: 7));
      startDate = '${weekAgo.year.toString().padLeft(4, '0')}-${weekAgo.month.toString().padLeft(2, '0')}-${weekAgo.day.toString().padLeft(2, '0')}';
      endDate = todayStr;
      periodWords = 'الأسبوع اللي فات';
    } else if (rawText.contains('الشهر ده') || rawText.contains('الشهر الحالي')) {
      startDate = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
      endDate = todayStr;
      periodWords = 'الشهر ده';
    } else if (intent.dateStr != null) {
      startDate = intent.dateStr!;
      endDate = intent.dateStr!;
      periodWords = ActionPlanner.formatDateInArabicWords(intent.dateStr!);
    }

    // Done tasks in period
    final allEvents = await (db.select(db.taskEvents)
          ..where((e) => e.toStatus.equals('done')))
        .get();
    final startMs = DateTime.parse(startDate).millisecondsSinceEpoch;
    final endMs = DateTime.parse(endDate).add(const Duration(days: 1)).millisecondsSinceEpoch;
    final doneEvents = allEvents.where((e) => e.at >= startMs && e.at < endMs).toList();

    // Postponed tasks and reasons
    final postponeEvents = allEvents.where((e) => e.toStatus == 'postponed' && e.at >= startMs && e.at < endMs).toList();
    final reasonsMap = <String, int>{};
    for (final e in postponeEvents) {
      if (e.reasonText != null && e.reasonText!.isNotEmpty) {
        reasonsMap[e.reasonText!] = (reasonsMap[e.reasonText!] ?? 0) + 1;
      }
    }
    String? topReason;
    if (reasonsMap.isNotEmpty) {
      final sortedReasons = reasonsMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topReason = sortedReasons.first.key;
    }

    // Spending in period
    final txs = await (db.select(db.transactions)
          ..where((t) => t.kind.equals('expense') & t.deletedAt.isNull()))
        .get();
    final periodTxs = txs.where((t) => t.occurredAt >= startMs && t.occurredAt < endMs).toList();
    final totals = financeService.calculateTotals(periodTxs);

    // Habits adherence in period
    final activeHabits = await (db.select(db.habits)..where((h) => h.deletedAt.isNull())).get();
    final logs = await db.getAllHabitLogsForRange(startDate, endDate);
    double? habitPct;
    if (activeHabits.isNotEmpty) {
      habitPct = (logs.length / (activeHabits.length * (DateTime.parse(endDate).difference(DateTime.parse(startDate)).inDays + 1))).clamp(0.0, 1.0);
    }

    // Notes and Ideas
    final allNotes = await (db.select(db.notes)..where((n) => n.deletedAt.isNull())).get();
    final notesInPeriod = allNotes.where((n) => n.createdAt >= startMs && n.createdAt < endMs).length;

    final allIdeas = await (db.select(db.ideas)..where((i) => i.deletedAt.isNull())).get();
    final ideasInPeriod = allIdeas.where((i) => i.createdAt >= startMs && i.createdAt < endMs).length;

    final speech = speechComposer.composeRecap(
      periodWords: periodWords,
      doneTasksCount: doneEvents.length,
      postponedCount: postponeEvents.length,
      topPostponeReason: topReason,
      habitAdherencePct: habitPct,
      totalSpending: totals.expenseMinor / 100,
      notesCount: notesInPeriod,
      ideasCount: ideasInPeriod,
    );

    final metricChips = <String>[
      'أنجزت ${PluralAr.formatTasks(doneEvents.length)}',
      if (postponeEvents.isNotEmpty) 'أجلت ${PluralAr.formatTasks(postponeEvents.length)}',
      if (totals.expenseMinor > 0) 'مصاريف: ${PluralAr.formatPounds(totals.expenseMinor / 100)}',
      if (habitPct != null && habitPct > 0) 'التزام عادات: ${(habitPct * 100).round()}%',
    ];

    return AnswerCardData(
      intent: intent,
      title: 'ملخص الإنجاز ($periodWords)',
      speechText: speech,
      metricChips: metricChips,
      detailItems: [
        if (doneEvents.isNotEmpty) 'المهام المكتملة: ${doneEvents.length}',
        if (topReason != null) 'أكثر سبب للتأجيل: $topReason',
        if (notesInPeriod > 0) 'ملاحظات مسجلة: $notesInPeriod',
        if (ideasInPeriod > 0) 'أفكار جديدة: $ideasInPeriod',
      ],
      navTarget: 'timeline',
      navLabel: 'فتح السجل الزمني (Timeline)',
      icon: Icons.history_rounded,
    );
  }

  // =========================================================================
  // 3. SPENDING
  // =========================================================================

  Future<AnswerCardData> _buildSpendingAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final rawText = intent.rawText;
    final ym = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    String periodWords = 'الشهر ده';
    String startDate = '$ym-01';
    String endDate = todayStr;

    if (rawText.contains('النهارده') || rawText.contains('اليوم')) {
      periodWords = 'النهارده';
      startDate = todayStr;
      endDate = todayStr;
    } else if (rawText.contains('السنة دي') || rawText.contains('العام الحالي')) {
      periodWords = 'السنة دي';
      startDate = '${now.year.toString().padLeft(4, '0')}-01-01';
      endDate = todayStr;
    }

    final startMs = DateTime.parse(startDate).millisecondsSinceEpoch;
    final endMs = DateTime.parse(endDate).add(const Duration(days: 1)).millisecondsSinceEpoch;

    // Fetch transactions
    final allTxs = await (db.select(db.transactions)
          ..where((t) => t.kind.equals('expense') & t.deletedAt.isNull()))
        .get();
    final periodTxs = allTxs.where((t) => t.occurredAt >= startMs && t.occurredAt < endMs).toList();

    // Specific category query?
    final catQuery = intent.category;
    final allCats = await db.select(db.financeCategories).get();
    final catMap = {for (final c in allCats) c.id: c};

    num totalAmount = 0;
    List<({String name, num amount})> topCategories = [];
    double? essPct;
    double? sidePct;

    if (catQuery != null && catQuery.isNotEmpty) {
      final matchedCat = allCats.cast<FinanceCategory?>().firstWhere(
        (c) => c!.nameAr.contains(catQuery) || catQuery.contains(c.nameAr),
        orElse: () => null,
      );
      if (matchedCat != null) {
        final catTxs = periodTxs.where((t) => t.categoryId == matchedCat.id).toList();
        final catTotals = financeService.calculateTotals(catTxs);
        totalAmount = catTotals.expenseMinor / 100;
      }
    } else {
      final totals = financeService.calculateTotals(periodTxs);
      totalAmount = totals.expenseMinor / 100;

      final catSpendings = financeService.calculateCategorySpendings(periodTxs, catMap);
      topCategories = catSpendings
          .take(3)
          .map((c) => (name: c.nameAr, amount: c.amountMinor / 100))
          .toList();

      final natureShare = financeService.calculateNatureShare(periodTxs);
      essPct = natureShare.essentialPercent;
      sidePct = natureShare.sidePercent;
    }

    final speech = speechComposer.composeSpending(
      periodWords: periodWords,
      totalAmount: totalAmount,
      categoryName: catQuery,
      topCategories: topCategories,
      essentialPct: essPct,
      sidePct: sidePct,
    );

    final metricChips = <String>[
      'الإجمالي: ${PluralAr.formatPounds(totalAmount)}',
      if (essPct != null && sidePct != null && totalAmount > 0) 'أساسي: ${(essPct * 100).round()}% | جانبي: ${(sidePct * 100).round()}%',
    ];

    final detailItems = topCategories.map((c) => '${c.name}: ${PluralAr.formatPounds(c.amount)}').toList();

    return AnswerCardData(
      intent: intent,
      title: 'تقرير المصروفات ($periodWords)',
      speechText: speech,
      metricChips: metricChips,
      detailItems: detailItems,
      navTarget: 'finance',
      navLabel: 'فتح شاشة المالية',
      icon: Icons.account_balance_wallet_rounded,
    );
  }

  // =========================================================================
  // 4. HABIT STATUS
  // =========================================================================

  Future<AnswerCardData> _buildHabitStatusAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final habitKey = intent.habitKey ?? 'coffee';
    final allHabits = await (db.select(db.habits)..where((h) => h.deletedAt.isNull())).get();

    // Map habitKey to Arabic name
    final matched = allHabits.cast<Habit?>().firstWhere(
      (h) => h!.nameAr.contains(habitKey) || (habitKey == 'coffee' && h.nameAr.contains('قهوة')) || (habitKey == 'water' && h.nameAr.contains('مياه')),
      orElse: () => allHabits.isNotEmpty ? allHabits.first : null,
    );

    final habitName = matched?.nameAr ?? 'القهوة';
    final habitId = matched?.id ?? 1;

    // Get today's logs
    final allLogs = await (db.select(db.habitLogs)
          ..where((l) => l.habitId.equals(habitId)))
        .get();
    final todayLogs = allLogs.where((l) => l.logDate == todayStr && l.deletedAt == null).toList();

    num todayCount = 0;
    if (matched != null && matched.type == 'check') {
      todayCount = todayLogs.isNotEmpty ? 1 : 0;
    } else {
      todayCount = todayLogs.fold<num>(0, (sum, l) => sum + (l.value ?? 1.0));
    }

    // Calculate streak
    final historyLogs = await db.getHabitLogsForRange(habitId, '2026-01-01', todayStr);
    final compMap = <String, bool>{};
    for (final l in historyLogs) {
      compMap[l.logDate] = true;
    }
    final streaks = HabitsService.calculateStreaks(
      scheduleDays: matched?.scheduleDays ?? 127,
      completionMap: compMap,
      today: now,
    );

    final speech = speechComposer.composeHabitStatus(
      habitName: habitName,
      todayCount: todayCount,
      habitKey: habitKey,
      currentStreak: streaks.$1,
      isCompletedToday: todayCount > 0,
    );

    final metricChips = <String>[
      'إنجاز اليوم: ${matched?.type == 'check' ? (todayCount > 0 ? 'مكتمل' : 'غير مكتمل') : todayCount.toInt()}',
      'سلسلة الاستمرار: ${PluralAr.formatDays(streaks.$1)}',
    ];

    return AnswerCardData(
      intent: intent,
      title: 'حالة العادة — $habitName',
      speechText: speech,
      metricChips: metricChips,
      detailItems: [
        'أفضل سلسلة استمرار: ${PluralAr.formatDays(streaks.$2)}',
      ],
      navTarget: 'habits',
      navLabel: 'فتح شاشة العادات',
      icon: Icons.loop_rounded,
    );
  }

  // =========================================================================
  // 5. PENDING TASKS
  // =========================================================================

  Future<AnswerCardData> _buildPendingAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final rawText = intent.rawText;
    String filterType = 'overdue';
    if (rawText.contains('المؤجل') || rawText.contains('مؤجل')) {
      filterType = 'postponed';
    } else if (rawText.contains('مستني') || rawText.contains('معلق')) {
      filterType = 'waiting';
    }

    final allActiveTasks = await (db.select(db.tasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final allTasks = allActiveTasks.where((t) => t.status != 'done').toList();

    final filtered = <({String title, String? reason, String? dueDate})>[];
    for (final t in allTasks) {
      if (filterType == 'overdue') {
        if (t.dueDate != null && t.dueDate!.compareTo(todayStr) < 0) {
          filtered.add((title: t.title, reason: t.reasonText, dueDate: t.dueDate));
        }
      } else if (filterType == 'postponed') {
        if (t.status == 'postponed') {
          filtered.add((title: t.title, reason: t.reasonText, dueDate: t.postponedUntil));
        }
      } else if (filterType == 'waiting') {
        if (t.status == 'waiting') {
          filtered.add((title: t.title, reason: t.reasonText, dueDate: t.dueDate));
        }
      }
    }

    final speech = speechComposer.composePending(
      filterType: filterType,
      tasks: filtered.map((t) => (title: t.title, reason: t.reason)).toList(),
    );

    final details = filtered.map((t) {
      final buffer = StringBuffer(t.title);
      if (t.reason != null && t.reason!.isNotEmpty) buffer.write(' — ${t.reason}');
      if (t.dueDate != null) buffer.write(' (${ActionPlanner.formatDateInArabicWords(t.dueDate!)})');
      return buffer.toString();
    }).toList();

    return AnswerCardData(
      intent: intent,
      title: 'المهام المعلقة والمتأخرة',
      speechText: speech,
      metricChips: [PluralAr.formatTasks(filtered.length)],
      detailItems: details,
      navTarget: 'tasks',
      navLabel: 'فتح قائمة التخطيط (Plan)',
      icon: Icons.pending_actions_rounded,
    );
  }

  // =========================================================================
  // 6. OBLIGATIONS
  // =========================================================================

  Future<AnswerCardData> _buildObligationsAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final ym = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final instances = await db.getAllActiveObligationInstances();
    final allObs = await db.getAllObligations();
    final obsMap = {for (final o in allObs) o.id: o.name};

    final lateObs = <({String name, num amount, String dueDate})>[];
    final upcomingObs = <({String name, num amount, String dueDate})>[];
    int totalDueMinor = 0;

    for (final inst in instances) {
      if (inst.status == 'paid' || inst.status == 'skipped') continue;
      final name = obsMap[inst.obligationId] ?? 'التزام';
      final amt = inst.amountMinor / 100;
      totalDueMinor += inst.amountMinor;

      if (inst.dueDate.compareTo(todayStr) < 0) {
        lateObs.add((name: name, amount: amt, dueDate: inst.dueDate));
      } else if (inst.dueDate.startsWith(ym)) {
        upcomingObs.add((name: name, amount: amt, dueDate: inst.dueDate));
      }
    }

    final speech = speechComposer.composeObligations(
      lateObligations: lateObs,
      upcomingObligations: upcomingObs,
      totalDueAmount: totalDueMinor / 100,
    );

    final metricChips = <String>[
      'الإجمالي: ${PluralAr.formatPounds(totalDueMinor / 100)}',
      if (lateObs.isNotEmpty) '${PluralAr.formatObligations(lateObs.length)} متأخرة',
      if (upcomingObs.isNotEmpty) '${PluralAr.formatObligations(upcomingObs.length)} قادمة',
    ];

    final details = [
      ...lateObs.map((o) => 'متأخر: ${o.name} (${PluralAr.formatPounds(o.amount)}) - مستحق ${o.dueDate}'),
      ...upcomingObs.map((o) => 'قادم: ${o.name} (${PluralAr.formatPounds(o.amount)}) - مستحق ${o.dueDate}'),
    ];

    return AnswerCardData(
      intent: intent,
      title: 'الالتزامات المالية المستحقة',
      speechText: speech,
      metricChips: metricChips,
      detailItems: details,
      navTarget: 'finance',
      navLabel: 'فتح شاشة الالتزامات في المالية',
      icon: Icons.receipt_long_rounded,
    );
  }

  // =========================================================================
  // 7. HEALTH PENDING
  // =========================================================================

  Future<AnswerCardData> _buildHealthPendingAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final allItems = await (db.select(db.healthItems)..where((h) => h.deletedAt.isNull())).get();
    final pendingItems = allItems.where((h) => h.status == 'needed' || h.status == 'postponed').toList();

    final mapped = pendingItems.map((h) {
      final dur = healthService.calculateWaitingDuration(h.neededSince, now);
      return (
        title: h.title,
        status: h.status == 'postponed' ? 'مؤجل' : 'مطلوب',
        waitingDays: dur.totalDays,
        waitingMonths: dur.months,
      );
    }).toList();

    final speech = speechComposer.composeHealthPending(items: mapped);

    final metricChips = <String>[
      PluralAr.formatCheckups(mapped.length),
    ];

    final details = mapped.map((m) {
      final durStr = m.waitingMonths > 0 ? PluralAr.formatMonths(m.waitingMonths) : PluralAr.formatDays(m.waitingDays);
      return '${m.title} [${m.status}] — ينتظر منذ $durStr';
    }).toList();

    return AnswerCardData(
      intent: intent,
      title: 'الكشوفات والتحاليل الطبية المؤجلة',
      speechText: speech,
      metricChips: metricChips,
      detailItems: details,
      navTarget: 'health',
      navLabel: 'فتح شاشة الصحة',
      icon: Icons.medical_services_rounded,
    );
  }

  // =========================================================================
  // 8. WISHLIST
  // =========================================================================

  Future<AnswerCardData> _buildWishlistAnswer(AssistantIntent intent, DateTime now, String todayStr) async {
    final allItems = await (db.select(db.wishlistItems)..where((w) => w.deletedAt.isNull())).get();
    final wantedItems = allItems.where((w) => w.status == 'wanted' || w.status == 'planned').toList();

    int totalMinor = 0;
    for (final item in wantedItems) {
      totalMinor += item.estimatedPriceMinor;
    }

    final speech = speechComposer.composeWishlist(
      itemCount: wantedItems.length,
      totalEstimatedPrice: totalMinor / 100,
    );

    final metricChips = <String>[
      PluralAr.formatItems(wantedItems.length, singular: 'عنصر', dual: 'عنصرين', plural: 'عناصر'),
      if (totalMinor > 0) 'إجمالي تقديري: ${PluralAr.formatPounds(totalMinor / 100)}',
    ];

    final details = wantedItems.map((w) {
      return '${w.name} (${PluralAr.formatPounds(w.estimatedPriceMinor / 100)})';
    }).toList();

    return AnswerCardData(
      intent: intent,
      title: 'قائمة أمنيات المشتريات (Wishlist)',
      speechText: speech,
      metricChips: metricChips,
      detailItems: details,
      navTarget: 'finance',
      navLabel: 'فتح قائمة المشتريات في المالية',
      icon: Icons.card_giftcard_rounded,
    );
  }
}
