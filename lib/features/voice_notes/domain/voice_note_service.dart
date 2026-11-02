import 'package:intl/intl.dart';

class VoiceNoteService {
  VoiceNoteService._();

  /// Formats duration in milliseconds to mm:ss (e.g. 02:45)
  static String formatDuration(int durationMs) {
    if (durationMs < 0) return '00:00';
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Formats size in bytes to readable string (e.g. 350 KB, 1.4 MB)
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      final kb = (bytes / 1024).round();
      return '$kb KB';
    } else {
      final mb = bytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
  }

  /// Generates default voice-only title according to Spec 14.3:
  /// e.g. "تسجيل صوتي — 2 نوفمبر 10:30" / "Voice note — 2 Nov 10:30"
  static String generateVoiceOnlyTitle({
    required DateTime date,
    required bool isArabic,
  }) {
    if (isArabic) {
      final arabicMonths = [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ];
      final day = date.day;
      final month = arabicMonths[date.month - 1];
      final time = DateFormat('hh:mm').format(date);
      final amPm = date.hour >= 12 ? 'م' : 'ص';
      return 'تسجيل صوتي — $day $month $time $amPm';
    } else {
      final formatted = DateFormat('d MMM hh:mm a').format(date);
      return 'Voice note — $formatted';
    }
  }

  /// Checks if recording duration exceeds 5 seconds (needs confirmation to discard)
  static bool requiresDiscardConfirmation(int durationMs) {
    return durationMs > 5000;
  }
}
