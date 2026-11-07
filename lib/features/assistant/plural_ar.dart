/// Helper for Arabic / Egyptian counting and pluralization rules (VOICE.md Section 10.2).
class PluralAr {
  const PluralAr._();

  /// Generic formatter for an Arabic count with singular, dual, and plural forms.
  /// Rules:
  /// - count == 1: [singular]
  /// - count == 2: [dual]
  /// - count >= 3 && count <= 10: '$count $plural'
  /// - count > 10: '$count $singular'
  static String format(
    int count, {
    required String singular,
    required String dual,
    required String plural,
    String? zero,
  }) {
    if (count == 0) return zero ?? 'صفر $singular';
    if (count == 1) return singular;
    if (count == 2) return dual;
    if (count >= 3 && count <= 10) return '$count $plural';
    return '$count $singular';
  }

  /// Formats day counts (e.g. "يوم", "يومين", "3 أيام", "15 يوم")
  static String formatDays(int count) {
    return format(
      count,
      singular: 'يوم',
      dual: 'يومين',
      plural: 'أيام',
      zero: 'صفر يوم',
    );
  }

  /// Formats hour counts (e.g. "ساعة", "ساعتين", "3 ساعات", "14 ساعة")
  static String formatHours(int count) {
    return format(
      count,
      singular: 'ساعة',
      dual: 'ساعتين',
      plural: 'ساعات',
      zero: 'صفر ساعة',
    );
  }

  /// Formats minute counts (e.g. "دقيقة", "دقيقتين", "5 دقائق", "25 دقيقة")
  static String formatMinutes(int count) {
    return format(
      count,
      singular: 'دقيقة',
      dual: 'دقيقتين',
      plural: 'دقائق',
      zero: 'صفر دقيقة',
    );
  }

  /// Formats task counts (e.g. "مهمة", "مهمتين", "3 مهام", "12 مهمة")
  static String formatTasks(int count) {
    return format(
      count,
      singular: 'مهمة',
      dual: 'مهمتين',
      plural: 'مهام',
      zero: 'لا توجد مهام',
    );
  }

  /// Formats habits counts (e.g. "عادة", "عادتين", "3 عادات")
  static String formatHabits(int count) {
    return format(
      count,
      singular: 'عادة',
      dual: 'عادتين',
      plural: 'عادات',
      zero: 'صفر عادة',
    );
  }

  /// Formats Egyptian pounds (e.g. "جنيه", "جنيهين", "25 جنيه", "1500 جنيه")
  static String formatPounds(num amount) {
    if (amount == 0) return '0 جنيه';
    if (amount == 1) return 'جنيه';
    if (amount == 2) return 'جنيهين';
    if (amount >= 3 && amount <= 10 && amount == amount.toInt()) {
      return '${amount.toInt()} جنيه';
    }
    final formatted = amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
    return '$formatted جنيه';
  }
}
