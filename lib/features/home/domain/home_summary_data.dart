/// HomeSummaryData (UI.md Section 4 & Section 8 Rule 4)
/// Aggregated summary model for the Home screen cards.
class HomeSummaryData {
  // Today card
  final int todayCompletedCount;
  final int todayTotalCount;
  final double todayProgress;
  final String? nextTaskTitle;
  final String? nextTaskTime;
  final bool isAllTodayDone;

  // Overdue strip
  final int overdueCount;

  // Habits card
  final int habitsCompletedCount;
  final int habitsTotalScheduledCount;
  final int habitsStreak;
  final bool hasHabits;

  // Finance card
  final int todaySpendingMinor;
  final bool hasMonthlyBudget;
  final int remainingMonthlyBudgetMinor;
  final int monthSpendingMinor;

  // Health card
  final String? nearestHealthTitle;
  final String? nearestHealthDay;
  final int postponedHealthCount;

  // Goals & Ideas card
  final int activeGoalsCount;
  final int ideasCount;
  final int notesCount;

  const HomeSummaryData({
    this.todayCompletedCount = 0,
    this.todayTotalCount = 0,
    this.todayProgress = 0.0,
    this.nextTaskTitle,
    this.nextTaskTime,
    this.isAllTodayDone = false,
    this.overdueCount = 0,
    this.habitsCompletedCount = 0,
    this.habitsTotalScheduledCount = 0,
    this.habitsStreak = 0,
    this.hasHabits = false,
    this.todaySpendingMinor = 0,
    this.hasMonthlyBudget = false,
    this.remainingMonthlyBudgetMinor = 0,
    this.monthSpendingMinor = 0,
    this.nearestHealthTitle,
    this.nearestHealthDay,
    this.postponedHealthCount = 0,
    this.activeGoalsCount = 0,
    this.ideasCount = 0,
    this.notesCount = 0,
  });
}
