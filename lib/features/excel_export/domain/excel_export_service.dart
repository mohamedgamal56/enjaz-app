import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/db/app_database.dart';
import '../../stats/domain/stats_service.dart';
import 'chart_image_renderer.dart';

class ExcelExportService {
  const ExcelExportService();

  /// Build and save .xlsx report to disk matching Roadmap v2.0 Round 2
  Future<File> generateReport({
    required StatsDateRange range,
    required StatsResult stats,
    required List<Task> tasks,
    required List<TaskEvent> events,
    required List<Goal> goals,
    required List<Milestone> milestones,
    required List<GoalUpdate> goalUpdates,
    required List<Idea> ideas,
    required List<VoiceNote> voiceNotes,
    List<Transaction>? transactions,
    List<FinanceCategory>? financeCategories,
    List<Obligation>? obligations,
    List<ObligationInstance>? obligationInstances,
    List<WishlistItem>? wishlistItems,
    List<Habit>? habits,
    List<HabitLog>? habitLogs,
    List<Note>? notes,
    List<HealthItem>? healthItems,
    List<HealthEvent>? healthEvents,
    List<Treatment>? treatments,
    required String languageCode, // 'ar' or 'en'
    Directory? outputDirectory,
  }) async {
    final excel = Excel.createExcel();
    final isAr = languageCode == 'ar';

    // Remove or rename default sheet to become Dashboard (First Sheet)
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    // 1. First Sheet: Dashboard / لوحة المتابعة (Roadmap v2.0 Sec 6.2)
    final dashboardName = isAr ? 'لوحة المتابعة' : 'Dashboard';
    excel.rename(defaultSheet, dashboardName);
    final dashboardSheet = excel[dashboardName];
    if (isAr) dashboardSheet.isRTL = true;
    _buildDashboardSheet(dashboardSheet, stats, range, tasks, events, isAr);

    // 2. Sheet: Summary / الملخص
    final summaryName = isAr ? 'الملخص' : 'Summary';
    final summarySheet = excel[summaryName];
    if (isAr) summarySheet.isRTL = true;
    _buildSummarySheet(summarySheet, stats, range, isAr);

    // 3. Sheet: Tasks / المهام
    final tasksName = isAr ? 'المهام' : 'Tasks';
    final tasksSheet = excel[tasksName];
    if (isAr) tasksSheet.isRTL = true;
    _buildTasksSheet(tasksSheet, tasks, events, range, goals, voiceNotes, isAr);

    // 4. Sheet: History / السجل
    final historyName = isAr ? 'السجل' : 'History';
    final historySheet = excel[historyName];
    if (isAr) historySheet.isRTL = true;
    _buildHistorySheet(historySheet, events, tasks, isAr);

    // 5. Sheet: Daily / يومي
    final dailyName = isAr ? 'يومي' : 'Daily';
    final dailySheet = excel[dailyName];
    if (isAr) dailySheet.isRTL = true;
    _buildDailySheet(dailySheet, range, tasks, events, isAr);

    // 6. Sheet: Reasons / الأسباب
    final reasonsName = isAr ? 'الأسباب' : 'Reasons';
    final reasonsSheet = excel[reasonsName];
    if (isAr) reasonsSheet.isRTL = true;
    _buildReasonsSheet(reasonsSheet, stats.topReasons, isAr);

    // 7. Sheet: Goals / الأهداف
    final goalsName = isAr ? 'الأهداف' : 'Goals';
    final goalsSheet = excel[goalsName];
    if (isAr) goalsSheet.isRTL = true;
    _buildGoalsSheet(goalsSheet, goals, milestones, goalUpdates, range, isAr);

    // 8. Sheet: Ideas / الأفكار
    final ideasName = isAr ? 'الأفكار' : 'Ideas';
    final ideasSheet = excel[ideasName];
    if (isAr) ideasSheet.isRTL = true;
    _buildIdeasSheet(ideasSheet, ideas, voiceNotes, range, isAr);

    // 9. Sheet: Transactions / المعاملات (Roadmap v2.0 Round 5)
    if (transactions != null) {
      final transactionsName = isAr ? 'المعاملات' : 'Transactions';
      final txSheet = excel[transactionsName];
      if (isAr) txSheet.isRTL = true;
      final catMap = {for (final c in (financeCategories ?? <FinanceCategory>[])) c.id: c};
      _buildTransactionsSheet(txSheet, transactions, catMap, isAr);
    }

    // 10. Sheet: Obligations / الالتزامات
    if (obligations != null && obligationInstances != null) {
      final obligationsName = isAr ? 'الالتزامات' : 'Obligations';
      final obSheet = excel[obligationsName];
      if (isAr) obSheet.isRTL = true;
      _buildObligationsSheet(obSheet, obligations, obligationInstances, isAr);
    }

    // 11. Sheet: Wishlist / المشتريات
    if (wishlistItems != null) {
      final wishlistName = isAr ? 'المشتريات' : 'Wishlist';
      final wishSheet = excel[wishlistName];
      if (isAr) wishSheet.isRTL = true;
      _buildWishlistSheet(wishSheet, wishlistItems, isAr);
    }

    // 12. Sheet: Finance summary / ملخص المال
    if (transactions != null) {
      final finSummaryName = isAr ? 'ملخص المال' : 'Finance summary';
      final finSumSheet = excel[finSummaryName];
      if (isAr) finSumSheet.isRTL = true;
      final catMap = {for (final c in (financeCategories ?? <FinanceCategory>[])) c.id: c};
      _buildFinanceSummarySheet(finSumSheet, transactions, catMap, isAr);
    }

    // 13. Sheet: Habits / العادات (Roadmap v2.0 Round 7)
    if (habits != null) {
      final habitsName = isAr ? 'العادات' : 'Habits';
      final habitSheet = excel[habitsName];
      if (isAr) habitSheet.isRTL = true;
      _buildHabitsSheet(habitSheet, habits, habitLogs ?? <HabitLog>[], isAr);
    }

    // 14. Sheet: Notes / الملاحظات (Roadmap v2.0 Round 7)
    if (notes != null) {
      final notesName = isAr ? 'الملاحظات' : 'Notes';
      final noteSheet = excel[notesName];
      if (isAr) noteSheet.isRTL = true;
      _buildNotesSheet(noteSheet, notes, isAr);
    }

    // 15. Sheet: Health / الصحة (Roadmap v2.0 Round 7)
    if (healthItems != null) {
      final healthName = isAr ? 'الصحة' : 'Health';
      final hlSheet = excel[healthName];
      if (isAr) hlSheet.isRTL = true;
      _buildHealthSheet(hlSheet, healthItems, healthEvents ?? <HealthEvent>[], treatments ?? <Treatment>[], isAr);
    }

    // Generate base Excel bytes
    final baseBytes = excel.save();
    if (baseBytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    // Prepare chart images
    List<int> finalBytes = baseBytes;
    try {
      final renderer = const ChartImageRenderer();

      // Timeline entries
      final timelineMap = <String, int>{};
      final doneEvents = events.where((e) => e.toStatus == 'done').toList();
      for (final e in doneEvents) {
        final dStr = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(e.at));
        timelineMap[dStr] = (timelineMap[dStr] ?? 0) + 1;
      }
      final sortedTimeline = timelineMap.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

      // Weekday counts (Saturday..Friday = 0..6)
      final weekdayCounts = List.filled(7, 0);
      for (final e in doneEvents) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
        final idx = (dt.weekday + 1) % 7; // Sat=0, Sun=1.. Fri=6
        weekdayCounts[idx]++;
      }

      final imgTimeline = await renderer.renderTimelineChart(entries: sortedTimeline, isAr: isAr);
      final imgStatus = await renderer.renderStatusDonutChart(statusDist: stats.statusDistribution, isAr: isAr);
      final imgReasons = await renderer.renderReasonsChart(topReasons: stats.topReasons, isAr: isAr);
      final imgWeekday = await renderer.renderWeekdayProductivityChart(weekdayCounts: weekdayCounts, isAr: isAr);

      // Embed DrawingML images and apply RTL into the xlsx archive
      finalBytes = _embedImagesInXlsx(
        xlsxBytes: baseBytes,
        images: [imgTimeline, imgStatus, imgReasons, imgWeekday],
        isAr: isAr,
      );
    } catch (e) {
      // If chart rendering fails (e.g. headless environment with no canvas), still apply RTL
      try {
        finalBytes = _embedImagesInXlsx(
          xlsxBytes: baseBytes,
          images: [],
          isAr: isAr,
        );
      } catch (_) {
        finalBytes = baseBytes;
      }
    }

