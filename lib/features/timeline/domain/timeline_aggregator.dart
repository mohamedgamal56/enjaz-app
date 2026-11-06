import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import 'timeline_models.dart';

/// Aggregator service that collects, converts, and merges timeline events
/// across all modules without duplicating records in a separate table.
class TimelineAggregator {
  final AppDatabase db;

  const TimelineAggregator(this.db);

  /// Retrieves chronological entries and day summary for a single local calendar day.
  /// Performance target: day opens in under 300 ms.
  Future<(List<TimelineEntry>, TimelineDaySummary)> getTimelineForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = endOfDay.millisecondsSinceEpoch;
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final isFuture = dateStr.compareTo(todayStr) > 0;

    final entries = <TimelineEntry>[];

    // Day summary accumulators
    int tasksDoneCount = 0;
    int expensesMinor = 0;
    int incomeMinor = 0;
    int habitsDoneCount = 0;
    int notesCount = 0;
    int ideasCount = 0;

    // ------------------------------------------------------------------
    // FUTURE DAYS: Only planned items (Tasks due, Obligations due, Appointments)
    // ------------------------------------------------------------------
    if (isFuture) {
      // 1. Tasks due on this day
      final allTasks = await db.getAllActiveTasks();
      for (final t in allTasks) {
        if (t.dueDate == dateStr) {
          final isTimed = t.dueTime != null && t.dueTime!.isNotEmpty;
          int entryTime = startMs;
          if (isTimed) {
            final parts = t.dueTime!.split(':');
            if (parts.length >= 2) {
              final h = int.tryParse(parts[0]) ?? 0;
              final m = int.tryParse(parts[1]) ?? 0;
              entryTime = DateTime(day.year, day.month, day.day, h, m).millisecondsSinceEpoch;
            }
          }
          entries.add(
            TimelineEntry(
              id: 'future_task_${t.id}',
              module: TimelineModule.task,
              occurredAt: entryTime,
              localDate: dateStr,
              allDay: !isTimed,
              timeStr: isTimed ? t.dueTime : null,
              title: t.title,
              subtitle: t.notes?.isNotEmpty == true ? t.notes : 'مهمة مجدولة',
              icon: Icons.assignment_outlined,
              color: TimelineModule.task.color,
              statusBadge: 'مجدولة',
              sourceType: 'task',
              sourceId: t.id,
              isFuturePlanned: true,
            ),
          );
        }
      }

      // 2. Obligations due on this day
      final obligationInstances = await db.getObligationInstancesForRange(dateStr, dateStr);
      final allObligations = await db.getAllObligations();
      final obMap = {for (final o in allObligations) o.id: o};

      for (final inst in obligationInstances) {
        if (inst.status == 'pending') {
          final parent = obMap[inst.obligationId];
          final title = parent?.name ?? 'التزام مالي';
          final amountEgp = (inst.amountMinor / 100.0).toStringAsFixed(2);
          entries.add(
            TimelineEntry(
              id: 'future_ob_${inst.id}',
              module: TimelineModule.finance,
              occurredAt: startMs + (10 * 3600 * 1000), // Default 10:00 AM
              localDate: dateStr,
              allDay: true,
              timeStr: null,
              title: title,
              subtitle: 'مستحق: $amountEgp ج.م',
              icon: Icons.receipt_long_rounded,
              color: TimelineModule.finance.color,
              statusBadge: 'مستحق',
              sourceType: 'obligation',
              sourceId: inst.id,
              isFuturePlanned: true,
            ),
          );
        }
      }

      // 3. Health items scheduled or due on this day
      final healthItems = await db.getAllActiveHealthItems();
      for (final h in healthItems) {
        if (h.scheduledAt != null) {
          final schedDate = DateTime.fromMillisecondsSinceEpoch(h.scheduledAt!);
          final schedDateStr = DateFormat('yyyy-MM-dd').format(schedDate);
          if (schedDateStr == dateStr) {
            entries.add(
              TimelineEntry(
                id: 'future_health_${h.id}',
                module: TimelineModule.health,
                occurredAt: h.scheduledAt!,
                localDate: dateStr,
                allDay: false,
                timeStr: DateFormat('HH:mm').format(schedDate),
                title: h.title,
                subtitle: h.placeOrDoctor != null ? 'المكان: ${h.placeOrDoctor}' : 'موعد طبي مجدول',
                icon: Icons.calendar_today_rounded,
                color: TimelineModule.health.color,
                statusBadge: 'موعد مجدول',
                sourceType: 'health_item',
                sourceId: h.id,
                isFuturePlanned: true,
              ),
            );
          }
        } else if (h.dueBy == dateStr) {
          entries.add(
            TimelineEntry(
              id: 'future_health_due_${h.id}',
              module: TimelineModule.health,
              occurredAt: startMs,
              localDate: dateStr,
              allDay: true,
              timeStr: null,
              title: h.title,
              subtitle: 'فحص مطلوب قبل هذا التاريخ',
              icon: Icons.alarm_rounded,
              color: TimelineModule.health.color,
              statusBadge: 'مطلوب',
              sourceType: 'health_item',
              sourceId: h.id,
              isFuturePlanned: true,
            ),
          );
        }
      }

      // Sort future entries: all-day first, then by time
      entries.sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return a.occurredAt.compareTo(b.occurredAt);
      });

      return (entries, const TimelineDaySummary());
    }

    // ------------------------------------------------------------------
    // PAST & TODAY: Full Chronological Timeline
    // ------------------------------------------------------------------

    // 1. TASK EVENTS (State transitions: created, started, done, postponed)
    final events = await db.getEventsForRange(startOfDay, endOfDay);
    final allTasks = await db.getAllActiveTasks();
    final tasksMap = {for (final t in allTasks) t.id: t};

    for (final e in events) {
      final task = tasksMap[e.taskId];
      final title = task?.title ?? 'مهمة';
      final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
      final timeStr = DateFormat('HH:mm').format(dt);

      String badge = e.toStatus;
      String desc = '';
      if (e.toStatus == 'done') {
        badge = 'منجزة';
        tasksDoneCount++;
      } else if (e.toStatus == 'in_progress') {
        badge = 'بدأت';
      } else if (e.toStatus == 'postponed') {
        badge = 'مؤجلة';
        desc = e.reasonText != null ? 'السبب: ${e.reasonText}' : '';
      } else if (e.toStatus == 'todo') {
        badge = 'أنشئت';
      }

      entries.add(
        TimelineEntry(
          id: 'event_${e.id}',
          module: TimelineModule.task,
          occurredAt: e.at,
          localDate: dateStr,
          allDay: false,
          timeStr: timeStr,
          title: title,
          subtitle: desc.isNotEmpty ? desc : (e.note ?? 'تحديث حالة المهمة'),
          icon: e.toStatus == 'done' ? Icons.check_circle_rounded : Icons.task_alt_rounded,
          color: TimelineModule.task.color,
          statusBadge: badge,
          sourceType: 'task',
          sourceId: e.taskId,
        ),
      );
    }

    // Also include tasks scheduled today if they have no events yet
    for (final t in allTasks) {
      if (t.dueDate == dateStr && !events.any((e) => e.taskId == t.id)) {
        final isTimed = t.dueTime != null && t.dueTime!.isNotEmpty;
        int tTime = startMs;
        if (isTimed) {
          final parts = t.dueTime!.split(':');
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 0;
            final m = int.tryParse(parts[1]) ?? 0;
            tTime = DateTime(day.year, day.month, day.day, h, m).millisecondsSinceEpoch;
          }
        }

        if (t.status == 'done') tasksDoneCount++;

        entries.add(
          TimelineEntry(
            id: 'task_${t.id}',
            module: TimelineModule.task,
            occurredAt: tTime,
            localDate: dateStr,
            allDay: !isTimed,
            timeStr: isTimed ? t.dueTime : null,
            title: t.title,
            subtitle: t.notes?.isNotEmpty == true ? t.notes : 'مهمة مخصصة لليوم',
            icon: Icons.assignment_rounded,
            color: TimelineModule.task.color,
            statusBadge: t.status == 'done' ? 'منجزة' : 'اليوم',
            sourceType: 'task',
            sourceId: t.id,
          ),
        );
      }
    }

    // 2. HABITS: Habit Logs & Habit Item Logs
    final habitLogs = await db.getAllHabitLogsForRange(dateStr, dateStr);
    final habitItemLogs = await db.getAllHabitItemLogsForRange(dateStr, dateStr);
    final habits = await db.getAllActiveHabits();
    final habitMap = {for (final h in habits) h.id: h};

    for (final hl in habitLogs) {
      final habit = habitMap[hl.habitId];
      final title = habit?.nameAr ?? 'عادة يومية';
      final dt = DateTime.fromMillisecondsSinceEpoch(hl.at);
      final timeStr = DateFormat('HH:mm').format(dt);
      habitsDoneCount++;

      final unitStr = habit?.unit ?? '';
      final valStr = hl.value == hl.value.roundToDouble()
          ? hl.value.toInt().toString()
          : hl.value.toStringAsFixed(1);
      final subtitle = unitStr.isNotEmpty ? '$valStr $unitStr' : (hl.note ?? 'تم تسجيل العادة');

      entries.add(
        TimelineEntry(
          id: 'habit_log_${hl.id}',
          module: TimelineModule.habit,
          occurredAt: hl.at,
          localDate: dateStr,
          allDay: false,
          timeStr: timeStr,
          title: title,
          subtitle: subtitle,
          icon: Icons.repeat_rounded,
          color: TimelineModule.habit.color,
          statusBadge: 'عادة مكتملة',
          sourceType: 'habit',
          sourceId: hl.habitId,
        ),
      );
    }

    for (final hil in habitItemLogs) {
      final habit = habitMap[hil.habitId];
      final dt = DateTime.fromMillisecondsSinceEpoch(hil.doneAt);
      final timeStr = DateFormat('HH:mm').format(dt);
      habitsDoneCount++;

      entries.add(
        TimelineEntry(
          id: 'habit_item_log_${hil.id}',
          module: TimelineModule.habit,
          occurredAt: hil.doneAt,
          localDate: dateStr,
          allDay: false,
          timeStr: timeStr,
          title: habit?.nameAr ?? 'عنصر في العادة',
          subtitle: 'تم إنجاز بند من العادة',
          icon: Icons.check_circle_outline_rounded,
          color: TimelineModule.habit.color,
          statusBadge: 'إنجاز',
          sourceType: 'habit',
          sourceId: hil.habitId,
        ),
      );
    }

    // 3. FINANCE: Transactions & Obligations
    final transactions = await db.getTransactionsForRange(dateStr, dateStr);
    final categories = await db.getAllFinanceCategories();
    final catMap = {for (final c in categories) c.id: c};

    for (final tx in transactions) {
      final dt = DateTime.fromMillisecondsSinceEpoch(tx.occurredAt);
      final timeStr = DateFormat('HH:mm').format(dt);
      final cat = catMap[tx.categoryId];
      final catName = cat?.nameAr ?? (tx.kind == 'expense' ? 'مصروف' : 'دخل');
      final amountEgp = (tx.amountMinor / 100.0).toStringAsFixed(2);

      if (tx.kind == 'expense') {
        expensesMinor += tx.amountMinor;
      } else {
        incomeMinor += tx.amountMinor;
      }

      final isExp = tx.kind == 'expense';
      final formattedAmount = '${isExp ? '-' : '+'}$amountEgp ج.م';

      entries.add(
        TimelineEntry(
          id: 'tx_${tx.id}',
          module: TimelineModule.finance,
          occurredAt: tx.occurredAt,
          localDate: dateStr,
          allDay: false,
          timeStr: timeStr,
          title: '$catName ($formattedAmount)',
          subtitle: tx.note?.isNotEmpty == true ? tx.note : (isExp ? 'مصروف مسجل' : 'دخل مسجل'),
          icon: isExp ? Icons.trending_down_rounded : Icons.trending_up_rounded,
          color: isExp ? Colors.redAccent : Colors.green,
          statusBadge: isExp ? 'مصروف' : 'دخل',
          sourceType: 'transaction',
          sourceId: tx.id,
        ),
      );
    }

    // Obligations paid or due today
    final obligationInstances = await db.getObligationInstancesForRange(dateStr, dateStr);
    final allObligations = await db.getAllObligations();
    final obMap = {for (final o in allObligations) o.id: o};

    for (final inst in obligationInstances) {
      final parent = obMap[inst.obligationId];
      final title = parent?.name ?? 'التزام';
      final amountEgp = (inst.amountMinor / 100.0).toStringAsFixed(2);

      if (inst.status == 'paid' && inst.paidAt != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(inst.paidAt!);
        entries.add(
          TimelineEntry(
            id: 'ob_paid_${inst.id}',
            module: TimelineModule.finance,
            occurredAt: inst.paidAt!,
            localDate: dateStr,
            allDay: false,
            timeStr: DateFormat('HH:mm').format(dt),
            title: '$title ($amountEgp ج.م)',
            subtitle: 'تم سداد الالتزام بنجاح',
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            statusBadge: 'مدفوع',
            sourceType: 'obligation',
            sourceId: inst.id,
          ),
        );
      } else if (inst.status == 'pending') {
        entries.add(
          TimelineEntry(
            id: 'ob_due_${inst.id}',
            module: TimelineModule.finance,
            occurredAt: startMs + (9 * 3600 * 1000),
            localDate: dateStr,
            allDay: true,
            timeStr: null,
            title: '$title ($amountEgp ج.م)',
            subtitle: 'مستحق الدفع اليوم',
            icon: Icons.receipt_long_rounded,
            color: Colors.orange,
            statusBadge: 'مستحق',
            sourceType: 'obligation',
            sourceId: inst.id,
          ),
        );
      }
    }

    // 4. HEALTH: Items, Events & Treatments
    final healthEvents = await db.getHealthEventsForRange(startMs, endMs);
    final activeHealthItems = await db.getAllActiveHealthItems();
    final healthMap = {for (final h in activeHealthItems) h.id: h};

    for (final he in healthEvents) {
      final hItem = healthMap[he.healthItemId];
      final title = hItem?.title ?? 'متابعة صحية';
      final dt = DateTime.fromMillisecondsSinceEpoch(he.at);
      final timeStr = DateFormat('HH:mm').format(dt);

      String badge = he.toStatus;
      if (he.toStatus == 'done') badge = 'فحص منجز';
      if (he.toStatus == 'scheduled') badge = 'موعد محدد';
      if (he.toStatus == 'postponed') badge = 'مؤجل';

      entries.add(
        TimelineEntry(
          id: 'health_ev_${he.id}',
          module: TimelineModule.health,
          occurredAt: he.at,
          localDate: dateStr,
          allDay: false,
          timeStr: timeStr,
          title: title,
          subtitle: he.note?.isNotEmpty == true ? he.note : 'تحديث الحالة الصحية',
          icon: Icons.favorite_rounded,
          color: TimelineModule.health.color,
          statusBadge: badge,
          sourceType: 'health_item',
          sourceId: he.healthItemId,
        ),
      );
    }

    // Checkups done or scheduled today
    for (final h in activeHealthItems) {
      if (h.doneAt != null && h.status == 'done') {
        final dDate = DateTime.fromMillisecondsSinceEpoch(h.doneAt!);
        if (DateFormat('yyyy-MM-dd').format(dDate) == dateStr &&
            !healthEvents.any((he) => he.healthItemId == h.id && he.toStatus == 'done')) {
          entries.add(
            TimelineEntry(
              id: 'health_done_${h.id}',
              module: TimelineModule.health,
              occurredAt: h.doneAt!,
              localDate: dateStr,
              allDay: false,
              timeStr: DateFormat('HH:mm').format(dDate),
              title: h.title,
              subtitle: h.resultNote?.isNotEmpty == true ? h.resultNote : 'تم إجراء الفحص بنجاح',
              icon: Icons.health_and_safety_rounded,
              color: TimelineModule.health.color,
              statusBadge: 'فحص منجز',
              sourceType: 'health_item',
              sourceId: h.id,
            ),
          );
        }
      }
    }

    // Treatment checks today
    final treatmentChecks = await db.getAllTreatmentChecksForRange(dateStr, dateStr);
    if (treatmentChecks.isNotEmpty) {
      entries.add(
        TimelineEntry(
          id: 'treatment_checks_$dateStr',
          module: TimelineModule.health,
          occurredAt: startMs + (12 * 3600 * 1000), // Midday
          localDate: dateStr,
          allDay: true,
          timeStr: null,
          title: 'الالتزام بالأدوية والعلاج',
          subtitle: 'تم تناول جرعات اليوم (${treatmentChecks.length} أدوية)',
          icon: Icons.medication_rounded,
          color: TimelineModule.health.color,
          statusBadge: 'أدوية اليوم',
          sourceType: 'treatment',
          sourceId: treatmentChecks.first.treatmentId,
        ),
      );
    }

    // 5. NOTES: Written or dated today
    final notes = await db.getAllActiveNotes();
    for (final n in notes) {
      bool isMatch = false;
      int noteTime = startMs;

      if (n.localDate == dateStr || n.noteDate == dateStr) {
        isMatch = true;
        if (n.occurredAt != null) noteTime = n.occurredAt!;
      } else if (n.createdAt >= startMs && n.createdAt <= endMs) {
        isMatch = true;
        noteTime = n.createdAt;
      }

      if (isMatch) {
        notesCount++;
        final dt = DateTime.fromMillisecondsSinceEpoch(noteTime);
        final title = n.title?.isNotEmpty == true ? n.title! : 'ملاحظة يومية';

        entries.add(
          TimelineEntry(
            id: 'note_${n.id}',
            module: TimelineModule.note,
            occurredAt: noteTime,
            localDate: dateStr,
            allDay: n.occurredAt == null,
            timeStr: n.occurredAt != null ? DateFormat('HH:mm').format(dt) : null,
            title: title,
            subtitle: n.body.length > 80 ? '${n.body.substring(0, 80)}...' : n.body,
            icon: Icons.note_alt_rounded,
            color: TimelineModule.note.color,
            statusBadge: n.kind == 'quote' ? 'اقتباس' : (n.kind == 'info' ? 'معلومة' : 'ملاحظة'),
            sourceType: 'note',
            sourceId: n.id,
          ),
        );
      }
    }

    // 6. IDEAS: Created today
    final ideas = await db.getAllIdeasList();
    for (final idea in ideas) {
      if (idea.createdAt >= startMs && idea.createdAt <= endMs) {
        ideasCount++;
        final dt = DateTime.fromMillisecondsSinceEpoch(idea.createdAt);
        entries.add(
          TimelineEntry(
            id: 'idea_${idea.id}',
            module: TimelineModule.idea,
            occurredAt: idea.createdAt,
            localDate: dateStr,
            allDay: false,
            timeStr: DateFormat('HH:mm').format(dt),
            title: idea.title,
            subtitle: idea.description?.isNotEmpty == true ? idea.description : 'فكرة جديدة مدونة',
            icon: Icons.lightbulb_rounded,
            color: TimelineModule.idea.color,
            statusBadge: 'فكرة جديدة',
            sourceType: 'idea',
            sourceId: idea.id,
          ),
        );
      }
    }

    // 7. GOALS: Created, completed or milestones completed today
    final goals = await db.getAllGoalsList();
    for (final g in goals) {
      if (g.completedAt != null && g.completedAt! >= startMs && g.completedAt! <= endMs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(g.completedAt!);
        entries.add(
          TimelineEntry(
            id: 'goal_done_${g.id}',
            module: TimelineModule.goal,
            occurredAt: g.completedAt!,
            localDate: dateStr,
            allDay: false,
            timeStr: DateFormat('HH:mm').format(dt),
            title: g.title,
            subtitle: 'تم تحقيق الهدف بنجاح! 🎉',
            icon: Icons.flag_rounded,
            color: TimelineModule.goal.color,
            statusBadge: 'هدف منجز',
            sourceType: 'goal',
            sourceId: g.id,
          ),
        );
      }
    }

    final milestones = await db.getAllMilestonesList();
    for (final m in milestones) {
      if (m.completedAt != null && m.completedAt! >= startMs && m.completedAt! <= endMs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(m.completedAt!);
        entries.add(
          TimelineEntry(
            id: 'milestone_${m.id}',
            module: TimelineModule.goal,
            occurredAt: m.completedAt!,
            localDate: dateStr,
            allDay: false,
            timeStr: DateFormat('HH:mm').format(dt),
            title: m.title,
            subtitle: 'تم إنجاز مرحلة من الهدف',
            icon: Icons.stars_rounded,
            color: TimelineModule.goal.color,
            statusBadge: 'مرحلة هدف',
            sourceType: 'goal',
            sourceId: m.goalId,
          ),
        );
      }
    }

    // 8. VOICE NOTES: Recorded today
    final voiceNotes = await db.getAllVoiceNotesList();
    for (final vn in voiceNotes) {
      if (vn.recordedAt >= startMs && vn.recordedAt <= endMs) {
        final dt = DateTime.fromMillisecondsSinceEpoch(vn.recordedAt);
        final title = vn.label?.isNotEmpty == true ? vn.label! : 'تسجيل صوتي';
        final durSec = (vn.durationMs / 1000).round();
        final durStr = '${(durSec ~/ 60).toString().padLeft(2, '0')}:${(durSec % 60).toString().padLeft(2, '0')}';

        TimelineModule vMod = TimelineModule.task;
        if (vn.parentType == 'health_item') vMod = TimelineModule.health;
        if (vn.parentType == 'idea') vMod = TimelineModule.idea;
        if (vn.parentType == 'goal') vMod = TimelineModule.goal;

        entries.add(
          TimelineEntry(
            id: 'voice_${vn.id}',
            module: vMod,
            occurredAt: vn.recordedAt,
            localDate: dateStr,
            allDay: false,
            timeStr: DateFormat('HH:mm').format(dt),
            title: title,
            subtitle: 'المدة: $durStr دقيقة',
            icon: Icons.mic_rounded,
            color: vMod.color,
            hasVoice: true,
            voiceFileName: vn.fileName,
            statusBadge: 'تسجيل صوتي',
            sourceType: vn.parentType,
            sourceId: vn.parentId,
          ),
        );
      }
    }

    // Sort entries: All-day at the top, then by occurredAt ASC
    entries.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.occurredAt.compareTo(b.occurredAt);
    });

    final summary = TimelineDaySummary(
      tasksDoneCount: tasksDoneCount,
      expensesMinor: expensesMinor,
      incomeMinor: incomeMinor,
      habitsDoneCount: habitsDoneCount,
      notesCount: notesCount,
      ideasCount: ideasCount,
    );

    return (entries, summary);
  }

  /// Fast month query: Returns map of YYYY-MM-DD -> Set of TimelineModules with activity.
  /// Performance target: under 500 ms.
  Future<Map<String, Set<TimelineModule>>> getModuleDotsForMonth(int year, int month) async {
    final start = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final end = DateTime(year, month, daysInMonth, 23, 59, 59, 999);

    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    final result = <String, Set<TimelineModule>>{};

    void addDot(String ymd, TimelineModule mod) {
      result.putIfAbsent(ymd, () => <TimelineModule>{}).add(mod);
    }

    // 1. Tasks: Task events in range + scheduled tasks
    final events = await db.getEventsForRange(start, end);
    for (final e in events) {
      final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(e.at));
      addDot(ymd, TimelineModule.task);
    }

    final allTasks = await db.getAllActiveTasks();
    for (final t in allTasks) {
      if (t.dueDate != null && t.dueDate!.compareTo(startStr) >= 0 && t.dueDate!.compareTo(endStr) <= 0) {
        addDot(t.dueDate!, TimelineModule.task);
      }
    }

    // 2. Habits: Habit logs in range
    final habitLogs = await db.getAllHabitLogsForRange(startStr, endStr);
    for (final hl in habitLogs) {
      addDot(hl.logDate, TimelineModule.habit);
    }

    // 3. Finance: Transactions in range
    final transactions = await db.getTransactionsForRange(startStr, endStr);
    for (final tx in transactions) {
      addDot(tx.localDate, TimelineModule.finance);
    }

    // 4. Health: Health items & events in range
    final healthItems = await db.getAllActiveHealthItems();
    for (final h in healthItems) {
      if (h.doneAt != null && h.doneAt! >= startMs && h.doneAt! <= endMs) {
        final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(h.doneAt!));
        addDot(ymd, TimelineModule.health);
      }
      if (h.scheduledAt != null && h.scheduledAt! >= startMs && h.scheduledAt! <= endMs) {
        final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(h.scheduledAt!));
        addDot(ymd, TimelineModule.health);
      }
    }

    // 5. Notes in range
    final notes = await db.getAllActiveNotes();
    for (final n in notes) {
      if (n.localDate != null && n.localDate!.compareTo(startStr) >= 0 && n.localDate!.compareTo(endStr) <= 0) {
        addDot(n.localDate!, TimelineModule.note);
      } else if (n.noteDate != null && n.noteDate!.compareTo(startStr) >= 0 && n.noteDate!.compareTo(endStr) <= 0) {
        addDot(n.noteDate!, TimelineModule.note);
      } else if (n.createdAt >= startMs && n.createdAt <= endMs) {
        final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(n.createdAt));
        addDot(ymd, TimelineModule.note);
      }
    }

    // 6. Ideas in range
    final ideas = await db.getAllIdeasList();
    for (final idea in ideas) {
      if (idea.createdAt >= startMs && idea.createdAt <= endMs) {
        final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(idea.createdAt));
        addDot(ymd, TimelineModule.idea);
      }
    }

    // 7. Goals in range
    final goals = await db.getAllGoalsList();
    for (final g in goals) {
      if (g.completedAt != null && g.completedAt! >= startMs && g.completedAt! <= endMs) {
        final ymd = DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(g.completedAt!));
        addDot(ymd, TimelineModule.goal);
      }
    }

    return result;
  }

  /// Activity count per month for Year View (1..12 -> count)
  Future<Map<int, int>> getYearActivityDensity(int year) async {
    final counts = <int, int>{};
    for (int m = 1; m <= 12; m++) {
      counts[m] = 0;
    }

    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31, 23, 59, 59, 999);
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    // Count tasks
    final events = await db.getEventsForRange(start, end);
    for (final e in events) {
      final dt = DateTime.fromMillisecondsSinceEpoch(e.at);
      if (dt.year == year) counts[dt.month] = (counts[dt.month] ?? 0) + 1;
    }

    // Count habits
    final habitLogs = await db.getAllHabitLogsForRange(startStr, endStr);
    for (final hl in habitLogs) {
      final m = int.tryParse(hl.logDate.split('-')[1]) ?? 1;
      counts[m] = (counts[m] ?? 0) + 1;
    }

    // Count transactions
    final transactions = await db.getTransactionsForRange(startStr, endStr);
    for (final tx in transactions) {
      final m = int.tryParse(tx.localDate.split('-')[1]) ?? 1;
      counts[m] = (counts[m] ?? 0) + 1;
    }

    return counts;
  }

  /// Calculates headline overview metrics across all modules for the selected range
  Future<TimelineOverviewSummary> getOverviewSummary(DateTime start, DateTime end) async {
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    // 1. Tasks done count
    final events = await db.getEventsForRange(start, end);
    final tasksDone = events.where((e) => e.toStatus == 'done').map((e) => e.taskId).toSet().length;

    // 2. Finance: total expenses, income, top category
    final transactions = await db.getTransactionsForRange(startStr, endStr);
    int totalExpensesMinor = 0;
    int totalIncomeMinor = 0;
    final catExpenses = <int, int>{};

    for (final tx in transactions) {
      if (tx.kind == 'expense') {
        totalExpensesMinor += tx.amountMinor;
        catExpenses[tx.categoryId] = (catExpenses[tx.categoryId] ?? 0) + tx.amountMinor;
      } else {
        totalIncomeMinor += tx.amountMinor;
      }
    }

    String? topCategory;
    int topAmount = 0;
    if (catExpenses.isNotEmpty) {
      final sortedCats = catExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topCatId = sortedCats.first.key;
      topAmount = sortedCats.first.value;

      final categories = await db.getAllFinanceCategories();
      final cat = categories.where((c) => c.id == topCatId).firstOrNull;
      topCategory = cat?.nameAr ?? 'أخرى';
    }

    // 3. Habits completion rate
    final habitLogs = await db.getAllHabitLogsForRange(startStr, endStr);
    final allHabits = await db.getAllActiveHabits();
    double habitsRate = 0.0;
    if (allHabits.isNotEmpty) {
      final daysDiff = end.difference(start).inDays + 1;
      final totalPossible = allHabits.length * daysDiff;
      if (totalPossible > 0) {
        habitsRate = (habitLogs.length / totalPossible.toDouble()) * 100.0;
        if (habitsRate > 100.0) habitsRate = 100.0;
      }
    }

    // 4. Notes count
    final notes = await db.getAllActiveNotes();
    int notesCount = 0;
    for (final n in notes) {
      if (n.localDate != null && n.localDate!.compareTo(startStr) >= 0 && n.localDate!.compareTo(endStr) <= 0) {
        notesCount++;
      } else if (n.createdAt >= startMs && n.createdAt <= endMs) {
        notesCount++;
      }
    }

    // 5. Goals progress average
    final goals = await db.getAllActiveGoals();
    double goalProgressAvg = 0.0;
    if (goals.isNotEmpty) {
      final milestones = await db.getAllMilestonesList();
      double totalProg = 0.0;
      for (final g in goals) {
        if (g.progressMode == 'numeric') {
          final cur = g.currentValue ?? 0.0;
          final tar = g.targetValue ?? 1.0;
          totalProg += tar > 0 ? (cur / tar * 100.0).clamp(0.0, 100.0) : 0.0;
        } else {
          final gMilestones = milestones.where((m) => m.goalId == g.id).toList();
          if (gMilestones.isEmpty) {
            totalProg += 0.0;
          } else {
            final doneW = gMilestones.where((m) => m.status == 'done').fold<int>(0, (s, m) => s + m.weight);
            final totalW = gMilestones.fold<int>(0, (s, m) => s + m.weight);
            totalProg += totalW > 0 ? (doneW / totalW * 100.0) : 0.0;
          }
        }
      }
      goalProgressAvg = totalProg / goals.length;
    }

    // 6. Health items done
    final healthItems = await db.getAllActiveHealthItems();
    final healthDone = healthItems.where((h) =>
        h.status == 'done' &&
        h.doneAt != null &&
        h.doneAt! >= startMs &&
        h.doneAt! <= endMs).length;

    return TimelineOverviewSummary(
      tasksDoneCount: tasksDone,
      topSpendingCategory: topCategory,
      topSpendingAmountMinor: topAmount,
      totalExpensesMinor: totalExpensesMinor,
      totalIncomeMinor: totalIncomeMinor,
      habitsCompletionRate: habitsRate,
      habitsLoggedCount: habitLogs.length,
      notesCount: notesCount,
      goalProgressAvg: goalProgressAvg,
      healthItemsDoneCount: healthDone,
    );
  }
}
