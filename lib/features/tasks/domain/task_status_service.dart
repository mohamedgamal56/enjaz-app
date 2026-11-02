class TaskTransitionResult {
  final String status;
  final int? startedAt;
  final int? finishedAt;
  final int progress;
  final int postponeCount;
  final String? postponedUntil;

  const TaskTransitionResult({
    required this.status,
    this.startedAt,
    this.finishedAt,
    required this.progress,
    required this.postponeCount,
    this.postponedUntil,
  });
}

class TaskStatusService {
  TaskStatusService._();

  /// Validates whether a transition to [targetStatus] is allowed with given parameters
  static String? validateTransition({
    required String targetStatus,
    int? progress,
    int? reasonId,
    String? reasonText,
  }) {
    final hasReason = (reasonId != null && reasonId > 0) || (reasonText != null && reasonText.trim().isNotEmpty);

    switch (targetStatus) {
      case 'partial':
        if (progress == null || progress < 1 || progress > 99) {
          return 'Progress must be between 1 and 99%';
        }
        if (!hasReason) {
          return 'Reason is required for partially done status';
        }
        break;

      case 'postponed':
        if (!hasReason) {
          return 'Reason is required for postponing';
        }
        break;

      case 'waiting':
        if (!hasReason) {
          return 'Reason is required for waiting';
        }
        break;

      case 'stopped':
        if (!hasReason) {
          return 'Reason is required for stopping a task';
        }
        break;

      case 'todo':
      case 'in_progress':
      case 'done':
        // No required reason
        break;
    }
    return null; // Valid
  }

  /// Calculates new state variables for a transition according to Spec Section 5
  static TaskTransitionResult applyTransition({
    required String currentStatus,
    required String targetStatus,
    int? currentStartedAt,
    int? currentFinishedAt,
    int currentProgress = 0,
    int currentPostponeCount = 0,
    String? currentPostponedUntil,
    int? newProgress,
    int? nowMs,
    String? newPostponedUntil,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;

    int? startedAt = currentStartedAt;
    int? finishedAt = currentFinishedAt;
    int progress = newProgress ?? currentProgress;
    int postponeCount = currentPostponeCount;
    String? postponedUntil = currentPostponedUntil;

    // Rule 1 & Rule 2 & Rule 3:
    if (targetStatus == 'done') {
      finishedAt = now;
      progress = 100;
    } else if (currentStatus == 'done' && (targetStatus == 'todo' || targetStatus == 'in_progress')) {
      // Reopening a done task clears finished_at
      finishedAt = null;
      if (targetStatus == 'todo') {
        progress = 0;
      }
    }

    // In progress sets started_at if empty
    if (targetStatus == 'in_progress') {
      startedAt ??= now;
    }

    // Postponed increments count and sets postponed_until
    if (targetStatus == 'postponed') {
      postponeCount += 1;
      postponedUntil = newPostponedUntil;
    } else if (currentStatus == 'postponed' && targetStatus != 'postponed') {
      // Moving from postponed to any other status clears postponed_until
      postponedUntil = null;
    }

    // Partial updates progress (1-99)
    if (targetStatus == 'partial' && newProgress != null) {
      progress = newProgress.clamp(1, 99);
    }

    return TaskTransitionResult(
      status: targetStatus,
      startedAt: startedAt,
      finishedAt: finishedAt,
      progress: progress,
      postponeCount: postponeCount,
      postponedUntil: postponedUntil,
    );
  }
}
