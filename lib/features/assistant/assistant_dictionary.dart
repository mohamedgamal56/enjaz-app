import 'text_normalizer.dart';

/// Dictionary and synonyms lookup helper for the Voice Assistant (VOICE.md Section 5.3 & Section 8).
class AssistantDictionary {
  const AssistantDictionary._();

  /// Category synonyms mapping to standard category names
  static const Map<String, List<String>> categorySynonyms = {
    'شاي وقهوة': [
      'شاي',
      'قهوه',
      'قهوة',
      'شاي وقهوة',
      'شاي بلبن',
      'نسكافيه',
      'اسبريسو',
      'كابتشينو',
      'مشروبات',
      'عصير',
      'كركديه',
      'ينسون',
    ],
    'طعام ومطاعم': [
      'اكل بره',
      'أكل بره',
      'مطعم',
      'غدا',
      'عشا',
      'فطار',
      'سندوتش',
      'سندوتشات',
      'دليفري',
      'كافيه',
      'حلويات',
      'بيتزا',
      'برجر',
      'شاورما',
      'كشري',
    ],
    'بنزين ومواصلات': [
      'بنزين',
      'مواصلات',
      'موتوسيكل',
      'عربيه',
      'عربية',
      'اوبر',
      'كريم',
      'تاكسي',
      'مترو',
      'ميكروباص',
      'باص',
      'اتوبيس',
      'تذكرة',
      'تذاكر',
      'تفويلة',
      'غيار زيت',
    ],
    'فواتير واشتراكات': [
      'فاتوره',
      'فاتورة',
      'فاتورة النت',
      'فاتوره النت',
      'نت',
      'انترنت',
      'تليفون',
      'موبايل',
      'شحن',
      'رصيد',
      'كهربا',
      'كهرباء',
      'غاز',
      'ميه',
      'مياه',
      'اشتراك',
    ],
    'بقالة ومستلزمات منزل': [
      'بقاله',
      'بقالة',
      'سوبرماركت',
      'سوبر ماركت',
      'خضار',
      'فاكهه',
      'فاكهة',
      'عيش',
      'لحمة',
      'فراخ',
      'لبن',
      'جبنة',
      'زيت',
      'سكر',
      'طلبات البيت',
    ],
    'صحة وعلاج': [
      'دوا',
      'دواء',
      'صيدلية',
      'صيدليه',
      'علاج',
      'كشف',
      'تحليل',
      'دكتور',
      'مستشفى',
      'روشتة',
    ],
  };

  /// Set of categories considered essential expenses
  static const Set<String> essentialCategories = {
    'بنزين ومواصلات',
    'فواتير واشتراكات',
    'بقالة ومستلزمات منزل',
    'صحة وعلاج',
  };

  /// Habit synonyms mapping to habit key and display names
  static const Map<String, List<String>> habitSynonyms = {
    'coffee': [
      'قهوه',
      'قهوة',
      'شربت قهوة',
      'شربت قهوه',
      'كوبايتين قهوة',
      'كوباية قهوة',
      'فنجان قهوة',
      'فنجان قهوه',
      'اسبريسو',
    ],
    'water': [
      'ميه',
      'مياه',
      'شربت ميه',
      'كوباية ميه',
      'كوبايتين ميه',
      'ازازة ميه',
      'لتر ميه',
    ],
    'quran': [
      'قران',
      'قرآن',
      'قريت قران',
      'قريت قرآن',
      'صفحات قران',
      'ورد القران',
      'سورة',
    ],
    'fajr': [
      'صليت الفجر',
      'الفجر',
      'فجر',
      'صلاة الفجر',
    ],
    'prayers': [
      'صليت',
      'الصلاة',
      'الضهر',
      'العصر',
      'المغرب',
      'العشا',
    ],
    'azkar': [
      'اذكار',
      'أذكار',
      'اذكار الصباح',
      'اذكار المساء',
      'أذكار الصباح',
      'أذكار المساء',
      'ورد الأذكار',
    ],
    'reading': [
      'قراءة',
      'قرايه',
      'قريت في الكتاب',
      'كتاب',
      'قريت صفحات',
    ],
    'exercise': [
      'رياضة',
      'جيم',
      'اتمرنت',
      'تمرين',
      'مشيت',
    ],
  };

  /// Common reasons for task postponement or status changes
  static const Map<String, List<String>> reasonSynonyms = {
    'مفيش فلوس': [
      'مفيش فلوس',
      'معييش فلوس',
      'الميزانية',
      'بسبب الميزانية',
      'الميزانيه',
      'محتاج سيولة',
      'السيولة',
    ],
    'مضغوط في الشغل': [
      'مضغوط في الشغل',
      'ضغط شغل',
      'شغل كتير',
      'الشغل زحمة',
      'مشغول في الشغل',
      'ضغط العمل',
    ],
    'تعبت': [
      'تعبت',
      'لاني تعبت',
      'تعبان',
      'مرهق',
      'ارهاق',
      'مش قادر',
      'ظرف صحي',
    ],
    'مستني رد': [
      'مستني رد',
      'مستنية رد',
      'مستني الرد',
      'مستنية رد الدكتور',
      'مستني رد الدكتور',
      'مستني العميل',
    ],
    'مشوار طارئ': [
      'مشوار طارئ',
      'ظرف طارئ',
      'عندي مشوار',
      'مشوار مفاجئ',
    ],
  };

  /// Matches text against known expense categories
  static String? matchCategory(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    // 1. Direct match on synonyms
    for (final entry in categorySynonyms.entries) {
      for (final syn in entry.value) {
        final normSyn = TextNormalizer.normalize(syn);
        if (_containsPhrase(norm, normSyn)) {
          return entry.key;
        }
      }
    }

    return null;
  }

  /// Returns true if category is essential
  static bool isEssential(String? category) {
    if (category == null) return false;
    return essentialCategories.contains(category);
  }

  /// Matches habit key from text
  static String? matchHabitKey(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    for (final entry in habitSynonyms.entries) {
      for (final syn in entry.value) {
        final normSyn = TextNormalizer.normalize(syn);
        if (_containsPhrase(norm, normSyn)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Matches reason from text
  static String? matchReason(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    for (final entry in reasonSynonyms.entries) {
      for (final syn in entry.value) {
        final normSyn = TextNormalizer.normalize(syn);
        if (_containsPhrase(norm, normSyn)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  static bool _containsPhrase(String text, String phrase) {
    if (text == phrase) return true;
    final reg = RegExp('(^|[\\s،,])${RegExp.escape(phrase)}([\\s،,]|\$)');
    return reg.hasMatch(text);
  }
}