    // File name: Enjaz_<range>_<start>to<end>.xlsx
    final startStr = DateFormat('yyyy-MM-dd').format(range.start);
    final endStr = DateFormat('yyyy-MM-dd').format(range.end);
    final rangeName = range.type.name.toUpperCase();
    final fileName = 'Enjaz_${rangeName}_${startStr}_to_${endStr}.xlsx';

    final outDir = outputDirectory ?? await getTemporaryDirectory();
    final file = File(p.join(outDir.path, fileName));
    await file.writeAsBytes(finalBytes, flush: true);

    return file;
  }

  // --- Sheet 1: Dashboard (لوحة المتابعة) ---
  void _buildDashboardSheet(
    Sheet sheet,
    StatsResult stats,
    StatsDateRange range,
    List<Task> tasks,
    List<TaskEvent> events,
    bool isAr,
  ) {
    final startStr = DateFormat('yyyy-MM-dd').format(range.start);
    final endStr = DateFormat('yyyy-MM-dd').format(range.end);

    // Title & Range Header
    sheet.appendRow([
      TextCellValue(isAr ? 'تطبيق إنجاز — لوحة المتابعة الشاملة' : 'Enjaz App — Executive Dashboard'),
    ]);
    sheet.appendRow([
      TextCellValue('${isAr ? 'نطاق التقرير' : 'Report Range'}: ${range.getLocalizedLabel(isAr ? 'ar' : 'en')} ($startStr - $endStr)'),
    ]);
    sheet.appendRow([
      TextCellValue('${isAr ? 'تاريخ الاستخراج' : 'Generated At'}: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
    ]);
    sheet.appendRow([]); // Empty spacer row 4

    // KPI Header Row (Row 5)
    sheet.appendRow([
      TextCellValue(isAr ? 'المهام المنجزة' : 'Completed'),
      TextCellValue(isAr ? 'نسبة الإنجاز %' : 'Completion Rate %'),
      TextCellValue(isAr ? 'المهام المؤجلة' : 'Postponed'),
      TextCellValue(isAr ? 'إنجاز جزئي' : 'Partially Done'),
      TextCellValue(isAr ? 'متوسط المدة (دقيقة)' : 'Avg Duration (min)'),
      TextCellValue(isAr ? 'أطول حماسة (أيام)' : 'Best Streak (days)'),
    ]);

    // KPI Values Row (Row 6)
    sheet.appendRow([
      IntCellValue(stats.completedCount),
      TextCellValue('${stats.completionRate.round()}%'),
      IntCellValue(stats.postponedCount),
      IntCellValue(stats.partialCount),
      DoubleCellValue(double.parse(stats.averageDurationMinutes.toStringAsFixed(1))),
      IntCellValue(stats.bestStreak),
    ]);

    sheet.appendRow([]); // Row 7
    sheet.appendRow([
      TextCellValue(isAr ? '--- المخططات البيانية التفاعلية (أدناه) ---' : '--- Graphical Visualizations (Below) ---'),
    ]); // Row 8

    // Rows 9 to 40 are reserved as the visual canvas for the 4 charts (2x2 grid)
    for (int r = 9; r <= 40; r++) {
      sheet.appendRow([]);
    }

    // Row 41: Highlights Section Header
    sheet.appendRow([
      TextCellValue(isAr ? 'جدول أبرز المؤشرات والملخص التنفيذي' : 'Executive Highlights & Key Observations'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المؤشر' : 'Metric'),
      TextCellValue(isAr ? 'القيمة' : 'Value'),
      TextCellValue(isAr ? 'الملاحظات والدلالة' : 'Notes'),
    ]);

    // Calculate highlight facts
    // Most productive weekday
    final doneEvents = events.where((e) => e.toStatus == 'done').toList();
    final weekdayCounts = List.filled(7, 0);
    for (final e in doneEvents) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
      final idx = (dt.weekday + 1) % 7;
      weekdayCounts[idx]++;
    }
    final dayNames = isAr
        ? ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة']
        : ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    int maxDayIdx = 0;
    int maxDayCount = 0;
    for (int i = 0; i < 7; i++) {
      if (weekdayCounts[i] > maxDayCount) {
        maxDayCount = weekdayCounts[i];
        maxDayIdx = i;
      }
    }
    final peakDayStr = maxDayCount > 0
        ? '${dayNames[maxDayIdx]} ($maxDayCount ${isAr ? 'مهمة' : 'tasks'})'
        : (isAr ? 'لا توجد بيانات كافية' : 'Insufficient data');

    // Top postponement reason
    final topReason = stats.topReasons.isNotEmpty ? stats.topReasons.first : null;
    final topReasonStr = topReason != null
        ? '${topReason.reason} (${topReason.count}×)'
        : (isAr ? 'لا توجد أسباب مسجلة' : 'No recorded reasons');

    final highlights = [
      [
        isAr ? 'اليوم الأكثر إنتاجية' : 'Most Productive Day',
        peakDayStr,
        isAr ? 'أعلى تركيز لإنجاز المهام في الأسبوع' : 'Day with highest task completion rate',
      ],
      [
        isAr ? 'أهم سبب للتأجيل' : 'Top Delay Reason',
        topReasonStr,
        isAr ? 'السبب الرئيسي المؤثر على تعطل المهام' : 'Primary factor leading to postponed tasks',
      ],
      [
        isAr ? 'المهام المتوقفة والمعلقة' : 'Waiting & Stopped Tasks',
        stats.waitingStoppedCount.toString(),
        isAr ? 'مهام تحتاج لمتابعة أو إزالة معوقات' : 'Tasks waiting on external factors or stopped',
      ],
      [
        isAr ? 'الحماسة الحالية (Streak)' : 'Current Streak',
        '${stats.currentStreak} ${isAr ? 'أيام متتالية' : 'consecutive days'}',
        isAr ? 'الاستمرارية الحالية في إنجاز المهام' : 'Current active streak of completed tasks',
      ],
      [
        isAr ? 'الأهداف المرتبطة المنجزة' : 'Completed Linked Goals',
        stats.goalsCompletedCount.toString(),
        isAr ? 'أهداف حياتية تم تحقيقها بالكامل' : 'Life goals achieved within this range',
      ],
      [
        isAr ? 'الأفكار المحولة إلى مشاريع' : 'Converted Ideas',
        stats.ideasConvertedCount.toString(),
        isAr ? 'أفكار ملهمة تحولت إلى مهام وأهداف تنفيذية' : 'Brainstormed ideas converted into actions',
      ],
    ];

    for (final h in highlights) {
      sheet.appendRow([
        TextCellValue(h[0]),
        TextCellValue(h[1]),
        TextCellValue(h[2]),
      ]);
    }
  }

  // --- Sheet 2: Summary ---
  void _buildSummarySheet(
    Sheet sheet,
    StatsResult stats,
    StatsDateRange range,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'المؤشر' : 'Metric'),
      TextCellValue(isAr ? 'القيمة' : 'Value'),
    ]);

    if (stats.isEmpty) {
      sheet.appendRow([
        TextCellValue(isAr ? 'ملاحظة' : 'Note'),
        TextCellValue(isAr ? 'لا توجد بيانات مسجلة في هذه الفترة' : 'No data recorded in this range'),
      ]);
      return;
    }

    final startStr = DateFormat('yyyy-MM-dd').format(range.start);
    final endStr = DateFormat('yyyy-MM-dd').format(range.end);

    final rows = [
      [isAr ? 'الفترة' : 'Range', '${range.getLocalizedLabel(isAr ? 'ar' : 'en')} ($startStr to $endStr)'],
      [isAr ? 'المهام المجدولة' : 'Scheduled Tasks', stats.scheduledCount.toString()],
      [isAr ? 'المهام المنجزة' : 'Completed Tasks', stats.completedCount.toString()],
      [isAr ? 'نسبة الإنجاز %' : 'Completion Rate %', '${stats.completionRate}%'],
      [isAr ? 'المهام المؤجلة' : 'Postponed Tasks', stats.postponedCount.toString()],
      [isAr ? 'أُنجز جزء منها' : 'Partially Done', stats.partialCount.toString()],
      [isAr ? 'منتظرة ومتوقفة' : 'Waiting & Stopped', stats.waitingStoppedCount.toString()],
      [isAr ? 'متوسط المدة (دقيقة)' : 'Avg Duration (mins)', stats.averageDurationMinutes.toString()],
      [isAr ? 'الحماسة الحالية (أيام)' : 'Current Streak (days)', stats.currentStreak.toString()],
      [isAr ? 'أفضل حماسة (أيام)' : 'Best Streak (days)', stats.bestStreak.toString()],
      [isAr ? 'أهداف مكتملة' : 'Goals Completed', stats.goalsCompletedCount.toString()],
      [isAr ? 'مراحل أهداف مكتملة' : 'Milestones Completed', stats.milestonesCompletedCount.toString()],
      [isAr ? 'أفكار جديدة' : 'Ideas Created', stats.ideasCreatedCount.toString()],
      [isAr ? 'أفكار تم تحويلها' : 'Ideas Converted', stats.ideasConvertedCount.toString()],
    ];

    for (final r in rows) {
      sheet.appendRow([
        TextCellValue(r[0]),
        TextCellValue(r[1]),
      ]);
    }
  }

  // --- Sheet 3: Tasks ---
  void _buildTasksSheet(
    Sheet sheet,
    List<Task> allTasks,
    List<TaskEvent> events,
    StatsDateRange range,
    List<Goal> goals,
    List<VoiceNote> voiceNotes,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue('id'),
      TextCellValue(isAr ? 'العنوان' : 'title'),
      TextCellValue(isAr ? 'النوع' : 'type'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue('status_key'),
      TextCellValue(isAr ? 'الأولوية' : 'priority'),
      TextCellValue('due_date'),
      TextCellValue('due_time'),
      TextCellValue('created_at'),
      TextCellValue('started_at'),
      TextCellValue('finished_at'),
      TextCellValue('duration_min'),
      TextCellValue('progress_pct'),
      TextCellValue('postpone_count'),
      TextCellValue(isAr ? 'السبب' : 'current_reason'),
      TextCellValue(isAr ? 'ملاحظة الإنجاز' : 'outcome_note'),
      TextCellValue(isAr ? 'الهدف المرتبط' : 'goal'),
      TextCellValue('voice_note_count'),
      TextCellValue('counted_as'),
    ]);

    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;
    final goalMap = {for (final g in goals) g.id: g.title};
    final eventTaskIds = events.map((e) => e.taskId).toSet();
    final isAllTime = range.type == StatsRangeType.allTime;

    // Count voice notes per task
    final vnMap = <int, int>{};
    for (final v in voiceNotes) {
      if (v.parentType == 'task') {
        vnMap[v.parentId] = (vnMap[v.parentId] ?? 0) + 1;
      }
    }

    for (final t in allTasks) {
      bool isScheduled = false;
      bool isCompleted = false;
      bool hasEvent = eventTaskIds.contains(t.id);

      // Scheduled check
      if (t.dueDate != null && t.dueDate!.isNotEmpty) {
        try {
          final due = DateTime.parse(t.dueDate!);
          final dueDay = DateTime(due.year, due.month, due.day);
          final startDay = DateTime(range.start.year, range.start.month, range.start.day);
          final endDay = DateTime(range.end.year, range.end.month, range.end.day);
          if (!dueDay.isBefore(startDay) && !dueDay.isAfter(endDay)) {
            isScheduled = true;
          }
        } catch (_) {}
      } else {
        if (t.createdAt >= startMs && t.createdAt <= endMs) {
          isScheduled = true;
        }
      }

      // Completed check
      if (t.finishedAt != null && t.finishedAt! >= startMs && t.finishedAt! <= endMs) {
        isCompleted = true;
      }

      // If not relevant to range and not all-time, skip
      if (!isScheduled && !isCompleted && !hasEvent && !isAllTime) continue;

      String countedAs = 'scheduled';
      if (isScheduled && isCompleted) {
        countedAs = 'both';
      } else if (isCompleted) {
        countedAs = 'completed';
      } else if (hasEvent) {
        countedAs = 'active_event';
      } else if (isAllTime) {
        countedAs = 'all_time';
      }

      double durationMin = 0;
      if (t.finishedAt != null && t.startedAt != null && t.finishedAt! >= t.startedAt!) {
        durationMin = double.parse(((t.finishedAt! - t.startedAt!) / (1000 * 60)).toStringAsFixed(1));
      }

      final createdStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(t.createdAt));
      final startedStr = t.startedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(t.startedAt!)) : '';
      final finishedStr = t.finishedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(t.finishedAt!)) : '';
      final goalTitle = t.goalId != null ? (goalMap[t.goalId] ?? '') : '';

      sheet.appendRow([
        IntCellValue(t.id),
        TextCellValue(t.title),
        TextCellValue(t.kind),
        TextCellValue(_translateStatus(t.status, isAr)),
        TextCellValue(t.status),
        TextCellValue(t.priority),
        TextCellValue(t.dueDate ?? ''),
        TextCellValue(t.dueTime ?? ''),
        TextCellValue(createdStr),
        TextCellValue(startedStr),
        TextCellValue(finishedStr),
        DoubleCellValue(durationMin),
        IntCellValue(t.progress),
        IntCellValue(t.postponeCount),
        TextCellValue(t.reasonText ?? ''),
        TextCellValue(t.outcomeNote ?? ''),
        TextCellValue(goalTitle),
        IntCellValue(vnMap[t.id] ?? 0),
        TextCellValue(countedAs),
      ]);
    }
  }

  // --- Sheet 4: History ---
  void _buildHistorySheet(
    Sheet sheet,
    List<TaskEvent> events,
    List<Task> tasks,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue('id'),
      TextCellValue('timestamp'),
      TextCellValue('task_id'),
      TextCellValue(isAr ? 'العنوان' : 'task_title'),
      TextCellValue(isAr ? 'من حالة' : 'from_status'),
      TextCellValue(isAr ? 'إلى حالة' : 'to_status'),
      TextCellValue('status_key'),
      TextCellValue(isAr ? 'السبب' : 'reason'),
      TextCellValue(isAr ? 'ملاحظة' : 'note'),
      TextCellValue('progress_pct'),
    ]);

    final taskMap = {for (final t in tasks) t.id: t.title};

    for (final e in events) {
      final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(e.at));
      final title = taskMap[e.taskId] ?? '#${e.taskId}';

      sheet.appendRow([
        IntCellValue(e.id),
        TextCellValue(timeStr),
        IntCellValue(e.taskId),
        TextCellValue(title),
        TextCellValue(_translateStatus(e.fromStatus, isAr)),
        TextCellValue(_translateStatus(e.toStatus, isAr)),
        TextCellValue(e.toStatus),
        TextCellValue(e.reasonText ?? ''),
        TextCellValue(e.note ?? ''),
        IntCellValue(e.progress),
      ]);
    }
  }

  // --- Sheet 5: Daily ---
  void _buildDailySheet(
    Sheet sheet,
    StatsDateRange range,
    List<Task> tasks,
    List<TaskEvent> events,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'التاريخ' : 'date'),
      TextCellValue(isAr ? 'تم إنشاؤها' : 'created'),
      TextCellValue(isAr ? 'تم إنجازها' : 'completed'),
      TextCellValue(isAr ? 'مؤجلة' : 'postponed'),
      TextCellValue(isAr ? 'جزئية' : 'partial'),
      TextCellValue(isAr ? 'متوقفة' : 'stopped'),
    ]);

    DateTime day;
    DateTime endDay;

    if (range.type == StatsRangeType.allTime) {
      // In all-time range, avoid 80-year empty iterations: bound by earliest task/event up to today
      final now = DateTime.now();
      endDay = DateTime(now.year, now.month, now.day);
      if (tasks.isEmpty && events.isEmpty) {
        day = endDay.subtract(const Duration(days: 7));
      } else {
        int minMs = now.millisecondsSinceEpoch;
        for (final t in tasks) {
          if (t.createdAt < minMs) minMs = t.createdAt;
        }
        for (final e in events) {
          if (e.at < minMs) minMs = e.at;
        }
        final minDt = DateTime.fromMillisecondsSinceEpoch(minMs);
        day = DateTime(minDt.year, minDt.month, minDt.day);
      }
    } else {
      day = DateTime(range.start.year, range.start.month, range.start.day);
      endDay = DateTime(range.end.year, range.end.month, range.end.day);
    }

    while (!day.isAfter(endDay)) {
      final dayStartMs = DateTime(day.year, day.month, day.day, 0, 0, 0).millisecondsSinceEpoch;
      final dayEndMs = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;
      final dayStr = DateFormat('yyyy-MM-dd').format(day);

      final created = tasks.where((t) => t.createdAt >= dayStartMs && t.createdAt <= dayEndMs).length;
      final completed = events.where((e) => e.toStatus == 'done' && e.at >= dayStartMs && e.at <= dayEndMs).length;
      final postponed = events.where((e) => e.toStatus == 'postponed' && e.at >= dayStartMs && e.at <= dayEndMs).length;
      final partial = events.where((e) => e.toStatus == 'partial' && e.at >= dayStartMs && e.at <= dayEndMs).length;
      final stopped = events.where((e) => (e.toStatus == 'stopped' || e.toStatus == 'waiting') && e.at >= dayStartMs && e.at <= dayEndMs).length;

      sheet.appendRow([
        TextCellValue(dayStr),
        IntCellValue(created),
        IntCellValue(completed),
        IntCellValue(postponed),
        IntCellValue(partial),
        IntCellValue(stopped),
      ]);

      day = day.add(const Duration(days: 1));
    }
  }

  // --- Sheet 6: Reasons ---
  void _buildReasonsSheet(
    Sheet sheet,
    List<ReasonCount> topReasons,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'السبب' : 'reason'),
      TextCellValue(isAr ? 'الإجمالي' : 'total'),
      TextCellValue(isAr ? 'مؤجلة' : 'postponed'),
      TextCellValue(isAr ? 'منتظرة' : 'waiting'),
      TextCellValue(isAr ? 'متوقفة' : 'stopped'),
      TextCellValue(isAr ? 'جزئية' : 'partial'),
    ]);

    for (final r in topReasons) {
      sheet.appendRow([
        TextCellValue(r.reason),
        IntCellValue(r.count),
        IntCellValue(r.postponed),
        IntCellValue(r.waiting),
        IntCellValue(r.stopped),
        IntCellValue(r.partial),
      ]);
    }
  }

  // --- Sheet 7: Goals ---
  void _buildGoalsSheet(
    Sheet sheet,
    List<Goal> goals,
    List<Milestone> milestones,
    List<GoalUpdate> updates,
    StatsDateRange range,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'عنوان الهدف' : 'title'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue('progress_pct'),
      TextCellValue('milestones_done'),
      TextCellValue('milestones_total'),
      TextCellValue('start_date'),
      TextCellValue('target_date'),
      TextCellValue('completed_at'),
      TextCellValue('progress_change_in_range'),
    ]);

    final startMs = range.start.millisecondsSinceEpoch;
    final endMs = range.end.millisecondsSinceEpoch;

    for (final g in goals) {
      final gMilestones = milestones.where((m) => m.goalId == g.id).toList();
      final doneMs = gMilestones.where((m) => m.status == 'done').length;

      int progressPct = 0;
      if (g.progressMode == 'numeric') {
        if (g.targetValue != null && g.targetValue! > 0) {
          progressPct = (((g.currentValue ?? 0) / g.targetValue!) * 100).clamp(0, 100).round();
        }
      } else {
        if (gMilestones.isNotEmpty) {
          progressPct = ((doneMs / gMilestones.length) * 100).round();
        }
      }

      final rangeUpdates = updates.where((u) => u.goalId == g.id && u.at >= startMs && u.at <= endMs).toList();
      double progressChange = 0;
      for (final u in rangeUpdates) {
        progressChange += (u.valueDelta ?? 0.0);
      }

      final createdStr = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(g.createdAt));
      final targetStr = g.targetDate ?? '';
      final completedStr = g.status == 'done'
          ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(g.updatedAt))
          : '';

      sheet.appendRow([
        TextCellValue(g.title),
        TextCellValue(g.status),
        IntCellValue(progressPct),
        IntCellValue(doneMs),
        IntCellValue(gMilestones.length),
        TextCellValue(createdStr),
        TextCellValue(targetStr),
        TextCellValue(completedStr),
        DoubleCellValue(progressChange),
      ]);
    }
  }

  // --- Sheet 8: Ideas ---
  void _buildIdeasSheet(
    Sheet sheet,
    List<Idea> ideas,
    List<VoiceNote> voiceNotes,
    StatsDateRange range,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'عنوان الفكرة' : 'title'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue(isAr ? 'الوسوم' : 'tags'),
      TextCellValue('created_at'),
      TextCellValue('converted_to'),
      TextCellValue('voice_note_count'),
    ]);

    final vnMap = <int, int>{};
    for (final v in voiceNotes) {
      if (v.parentType == 'idea') {
        vnMap[v.parentId] = (vnMap[v.parentId] ?? 0) + 1;
      }
    }

    for (final idea in ideas) {
      final createdStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(idea.createdAt));
      final convertedTo = idea.convertedType != null ? '${idea.convertedType} #${idea.convertedId}' : '';

      sheet.appendRow([
        TextCellValue(idea.title),
        TextCellValue(idea.status),
        TextCellValue(''),
        TextCellValue(createdStr),
        TextCellValue(convertedTo),
        IntCellValue(vnMap[idea.id] ?? 0),
      ]);
    }
  }

  // --- Sheet 9: Transactions ---
  void _buildTransactionsSheet(
    Sheet sheet,
    List<Transaction> transactions,
    Map<int, FinanceCategory> catMap,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'التاريخ' : 'date'),
      TextCellValue(isAr ? 'الوقت' : 'time'),
      TextCellValue(isAr ? 'النوع' : 'kind'),
      TextCellValue(isAr ? 'التصنيف' : 'category'),
      TextCellValue(isAr ? 'طبيعة الإنفاق' : 'nature'),
      TextCellValue(isAr ? 'المبلغ (ج.م)' : 'amount_egp'),
      TextCellValue(isAr ? 'طريقة الدفع' : 'payment_method'),
      TextCellValue(isAr ? 'ملاحظة' : 'note'),
    ]);

    for (final tx in transactions) {
      final dt = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
      final timeStr = DateFormat('HH:mm').format(dt);
      final cat = catMap[tx.categoryId];
      final catName = isAr ? (cat?.nameAr ?? 'أخرى') : (cat?.nameEn ?? cat?.nameAr ?? 'Other');
      final amount = tx.amountMinor / 100.0;

      sheet.appendRow([
        IntCellValue(tx.id),
        TextCellValue(tx.localDate),
        TextCellValue(timeStr),
        TextCellValue(tx.kind == 'expense' ? (isAr ? 'مصروف' : 'Expense') : (isAr ? 'دخل' : 'Income')),
        TextCellValue(catName),
        TextCellValue(tx.nature == 'essential' ? (isAr ? 'ضروري' : 'Essential') : (isAr ? 'كمالي' : 'Side')),
        DoubleCellValue(amount),
        TextCellValue(tx.paymentMethod ?? ''),
        TextCellValue(tx.note ?? ''),
      ]);
    }
  }

  // --- Sheet 10: Obligations ---
  void _buildObligationsSheet(
    Sheet sheet,
    List<Obligation> obligations,
    List<ObligationInstance> instances,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'الاسم' : 'name'),
      TextCellValue(isAr ? 'النوع' : 'kind'),
      TextCellValue(isAr ? 'المبلغ (ج.م)' : 'amount_egp'),
      TextCellValue(isAr ? 'التكرار' : 'frequency'),
      TextCellValue(isAr ? 'تاريخ/يوم الاستحقاق' : 'due_date'),
      TextCellValue(isAr ? 'الجهة المستحقة' : 'counterpart'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue(isAr ? 'تاريخ السداد' : 'paid_at'),
      TextCellValue(isAr ? 'المبلغ المسدد (ج.م)' : 'paid_amount_egp'),
    ]);

    final obMap = {for (final o in obligations) o.id: o};

    for (final inst in instances) {
      final ob = obMap[inst.obligationId];
      final amount = inst.amountMinor / 100.0;
      final paidAmount = inst.paidAmountMinor != null ? inst.paidAmountMinor! / 100.0 : 0.0;
      final paidDateStr = inst.paidAt != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(inst.paidAt!))
          : '';

      sheet.appendRow([
        IntCellValue(inst.id),
        TextCellValue(ob?.name ?? ''),
        TextCellValue(ob?.kind ?? ''),
        DoubleCellValue(amount),
        TextCellValue(ob?.frequency ?? ''),
        TextCellValue(inst.dueDate),
        TextCellValue(ob?.counterpart ?? ''),
        TextCellValue(inst.status),
        TextCellValue(paidDateStr),
        DoubleCellValue(paidAmount),
      ]);
    }
  }

  // --- Sheet 11: Wishlist ---
  void _buildWishlistSheet(
    Sheet sheet,
    List<WishlistItem> wishlist,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'اسم السلعة' : 'name'),
      TextCellValue(isAr ? 'السعر التقديري (ج.م)' : 'estimated_price_egp'),
      TextCellValue(isAr ? 'الأولوية' : 'priority'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue(isAr ? 'تاريخ الشراء' : 'bought_at'),
      TextCellValue(isAr ? 'سعر الشراء (ج.م)' : 'bought_price_egp'),
      TextCellValue(isAr ? 'ملاحظة' : 'note'),
    ]);

    for (final item in wishlist) {
      final estPrice = item.estimatedPriceMinor / 100.0;
      final boughtPrice = item.boughtPriceMinor != null ? item.boughtPriceMinor! / 100.0 : 0.0;
      final boughtDateStr = item.boughtAt != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(item.boughtAt!))
          : '';

      sheet.appendRow([
        IntCellValue(item.id),
        TextCellValue(item.name),
        DoubleCellValue(estPrice),
        TextCellValue(item.priority),
        TextCellValue(item.status),
        TextCellValue(boughtDateStr),
        DoubleCellValue(boughtPrice),
        TextCellValue(item.note ?? ''),
      ]);
    }
  }

  // --- Sheet 12: Finance summary ---
  void _buildFinanceSummarySheet(
    Sheet sheet,
    List<Transaction> transactions,
    Map<int, FinanceCategory> catMap,
    bool isAr,
  ) {
    int totalIncome = 0;
    int totalExpense = 0;
    final catTotals = <int, int>{};
    final catCounts = <int, int>{};

    for (final tx in transactions) {
      if (tx.kind == 'income') {
        totalIncome += tx.amountMinor;
      } else if (tx.kind == 'expense') {
        totalExpense += tx.amountMinor;
        catTotals[tx.categoryId] = (catTotals[tx.categoryId] ?? 0) + tx.amountMinor;
        catCounts[tx.categoryId] = (catCounts[tx.categoryId] ?? 0) + 1;
      }
    }

    final saved = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? (saved / totalIncome) * 100.0 : null;

    sheet.appendRow([
      TextCellValue(isAr ? 'مؤشرات المال العامة' : 'General Metrics'),
      TextCellValue(''),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'إجمالي الدخل (ج.م)' : 'Total Income (EGP)'),
      DoubleCellValue(totalIncome / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'إجمالي المصروفات (ج.م)' : 'Total Expenses (EGP)'),
      DoubleCellValue(totalExpense / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'صافي المدخرات (ج.م)' : 'Net Saved (EGP)'),
      DoubleCellValue(saved / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'معدل الادخار' : 'Savings Rate'),
      TextCellValue(savingsRate != null ? '${savingsRate.toStringAsFixed(1)}%' : (isAr ? 'غير متاح' : 'N/A')),
    ]);
    sheet.appendRow([TextCellValue(''), TextCellValue('')]);

    sheet.appendRow([
      TextCellValue(isAr ? 'التصنيف' : 'category'),
      TextCellValue(isAr ? 'النوع' : 'kind'),
      TextCellValue(isAr ? 'طبيعة الإنفاق' : 'nature'),
      TextCellValue(isAr ? 'المجموع (ج.م)' : 'total_egp'),
      TextCellValue(isAr ? 'عدد المعاملات' : 'count'),
      TextCellValue(isAr ? 'النسبة من المصروفات' : 'percent'),
    ]);

    for (final entry in catTotals.entries) {
      final cat = catMap[entry.key];
      final catName = isAr ? (cat?.nameAr ?? 'أخرى') : (cat?.nameEn ?? cat?.nameAr ?? 'Other');
      final pct = totalExpense > 0 ? (entry.value / totalExpense) * 100.0 : 0.0;

      sheet.appendRow([
        TextCellValue(catName),
        TextCellValue(cat?.kind ?? 'expense'),
        TextCellValue(cat?.nature ?? 'side'),
        DoubleCellValue(entry.value / 100.0),
        IntCellValue(catCounts[entry.key] ?? 0),
        TextCellValue('${pct.toStringAsFixed(1)}%'),
      ]);
    }
  }

  /// Generate transactions.csv export (Roadmap v2.0 Section 5.5)
  Future<File> generateTransactionsCsv({
    required List<Transaction> transactions,
    required List<FinanceCategory> categories,
    required Directory outputDirectory,
  }) async {
    final catMap = {for (final c in categories) c.id: c};
    final buf = StringBuffer();
    buf.writeln('id,local_date,occurred_at,kind,category_id,category_name,nature,amount_minor,amount_egp,payment_method,note');
    for (final tx in transactions) {
      final cat = catMap[tx.categoryId];
      final catName = cat?.nameAr ?? 'أخرى';
      final noteSafe = (tx.note ?? '').replaceAll('"', '""');
      final amountEgp = (tx.amountMinor / 100.0).toStringAsFixed(2);
      buf.writeln('${tx.id},"${tx.localDate}",${tx.occurredAt},"${tx.kind}",${tx.categoryId},"$catName","${tx.nature}",${tx.amountMinor},$amountEgp,"${tx.paymentMethod ?? ''}","$noteSafe"');
    }
    final file = File(p.join(outputDirectory.path, 'transactions.csv'));
    await file.writeAsString(buf.toString(), encoding: utf8);
    return file;
  }

  // --- Sheet 13: Habits (العادات) ---
  void _buildHabitsSheet(
    Sheet sheet,
    List<Habit> habits,
    List<HabitLog> logs,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? '--- قائمة العادات المعرفة ---' : '--- Defined Habits ---'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'اسم العادة' : 'name_ar'),
      TextCellValue(isAr ? 'الاسم بالإنجليزية' : 'name_en'),
      TextCellValue(isAr ? 'نوع العادة' : 'type'),
      TextCellValue(isAr ? 'الهدف اليومي' : 'daily_target'),
      TextCellValue(isAr ? 'الوحدة' : 'unit'),
      TextCellValue(isAr ? 'أيام التكرار' : 'schedule_days'),
    ]);

    for (final h in habits) {
      sheet.appendRow([
        IntCellValue(h.id),
        TextCellValue(h.nameAr),
        TextCellValue(h.nameEn ?? ''),
        TextCellValue(h.type),
        DoubleCellValue(h.dailyTarget ?? 0.0),
        TextCellValue(h.unit ?? ''),
        IntCellValue(h.scheduleDays),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(isAr ? '--- سجلات تنفيذ العادات ---' : '--- Habit Logs History ---'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'معرف السجل' : 'log_id'),
      TextCellValue(isAr ? 'معرف العادة' : 'habit_id'),
      TextCellValue(isAr ? 'اسم العادة' : 'habit_name'),
      TextCellValue(isAr ? 'التاريخ' : 'log_date'),
      TextCellValue(isAr ? 'القيمة' : 'value'),
      TextCellValue(isAr ? 'الوقت' : 'time'),
      TextCellValue(isAr ? 'الملاحظات' : 'note'),
    ]);

    final habitMap = {for (final h in habits) h.id: h};
    for (final l in logs) {
      final h = habitMap[l.habitId];
      final timeStr = DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(l.at));
      sheet.appendRow([
        IntCellValue(l.id),
        IntCellValue(l.habitId),
        TextCellValue(h?.nameAr ?? ''),
        TextCellValue(l.logDate),
        DoubleCellValue(l.value),
        TextCellValue(timeStr),
        TextCellValue(l.note ?? ''),
      ]);
    }
  }

  // --- Sheet 14: Notes (الملاحظات) ---
  void _buildNotesSheet(
    Sheet sheet,
    List<Note> notes,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'التاريخ' : 'date'),
      TextCellValue(isAr ? 'النوع' : 'kind'),
      TextCellValue(isAr ? 'العنوان' : 'title'),
      TextCellValue(isAr ? 'المحتوى' : 'body'),
      TextCellValue(isAr ? 'الوسوم' : 'tags'),
      TextCellValue(isAr ? 'مثبتة' : 'pinned'),
    ]);

    for (final n in notes) {
      sheet.appendRow([
        IntCellValue(n.id),
        TextCellValue(n.localDate ?? n.noteDate ?? ''),
        TextCellValue(n.kind),
        TextCellValue(n.title ?? ''),
        TextCellValue(n.body),
        TextCellValue(n.tags ?? ''),
        TextCellValue(n.pinned ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No')),
      ]);
    }
  }

  // --- Sheet 15: Health (الصحة) ---
  void _buildHealthSheet(
    Sheet sheet,
    List<HealthItem> items,
    List<HealthEvent> events,
    List<Treatment> treatments,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue(isAr ? '--- الفحوصات والكشوفات والتحاليل ---' : '--- Health Checkups & Tests ---'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'العنوان' : 'title'),
      TextCellValue(isAr ? 'النوع' : 'kind'),
      TextCellValue(isAr ? 'الحالة' : 'status'),
      TextCellValue(isAr ? 'مطلوب منذ' : 'needed_since'),
      TextCellValue(isAr ? 'مطلوب قبل' : 'due_by'),
      TextCellValue(isAr ? 'الموعد المجدول' : 'scheduled_at'),
      TextCellValue(isAr ? 'تاريخ الإنجاز' : 'done_at'),
      TextCellValue(isAr ? 'المكان أو الطبيب' : 'doctor_or_place'),
      TextCellValue(isAr ? 'التكلفة (ج.م)' : 'cost_egp'),
      TextCellValue(isAr ? 'الملاحظات والنتيجة' : 'result_note'),
    ]);

    for (final h in items) {
      final schedStr = h.scheduledAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(h.scheduledAt!))
          : '';
      final doneStr = h.doneAt != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(h.doneAt!))
          : '';

      sheet.appendRow([
        IntCellValue(h.id),
        TextCellValue(h.title),
        TextCellValue(h.kind),
        TextCellValue(h.status),
        TextCellValue(h.neededSince),
        TextCellValue(h.dueBy ?? ''),
        TextCellValue(schedStr),
        TextCellValue(doneStr),
        TextCellValue(h.placeOrDoctor ?? ''),
        DoubleCellValue(h.costMinor != null ? h.costMinor! / 100.0 : 0.0),
        TextCellValue(h.resultNote ?? ''),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(isAr ? '--- سجل تحديثات الحالة الصحية ---' : '--- Health Events History ---'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'معرف الفحص' : 'health_item_id'),
      TextCellValue(isAr ? 'الوقت' : 'at'),
      TextCellValue(isAr ? 'من حالة' : 'from_status'),
      TextCellValue(isAr ? 'إلى حالة' : 'to_status'),
      TextCellValue(isAr ? 'الملاحظة' : 'note'),
    ]);

    for (final e in events) {
      final atStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e.at));
      sheet.appendRow([
        IntCellValue(e.id),
        IntCellValue(e.healthItemId),
        TextCellValue(atStr),
        TextCellValue(e.fromStatus),
        TextCellValue(e.toStatus),
        TextCellValue(e.note ?? ''),
      ]);
    }

    sheet.appendRow([]);
    sheet.appendRow([
      TextCellValue(isAr ? '--- الأدوية والعلاجات ---' : '--- Treatments & Medications ---'),
    ]);
    sheet.appendRow([
      TextCellValue(isAr ? 'المعرف' : 'id'),
      TextCellValue(isAr ? 'اسم العلاج' : 'name'),
      TextCellValue(isAr ? 'حالة الالتزام' : 'adherence'),
      TextCellValue(isAr ? 'التعليمات' : 'instructions'),
      TextCellValue(isAr ? 'تاريخ البدء' : 'start_date'),
      TextCellValue(isAr ? 'تاريخ الانتهاء' : 'end_date'),
      TextCellValue(isAr ? 'تم الشراء' : 'purchased'),
      TextCellValue(isAr ? 'تكلفة الشراء (ج.م)' : 'purchase_cost_egp'),
      TextCellValue(isAr ? 'الملاحظات' : 'note'),
    ]);

    for (final t in treatments) {
      sheet.appendRow([
        IntCellValue(t.id),
        TextCellValue(t.name),
        TextCellValue(t.adherence),
        TextCellValue(t.instructionsNote ?? ''),
        TextCellValue(t.startDate),
        TextCellValue(t.endDate ?? ''),
        TextCellValue(t.purchased ? (isAr ? 'نعم' : 'Yes') : (isAr ? 'لا' : 'No')),
        DoubleCellValue(t.purchaseCostMinor != null ? t.purchaseCostMinor! / 100.0 : 0.0),
        TextCellValue(t.note ?? ''),
      ]);
    }
  }

  String _translateStatus(String st, bool isAr) {
    if (!isAr) return st;
    switch (st) {
      case 'todo':
        return 'لسه';
      case 'in_progress':
        return 'جارية';
      case 'partial':
        return 'اتعمل جزء';
      case 'done':
        return 'تمت';
      case 'postponed':
        return 'مؤجلة';
      case 'waiting':
        return 'منتظرة';
      case 'stopped':
        return 'متوقفة';
      default:
        return st;
    }
  }

  /// Inject OpenXML DrawingML artifacts, PNG chart images, and RTL direction into the generated XLSX ZIP archive
  List<int> _embedImagesInXlsx({
    required List<int> xlsxBytes,
    required List<Uint8List> images,
    required bool isAr,
  }) {
    if (images.isEmpty && !isAr) return xlsxBytes;

    final inArchive = ZipDecoder().decodeBytes(xlsxBytes);
    final outArchive = Archive();

    // Chart positioning in grid:
    // Chart 1: Row 8 to 23, Col 0 to 5 (A..F)
    // Chart 2: Row 8 to 23, Col 6 to 11 (G..L)
    // Chart 3: Row 25 to 40, Col 0 to 5 (A..F)
    // Chart 4: Row 25 to 40, Col 6 to 11 (G..L)
    final anchors = [
      (0, 8, 5, 23),
      (6, 8, 11, 23),
      (0, 25, 5, 40),
      (6, 25, 11, 40),
    ];

    for (final file in inArchive) {
      var content = file.content as List<int>;

      if (file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml') && !file.name.contains('_rels')) {
        var xmlStr = utf8.decode(content);

        // Ensure RTL view for Arabic worksheets
        if (isAr) {
          if (xmlStr.contains('<sheetView')) {
            if (xmlStr.contains('rightToLeft="0"')) {
              xmlStr = xmlStr.replaceAll('rightToLeft="0"', 'rightToLeft="1"');
            } else if (!xmlStr.contains('rightToLeft=')) {
              xmlStr = xmlStr.replaceFirst('<sheetView ', '<sheetView rightToLeft="1" ');
            }
          } else if (xmlStr.contains('<sheetData')) {
            xmlStr = xmlStr.replaceFirst(
              '<sheetData',
              '<sheetViews><sheetView workbookViewId="0" rightToLeft="1"/></sheetViews><sheetData',
            );
          }
        }

        // Add drawing link to sheet1.xml (Dashboard) if images are provided
        if (file.name == 'xl/worksheets/sheet1.xml' && images.isNotEmpty) {
          if (!xmlStr.contains('xmlns:r=')) {
            xmlStr = xmlStr.replaceFirst(
              '<worksheet ',
              '<worksheet xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" ',
            );
          }
          if (!xmlStr.contains('<drawing')) {
            xmlStr = xmlStr.replaceFirst('</worksheet>', '<drawing r:id="rIdDrawing1"/></worksheet>');
          }
        }

        content = utf8.encode(xmlStr);
      } else if (file.name == '[Content_Types].xml' && images.isNotEmpty) {
        var xmlStr = utf8.decode(content);
        if (!xmlStr.contains('Extension="png"')) {
          const overrides = '<Default Extension="png" ContentType="image/png"/>'
              '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"/>';
          xmlStr = xmlStr.replaceFirst('</Types>', '$overrides</Types>');
          content = utf8.encode(xmlStr);
        }
      }

      outArchive.addFile(ArchiveFile(file.name, content.length, content));
    }

    // 1. Add sheet1.xml.rels
    const sheet1Rels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        '  <Relationship Id="rIdDrawing1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>\n'
        '</Relationships>';
    final sheet1RelsBytes = utf8.encode(sheet1Rels);
    outArchive.addFile(ArchiveFile('xl/worksheets/_rels/sheet1.xml.rels', sheet1RelsBytes.length, sheet1RelsBytes));

    // 2. Build drawing1.xml
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sb.writeln('<xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');

    for (int i = 0; i < images.length && i < anchors.length; i++) {
      final a = anchors[i];
      final colFrom = a.$1;
      final rowFrom = a.$2;
      final colTo = a.$3;
      final rowTo = a.$4;

      sb.writeln('  <xdr:twoCellAnchor editAs="oneCell">');
      sb.writeln('    <xdr:from><xdr:col>$colFrom</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>$rowFrom</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:from>');
      sb.writeln('    <xdr:to><xdr:col>$colTo</xdr:col><xdr:colOff>0</xdr:colOff><xdr:row>$rowTo</xdr:row><xdr:rowOff>0</xdr:rowOff></xdr:to>');
      sb.writeln('    <xdr:pic>');
      sb.writeln('      <xdr:nvPicPr>');
      sb.writeln('        <xdr:cNvPr id="${i + 1}" name="EnjazChart${i + 1}"/>');
      sb.writeln('        <xdr:cNvPicPr><a:picLocks noChangeAspect="1"/></xdr:cNvPicPr>');
      sb.writeln('      </xdr:nvPicPr>');
      sb.writeln('      <xdr:blipFill>');
      sb.writeln('        <a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rIdImg${i + 1}"/>');
      sb.writeln('        <a:stretch><a:fillRect/></a:stretch>');
      sb.writeln('      </xdr:blipFill>');
      sb.writeln('      <xdr:spPr>');
      sb.writeln('        <a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/></a:xfrm>');
      sb.writeln('        <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>');
      sb.writeln('      </xdr:spPr>');
      sb.writeln('    </xdr:pic>');
      sb.writeln('    <xdr:clientData/>');
      sb.writeln('  </xdr:twoCellAnchor>');
    }
    sb.writeln('</xdr:wsDr>');

    final drawingBytes = utf8.encode(sb.toString());
    outArchive.addFile(ArchiveFile('xl/drawings/drawing1.xml', drawingBytes.length, drawingBytes));

    // 3. Build drawing1.xml.rels
    final relsSb = StringBuffer();
    relsSb.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    relsSb.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (int i = 0; i < images.length && i < anchors.length; i++) {
      relsSb.writeln('  <Relationship Id="rIdImg${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image${i + 1}.png"/>');
    }
    relsSb.writeln('</Relationships>');

    final drawingRelsBytes = utf8.encode(relsSb.toString());
    outArchive.addFile(ArchiveFile('xl/drawings/_rels/drawing1.xml.rels', drawingRelsBytes.length, drawingRelsBytes));

    // 4. Add image PNG files in xl/media/
    for (int i = 0; i < images.length && i < anchors.length; i++) {
      final imgBytes = images[i];
      outArchive.addFile(ArchiveFile('xl/media/image${i + 1}.png', imgBytes.length, imgBytes));
    }

    final encoded = ZipEncoder().encode(outArchive);
    return encoded ?? xlsxBytes;
  }
}
