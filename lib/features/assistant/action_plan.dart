import 'assistant_intent.dart';

/// Represents a candidate task when multiple tasks match a spoken title
class CandidateTask {
  final int id;
  final String title;
  final String? dueDate;
  final String status;

  const CandidateTask({
    required this.id,
    required this.title,
    this.dueDate,
    required this.status,
  });
}

/// Represents the actionable plan generated from an [AssistantIntent] (VOICE.md Section 2.4 & 7).
class ActionPlan {
  final AssistantIntent intent;
  final String actionType; // task, errand, reminder, status_update, expense, income, habit, note, idea, wishlist, health, blocked, unrecognized
  final String actionTitle; // Display title in the card header
  final String descriptionInWords; // Full human-readable sentence in Arabic words
  final Map<String, dynamic> slots;

  // Missing or ambiguous info resolution
  final bool hasMissingDate;
  final String selectedDateChip; // 'none', 'today', 'tomorrow', 'custom'
  final bool hasMissingReason;
  final List<String> reasonChips;
  final bool isAmbiguous;
  final List<CandidateTask> candidateTasks;

  // Security and status flags
  final bool isBlocked;
  final String? blockedMessage;
  final bool isUnrecognized;
  final String? fallbackTitle;

  const ActionPlan({
    required this.intent,
    required this.actionType,
    required this.actionTitle,
    required this.descriptionInWords,
    required this.slots,
    this.hasMissingDate = false,
    this.selectedDateChip = 'none',
    this.hasMissingReason = false,
    this.reasonChips = const [],
    this.isAmbiguous = false,
    this.candidateTasks = const [],
    this.isBlocked = false,
    this.blockedMessage,
    this.isUnrecognized = false,
    this.fallbackTitle,
  });

  /// Creates a copy of this plan with updated fields (e.g. when user taps a date chip or selects a task)
  ActionPlan copyWith({
    String? descriptionInWords,
    Map<String, dynamic>? slots,
    bool? hasMissingDate,
    String? selectedDateChip,
    bool? hasMissingReason,
    List<String>? reasonChips,
    bool? isAmbiguous,
    List<CandidateTask>? candidateTasks,
  }) {
    return ActionPlan(
      intent: intent,
      actionType: actionType,
      actionTitle: actionTitle,
      descriptionInWords: descriptionInWords ?? this.descriptionInWords,
      slots: slots ?? this.slots,
      hasMissingDate: hasMissingDate ?? this.hasMissingDate,
      selectedDateChip: selectedDateChip ?? this.selectedDateChip,
      hasMissingReason: hasMissingReason ?? this.hasMissingReason,
      reasonChips: reasonChips ?? this.reasonChips,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      candidateTasks: candidateTasks ?? this.candidateTasks,
      isBlocked: isBlocked,
      blockedMessage: blockedMessage,
      isUnrecognized: isUnrecognized,
      fallbackTitle: fallbackTitle,
    );
  }
}
