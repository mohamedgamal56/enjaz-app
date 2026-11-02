import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/db/app_database.dart';
import '../../stats/domain/stats_service.dart';

class ExcelExportService {
  const ExcelExportService();

  /// Build and save .xlsx report to disk matching Addendum v1.2
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
    required String languageCode, // 'ar' or 'en'
  }) async {
    final excel = Excel.createExcel();
    final isAr = languageCode == 'ar';

    // Remove default Sheet1 later or rename
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';

    // 1. Sheet: Summary / الملخص
    final summaryName = isAr ? 'الملخص' : 'Summary';
    excel.rename(defaultSheet, summaryName);
    final summarySheet = excel[summaryName];
    if (isAr) summarySheet.isRTL = true;
    _buildSummarySheet(summarySheet, stats, range, isAr);

    // 2. Sheet: Tasks / المهام
    final tasksName = isAr ? 'المهام' : 'Tasks';
    final tasksSheet = excel[tasksName];
    if (isAr) tasksSheet.isRTL = true;
    _buildTasksSheet(tasksSheet, tasks, range, goals, voiceNotes, isAr);

    // 3. Sheet: History / السجل
    final historyName = isAr ? 'السجل' : 'History';
    final historySheet = excel[historyName];
    if (isAr) historySheet.isRTL = true;
    _buildHistorySheet(historySheet, events, tasks, isAr);

    // 4. Sheet: Daily / يومي
    final dailyName = isAr ? 'يومي' : 'Daily';
    final dailySheet = excel[dailyName];
    if (isAr) dailySheet.isRTL = true;
    _buildDailySheet(dailySheet, range, tasks, events, isAr);

    // 5. Sheet: Reasons / الأسباب
    final reasonsName = isAr ? 'الأسباب' : 'Reasons';
    final reasonsSheet = excel[reasonsName];
    if (isAr) reasonsSheet.isRTL = true;
    _buildReasonsSheet(reasonsSheet, stats.topReasons, isAr);

    // 6. Sheet: Goals / الأهداف
    final goalsName = isAr ? 'الأهداف' : 'Goals';
    final goalsSheet = excel[goalsName];
    if (isAr) goalsSheet.isRTL = true;
    _buildGoalsSheet(goalsSheet, goals, milestones, goalUpdates, range, isAr);

    // 7. Sheet: Ideas / الأفكار
    final ideasName = isAr ? 'الأفكار' : 'Ideas';
    final ideasSheet = excel[ideasName];
    if (isAr) ideasSheet.isRTL = true;
    _buildIdeasSheet(ideasSheet, ideas, voiceNotes, range, isAr);

    // Generate bytes
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Failed to generate Excel file bytes');
    }

    // File name: Enjaz_<range>_<start>to<end>.xlsx
    final startStr = DateFormat('yyyy-MM-dd').format(range.start);
    final endStr = DateFormat('yyyy-MM-dd').format(range.end);
    final rangeName = range.type.name.toUpperCase();
    final fileName = 'Enjaz_${rangeName}_${startStr}_to_${endStr}.xlsx';

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  // --- Sheet 1: Summary ---
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
        TextCellValue(isAr ? 'مفيش بيانات في دي الفترة' : 'No data in this range'),
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

  // --- Sheet 2: Tasks ---
  void _buildTasksSheet(
    Sheet sheet,
    List<Task> allTasks,
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

      if (!isScheduled && !isCompleted) continue;

      String countedAs = 'scheduled';
      if (isScheduled && isCompleted) {
        countedAs = 'both';
      } else if (isCompleted) {
        countedAs = 'completed';
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

  // --- Sheet 3: History ---
  void _buildHistorySheet(
    Sheet sheet,
    List<TaskEvent> events,
    List<Task> tasks,
    bool isAr,
  ) {
    sheet.appendRow([
      TextCellValue('event_time'),
      TextCellValue('task_id'),
      TextCellValue(isAr ? 'عنوان المهمة' : 'task_title'),
      TextCellValue(isAr ? 'من حالة' : 'from_status'),
      TextCellValue(isAr ? 'إلى حالة' : 'to_status'),
      TextCellValue('to_status_key'),
      TextCellValue(isAr ? 'السبب' : 'reason'),
      TextCellValue(isAr ? 'ملاحظة' : 'note'),
      TextCellValue('progress_pct'),
    ]);

    final taskTitleMap = {for (final t in tasks) t.id: t.title};

    for (final e in events) {
      final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(e.at));
      final title = taskTitleMap[e.taskId] ?? 'Task #${e.taskId}';

      sheet.appendRow([
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

  // --- Sheet 4: Daily ---
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

    // Iterate through every single day in the range
    DateTime day = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day);

    while (!day.isAfter(endDay)) {
      final dayStartMs = DateTime(day.year, day.month, day.day, 0, 0, 0).millisecondsSinceEpoch;
      final dayEndMs = DateTime(day.year, day.month, day.day, 23, 59, 59, 999).millisecondsSinceEpoch;
      final dayStr = DateFormat('yyyy-MM-dd').format(day);

      // Created on this day
      final created = tasks.where((t) => t.createdAt >= dayStartMs && t.createdAt <= dayEndMs).length;

      // Completed on this day
      final completed = events.where((e) => e.toStatus == 'done' && e.at >= dayStartMs && e.at <= dayEndMs).length;

      // Postponed on this day
      final postponed = events.where((e) => e.toStatus == 'postponed' && e.at >= dayStartMs && e.at <= dayEndMs).length;

      // Partial on this day
      final partial = events.where((e) => e.toStatus == 'partial' && e.at >= dayStartMs && e.at <= dayEndMs).length;

      // Stopped on this day
      final stopped = events.where((e) => e.toStatus == 'stopped' && e.at >= dayStartMs && e.at <= dayEndMs).length;

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

  // --- Sheet 5: Reasons ---
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

  // --- Sheet 6: Goals ---
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

      // Progress calculation
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

      // Progress delta in range
      final rangeUpdates = updates.where((u) => u.goalId == g.id && u.at >= startMs && u.at <= endMs).toList();
      double progressChange = 0;
      for (final u in rangeUpdates) {
        progressChange += u.delta;
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

  // --- Sheet 7: Ideas ---
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
        TextCellValue(idea.tags ?? ''),
        TextCellValue(createdStr),
        TextCellValue(convertedTo),
        IntCellValue(vnMap[idea.id] ?? 0),
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
}
