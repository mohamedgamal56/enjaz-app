import 'package:flutter/material.dart';

/// Module types supported in the Life Timeline
enum TimelineModule {
  task,
  habit,
  finance,
  health,
  note,
  idea,
  goal;

  String get labelAr {
    switch (this) {
      case TimelineModule.task:
        return 'المهام';
      case TimelineModule.habit:
        return 'العادات';
      case TimelineModule.finance:
        return 'المال';
      case TimelineModule.health:
        return 'الصحة';
      case TimelineModule.note:
        return 'الملاحظات';
      case TimelineModule.idea:
        return 'الأفكار';
      case TimelineModule.goal:
        return 'الأهداف';
    }
  }

  String get labelEn {
    switch (this) {
      case TimelineModule.task:
        return 'Tasks';
      case TimelineModule.habit:
        return 'Habits';
      case TimelineModule.finance:
        return 'Finance';
      case TimelineModule.health:
        return 'Health';
      case TimelineModule.note:
        return 'Notes';
      case TimelineModule.idea:
        return 'Ideas';
      case TimelineModule.goal:
        return 'Goals';
    }
  }

  /// Distinct module dot color per CHANGES.md Sec 11.2:
  /// tasks=blue, habits=teal, finance=green, health=red, notes=orange, ideas=purple, goals=indigo
  Color get color {
    switch (this) {
      case TimelineModule.task:
        return const Color(0xFF2196F3); // Blue
      case TimelineModule.habit:
        return const Color(0xFF009688); // Teal
      case TimelineModule.finance:
        return const Color(0xFF4CAF50); // Green
      case TimelineModule.health:
        return const Color(0xFFFF5252); // Red Accent
      case TimelineModule.note:
        return const Color(0xFFFF9800); // Orange
      case TimelineModule.idea:
        return const Color(0xFF9C27B0); // Purple
      case TimelineModule.goal:
        return const Color(0xFF3F51B5); // Indigo
    }
  }

  IconData get icon {
    switch (this) {
      case TimelineModule.task:
        return Icons.task_alt_rounded;
      case TimelineModule.habit:
        return Icons.repeat_rounded;
      case TimelineModule.finance:
        return Icons.account_balance_wallet_rounded;
      case TimelineModule.health:
        return Icons.favorite_rounded;
      case TimelineModule.note:
        return Icons.note_alt_rounded;
      case TimelineModule.idea:
        return Icons.lightbulb_rounded;
      case TimelineModule.goal:
        return Icons.flag_rounded;
    }
  }
}

/// A unified item in the chronological life timeline
class TimelineEntry {
  final String id;
  final TimelineModule module;
  final int occurredAt; // UTC epoch ms
  final String localDate; // YYYY-MM-DD
  final bool allDay;
  final String? timeStr; // HH:mm if timed
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool hasVoice;
  final String? voiceFileName;
  final String? statusBadge;
  final String sourceType; // task, task_event, habit_log, transaction, obligation, health_item, health_event, treatment, note, idea, goal
  final int sourceId;
  final bool isFuturePlanned;

  const TimelineEntry({
    required this.id,
    required this.module,
    required this.occurredAt,
    required this.localDate,
    this.allDay = false,
    this.timeStr,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.hasVoice = false,
    this.voiceFileName,
    this.statusBadge,
    required this.sourceType,
    required this.sourceId,
    this.isFuturePlanned = false,
  });
}

/// Day summary metrics for the day header
class TimelineDaySummary {
  final int tasksDoneCount;
  final int expensesMinor;
  final int incomeMinor;
  final int habitsDoneCount;
  final int notesCount;
  final int ideasCount;

  const TimelineDaySummary({
    this.tasksDoneCount = 0,
    this.expensesMinor = 0,
    this.incomeMinor = 0,
    this.habitsDoneCount = 0,
    this.notesCount = 0,
    this.ideasCount = 0,
  });

  bool get isEmpty =>
      tasksDoneCount == 0 &&
      expensesMinor == 0 &&
      incomeMinor == 0 &&
      habitsDoneCount == 0 &&
      notesCount == 0 &&
      ideasCount == 0;
}

/// Combined overview headline metrics across all modules
class TimelineOverviewSummary {
  final int tasksDoneCount;
  final String? topSpendingCategory;
  final int topSpendingAmountMinor;
  final int totalExpensesMinor;
  final int totalIncomeMinor;
  final double habitsCompletionRate; // 0..100
  final int habitsLoggedCount;
  final int notesCount;
  final double goalProgressAvg; // 0..100
  final int healthItemsDoneCount;

  const TimelineOverviewSummary({
    this.tasksDoneCount = 0,
    this.topSpendingCategory,
    this.topSpendingAmountMinor = 0,
    this.totalExpensesMinor = 0,
    this.totalIncomeMinor = 0,
    this.habitsCompletionRate = 0.0,
    this.habitsLoggedCount = 0,
    this.notesCount = 0,
    this.goalProgressAvg = 0.0,
    this.healthItemsDoneCount = 0,
  });
}

/// Timeline bounds and constants
class TimelineConstants {
  /// Range: 1 Jan 2026 to 31 Dec 2046 per CHANGES.md Sec 11.1
  static final DateTime minDate = DateTime(2026, 1, 1);
  static final DateTime maxDate = DateTime(2046, 12, 31);
}
