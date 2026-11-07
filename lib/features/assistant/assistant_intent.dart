/// Represents the detected intent type in the voice assistant (VOICE.md Sections 5 & 6).
enum AssistantIntentType {
  // --- Commands (Section 5) ---
  createTask,
  createErrand,
  createReminder,
  updateStatus,
  logExpense,
  logIncome,
  logHabit,
  createNote,
  createIdea,
  recordVoiceNote,
  createWishlistItem,
  createHealthItem,

  // --- Questions (Section 6) ---
  agenda,
  recap,
  spending,
  habitStatus,
  pending,
  obligations,
  healthPending,
  wishlist,

  // --- Blocked / Special (Section 7) ---
  unsupportedDelete,
  unrecognized;

  /// String representation matching VOICE.md identifiers (e.g. 'create_task')
  String get nameStr {
    switch (this) {
      case AssistantIntentType.createTask:
        return 'create_task';
      case AssistantIntentType.createErrand:
        return 'create_errand';
      case AssistantIntentType.createReminder:
        return 'create_reminder';
      case AssistantIntentType.updateStatus:
        return 'update_status';
      case AssistantIntentType.logExpense:
        return 'log_expense';
      case AssistantIntentType.logIncome:
        return 'log_income';
      case AssistantIntentType.logHabit:
        return 'log_habit';
      case AssistantIntentType.createNote:
        return 'create_note';
      case AssistantIntentType.createIdea:
        return 'create_idea';
      case AssistantIntentType.recordVoiceNote:
        return 'record_voice_note';
      case AssistantIntentType.createWishlistItem:
        return 'create_wishlist_item';
      case AssistantIntentType.createHealthItem:
        return 'create_health_item';
      case AssistantIntentType.agenda:
        return 'agenda';
      case AssistantIntentType.recap:
        return 'recap';
      case AssistantIntentType.spending:
        return 'spending';
      case AssistantIntentType.habitStatus:
        return 'habit_status';
      case AssistantIntentType.pending:
        return 'pending';
      case AssistantIntentType.obligations:
        return 'obligations';
      case AssistantIntentType.healthPending:
        return 'health_pending';
      case AssistantIntentType.wishlist:
        return 'wishlist';
      case AssistantIntentType.unsupportedDelete:
        return 'unsupported_delete';
      case AssistantIntentType.unrecognized:
        return 'unrecognized';
    }
  }

  /// Parses string into [AssistantIntentType]
  static AssistantIntentType fromString(String str) {
    for (final val in AssistantIntentType.values) {
      if (val.nameStr == str || val.name == str) return val;
    }
    return AssistantIntentType.unrecognized;
  }

  /// True if intent is an action command (Section 5)
  bool get isCommand {
    switch (this) {
      case AssistantIntentType.createTask:
      case AssistantIntentType.createErrand:
      case AssistantIntentType.createReminder:
      case AssistantIntentType.updateStatus:
      case AssistantIntentType.logExpense:
      case AssistantIntentType.logIncome:
      case AssistantIntentType.logHabit:
      case AssistantIntentType.createNote:
      case AssistantIntentType.createIdea:
      case AssistantIntentType.recordVoiceNote:
      case AssistantIntentType.createWishlistItem:
      case AssistantIntentType.createHealthItem:
        return true;
      default:
        return false;
    }
  }

  /// True if intent is a question (Section 6)
  bool get isQuestion {
    switch (this) {
      case AssistantIntentType.agenda:
      case AssistantIntentType.recap:
      case AssistantIntentType.spending:
      case AssistantIntentType.habitStatus:
      case AssistantIntentType.pending:
      case AssistantIntentType.obligations:
      case AssistantIntentType.healthPending:
      case AssistantIntentType.wishlist:
        return true;
      default:
        return false;
    }
  }
}

/// Extracted intent with slots resulting from parsing spoken or typed text.
class AssistantIntent {
  final AssistantIntentType type;
  final String rawText;
  final String normalizedText;
  final Map<String, dynamic> slots;
  final double confidence; // 0.0 to 1.0

  const AssistantIntent({
    required this.type,
    required this.rawText,
    required this.normalizedText,
    this.slots = const {},
    this.confidence = 1.0,
  });

  /// The extracted title / label / description (keeps original spelling from transcript)
  String? get title => slots['title'] as String?;

  /// Date string formatted as 'yyyy-MM-dd'
  String? get dateStr => slots['date'] as String?;

  /// Clock time string formatted as 'HH:mm' (24-hour format)
  String? get timeStr => slots['time'] as String?;

  /// Amount (money / cost / price / income)
  double? get amount => (slots['amount'] as num?)?.toDouble();

  /// Currency code (defaults to 'EGP')
  String get currency => (slots['currency'] as String?) ?? 'EGP';

  /// Expense category name (e.g. 'شاي وقهوة', 'بنزين', 'طعام ومشروبات', 'فواتير')
  String? get category => slots['category'] as String?;

  /// Whether expense is essential (ضروري) or side (جانبي/ترفيهي)
  bool? get isEssential => slots['isEssential'] as bool?;

  /// Quantity (habits count, pages, etc.)
  double? get quantity => (slots['quantity'] as num?)?.toDouble();

  /// Task status ('done', 'in_progress', 'postponed', 'waiting', 'stopped', 'partial')
  String? get status => slots['status'] as String?;

  /// Reason for postponement, waiting, stopping, or partial completion
  String? get reason => slots['reason'] as String?;

  /// Location for errands
  String? get location => slots['location'] as String?;

  /// Note kind ('note', 'quote')
  String? get noteKind => slots['noteKind'] as String?;

  /// Voice note kind ('idea', 'note')
  String? get voiceNoteKind => slots['voiceNoteKind'] as String?;

  /// Reminder offset in minutes prior to the target time
  int? get reminderOffsetMinutes => slots['reminderOffsetMinutes'] as int?;

  /// Habit key / identifier
  String? get habitKey => slots['habitKey'] as String?;

  /// Health item status ('needed', 'scheduled')
  String? get healthStatus => slots['healthStatus'] as String?;

  /// Filter for pending questions ('overdue', 'postponed', 'waiting')
  String? get statusFilter => slots['statusFilter'] as String?;

  /// Date period representation ('this_week', 'last_week', 'this_month', 'last_month', etc.)
  String? get periodStr => slots['period'] as String?;

  /// Progress fraction for partial tasks (e.g. 0.5)
  double? get progress => (slots['progress'] as num?)?.toDouble();

  /// True if the operation is explicitly blocked (such as voice deletion)
  bool get isBlocked => type == AssistantIntentType.unsupportedDelete;

  /// True if parser successfully resolved an intent
  bool get isRecognized => type != AssistantIntentType.unrecognized;

  /// True if intent is an action command (Section 5)
  bool get isCommand => type.isCommand;

  /// True if intent is a question (Section 6)
  bool get isQuestion => type.isQuestion;

  @override
  String toString() {
    return 'AssistantIntent(type: ${type.nameStr}, confidence: $confidence, slots: $slots)';
  }
}
