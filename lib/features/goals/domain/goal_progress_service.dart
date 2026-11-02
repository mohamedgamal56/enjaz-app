class GoalProgressService {
  GoalProgressService._();

  /// Calculates milestone mode progress (0.0 to 100.0) based on milestone weights
  /// Spec Section 4: (sum of weights of done milestones) / (sum of all weights) * 100
  static double calculateMilestonesProgress({
    required List<int> weights,
    required List<bool> isDoneList,
  }) {
    if (weights.isEmpty || weights.length != isDoneList.length) {
      return 0.0;
    }

    int totalWeight = 0;
    int doneWeight = 0;

    for (int i = 0; i < weights.length; i++) {
      final w = weights[i] > 0 ? weights[i] : 1;
      totalWeight += w;
      if (isDoneList[i]) {
        doneWeight += w;
      }
    }

    if (totalWeight == 0) return 0.0;
    return (doneWeight / totalWeight) * 100.0;
  }

  /// Calculates numeric mode progress (0.0 to 100.0, capped at 100)
  /// Spec Section 4: current_value / target_value * 100, capped at 100
  static double calculateNumericProgress({
    required double currentValue,
    required double targetValue,
  }) {
    if (targetValue <= 0) return 0.0;
    final pct = (currentValue / targetValue) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Calculates days left until target date. Negative number means overdue.
  static int calculateDaysLeft({
    required String? targetDateStr,
    DateTime? now,
  }) {
    if (targetDateStr == null || targetDateStr.trim().isEmpty) return 0;
    final target = DateTime.tryParse(targetDateStr);
    if (target == null) return 0;

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final targetDay = DateTime(target.year, target.month, target.day);

    return targetDay.difference(today).inDays;
  }

  /// Checks if a goal is overdue (target date before today and not done)
  static bool isOverdue({
    required String? targetDateStr,
    required String status,
    DateTime? now,
  }) {
    if (status == 'done' || status == 'abandoned') return false;
    if (targetDateStr == null) return false;
    final days = calculateDaysLeft(targetDateStr: targetDateStr, now: now);
    return days < 0;
  }
}
