import 'package:flutter/material.dart';

class AppColors {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color warningText;
  final Color warningBorder;
  final Color todo;
  final Color inProgress;
  final Color partial;
  final Color done;
  final Color postponed;
  final Color waiting;
  final Color stopped;

  Color get textSecondary => textMuted;

  const AppColors({
    this.isDark = false,
    this.background = lightBackground,
    this.surface = lightSurface,
    this.surfaceVariant = lightSurfaceVariant,
    this.text = lightText,
    this.textMuted = lightTextMuted,
    this.border = lightBorder,
    this.accent = lightAccent,
    this.warningText = lightWarningText,
    this.warningBorder = lightWarningBorder,
    this.todo = lightStatusTodo,
    this.inProgress = lightStatusInProgress,
    this.partial = lightStatusPartial,
    this.done = lightStatusDone,
    this.postponed = lightStatusPostponed,
    this.waiting = lightStatusWaiting,
    this.stopped = lightStatusStopped,
  });

  static AppColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppColors(
      isDark: isDark,
      background: isDark ? darkBackground : lightBackground,
      surface: isDark ? darkSurface : lightSurface,
      surfaceVariant: isDark ? darkSurfaceVariant : lightSurfaceVariant,
      text: isDark ? darkText : lightText,
      textMuted: isDark ? darkTextMuted : lightTextMuted,
      border: isDark ? darkBorder : lightBorder,
      accent: isDark ? darkAccent : lightAccent,
      warningText: isDark ? darkWarningText : lightWarningText,
      warningBorder: isDark ? darkWarningBorder : lightWarningBorder,
      todo: isDark ? darkStatusTodo : lightStatusTodo,
      inProgress: isDark ? darkStatusInProgress : lightStatusInProgress,
      partial: isDark ? darkStatusPartial : lightStatusPartial,
      done: isDark ? darkStatusDone : lightStatusDone,
      postponed: isDark ? darkStatusPostponed : lightStatusPostponed,
      waiting: isDark ? darkStatusWaiting : lightStatusWaiting,
      stopped: isDark ? darkStatusStopped : lightStatusStopped,
    );
  }

  // Light Tokens (UI.md Section 3)
  static const Color lightBackground = Color(0xFFFAFAF9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F4);
  static const Color lightText = Color(0xFF1C1917);
  static const Color lightTextMuted = Color(0xFF57534E); // text-secondary
  static const Color lightBorder = Color(0xFFE7E5E4);
  static const Color lightAccent = Color(0xFF0D9488); // Teal
  static const Color lightWarningText = Color(0xFF92400E);
  static const Color lightWarningBorder = Color(0xFFF59E0B);

  // Dark Tokens (UI.md Section 3)
  static const Color darkBackground = Color(0xFF0F1412);
  static const Color darkSurface = Color(0xFF1A1F1E);
  static const Color darkSurfaceVariant = Color(0xFF232928);
  static const Color darkText = Color(0xFFF5F5F4);
  static const Color darkTextMuted = Color(0xFFA8A29E); // text-secondary
  static const Color darkBorder = Color(0xFF2F3534);
  static const Color darkAccent = Color(0xFF2DD4BF); // Teal
  static const Color darkWarningText = Color(0xFFFBBF24);
  static const Color darkWarningBorder = Color(0xFF5C4410);

  // Status Colors (Light Mode)
  static const Color lightStatusTodo = Color(0xFF78716C);
  static const Color lightStatusInProgress = Color(0xFF2563EB);
  static const Color lightStatusPartial = Color(0xFFD97706);
  static const Color lightStatusDone = Color(0xFF16A34A);
  static const Color lightStatusPostponed = Color(0xFF6B7280);
  static const Color lightStatusWaiting = Color(0xFF7C3AED);
  static const Color lightStatusStopped = Color(0xFFDC2626);

  // Status Colors (Dark Mode)
  static const Color darkStatusTodo = Color(0xFFA8A29E);
  static const Color darkStatusInProgress = Color(0xFF60A5FA);
  static const Color darkStatusPartial = Color(0xFFFBBF24);
  static const Color darkStatusDone = Color(0xFF4ADE80);
  static const Color darkStatusPostponed = Color(0xFF9CA3AF);
  static const Color darkStatusWaiting = Color(0xFFA78BFA);
  static const Color darkStatusStopped = Color(0xFFF87171);

  /// Helper to get status color based on current brightness
  static Color getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'in_progress':
        return isDark ? darkStatusInProgress : lightStatusInProgress;
      case 'partial':
        return isDark ? darkStatusPartial : lightStatusPartial;
      case 'done':
        return isDark ? darkStatusDone : lightStatusDone;
      case 'postponed':
        return isDark ? darkStatusPostponed : lightStatusPostponed;
      case 'waiting':
        return isDark ? darkStatusWaiting : lightStatusWaiting;
      case 'stopped':
        return isDark ? darkStatusStopped : lightStatusStopped;
      case 'todo':
      default:
        return isDark ? darkStatusTodo : lightStatusTodo;
    }
  }

  /// Helper to get status icon based on Spec Section 5 table
  static IconData getStatusIcon(String status) {
    switch (status) {
      case 'in_progress':
        return Icons.play_circle_outline_rounded;
      case 'partial':
        return Icons.pie_chart_outline_rounded;
      case 'done':
        return Icons.check_circle_rounded;
      case 'postponed':
        return Icons.schedule_rounded;
      case 'waiting':
        return Icons.hourglass_empty_rounded;
      case 'stopped':
        return Icons.stop_circle_outlined;
      case 'todo':
      default:
        return Icons.circle_outlined;
    }
  }
}
