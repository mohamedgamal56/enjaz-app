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

  /// Formats month counts (e.g. "شهر", "شهرين", "3 شهور", "12 شهر")
  static String formatMonths(int count) {
    return format(
      count,
      singular: 'شهر',
      dual: 'شهرين',
      plural: 'شهور',
      zero: 'صفر شهر',
    );
  }

  /// Formats cups (e.g. "فنجان", "فنجانين", "3 فناجين", "12 فنجان")
  static String formatCups(int count) {
    return format(
      count,
      singular: 'فنجان',
      dual: 'فنجانين',
      plural: 'فناجين',
      zero: 'ولا فنجان',
    );
  }

  /// Formats times (e.g. "مرة", "مرتين", "3 مرات", "12 مرة")
  static String formatTimes(int count) {
    return format(
      count,
      singular: 'مرة',
      dual: 'مرتين',
      plural: 'مرات',
      zero: 'ولا مرة',
    );
  }

  /// Formats obligations (e.g. "التزام", "التزامين", "3 التزامات", "12 التزام")
  static String formatObligations(int count) {
    return format(
      count,
      singular: 'التزام',
      dual: 'التزامين',
      plural: 'التزامات',
      zero: 'لا توجد التزامات',
    );
  }

  /// Formats checkups / health items (e.g. "كشف", "كشفين", "3 كشوفات", "12 كشف")
  static String formatCheckups(int count) {
    return format(
      count,
      singular: 'كشف',
      dual: 'كشفين',
      plural: 'كشوفات',
      zero: 'لا توجد كشوفات',
    );
  }

  /// Formats notes (e.g. "ملاحظة", "ملاحظتين", "3 ملاحظات", "12 ملاحظة")
  static String formatNotes(int count) {
    return format(
      count,
      singular: 'ملاحظة',
      dual: 'ملاحظتين',
      plural: 'ملاحظات',
      zero: 'صفر ملاحظة',
    );
  }

  /// Formats ideas (e.g. "فكرة", "فكرتين", "3 أفكار", "12 فكرة")
  static String formatIdeas(int count) {
    return format(
      count,
      singular: 'فكرة',
      dual: 'فكرتين',
      plural: 'أفكار',
      zero: 'صفر فكرة',
    );
  }

  /// Formats generic items (e.g. "عنصر", "عنصرين", "3 عناصر", "12 عنصر")
  static String formatItems(int count, {String singular = 'عنصر', String dual = 'عنصرين', String plural = 'عناصر'}) {
    return format(
      count,
      singular: singular,
      dual: dual,
      plural: plural,
      zero: 'لا توجد $plural',
    );
  }
}
