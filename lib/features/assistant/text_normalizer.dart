/// Text normalizer for Arabic voice assistant matching (VOICE.md Section 4.2).
/// Used for parsing and pattern matching only; original transcript is preserved for display.
class TextNormalizer {
  const TextNormalizer._();

  /// Tashkeel / Diacritics regex: Fatha, Damma, Kasra, Sukun, Tanween, Shadda, etc.
  static final RegExp _diacriticsRegex = RegExp(r'[\u064B-\u065F\u0670\u0640]');

  /// Common Arabic and Latin punctuation
  static final RegExp _punctuationRegex = RegExp(r'[،؛؟!؟\.,:;`"\'\(\)\[\]\{\}\<\>\/\\«»\-_~#@\*\^\+=]');

  /// Arabic-Indic digits mapping to Western digits
  static const Map<String, String> _arabicDigitsMap = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  /// Common Egyptian dialect word mappings
  static const Map<String, String> _dialectReplacements = {
    'النهاردة': 'النهارده',
    'انهارده': 'النهارده',
    'النهارضه': 'النهارده',
    'النهارد': 'النهارده',
    'بكره': 'بكرة',
    'غدا': 'بكرة',
    'غداً': 'بكرة',
    'مبارح': 'امبارح',
    'البارحة': 'امبارح',
    'امس': 'امبارح',
    'أمس': 'امبارح',
    'دلوكتي': 'دلوقتي',
    'دلوؤتي': 'دلوقتي',
    'الجايه': 'الجاي',
    'الجاية': 'الجاي',
    'القادم': 'الجاي',
    'القادمة': 'الجاي',
    'الماضي': 'اللي فات',
    'الماضية': 'اللي فات',
    'الي فات': 'اللي فات',
    'الي فاتت': 'اللي فات',
    'اللي فاتت': 'اللي فات',
    'السنه دي': 'السنة دي',
    'السنة هذي': 'السنة دي',
  };

  /// Fully normalizes Arabic input for intent matching:
  /// 1. Removes tashkeel / diacritics
  /// 2. Converts Arabic-Indic digits (٠-٩) to Western (0-9)
  /// 3. Unifies Alef variations (أ, إ, آ, ٱ -> ا)
  /// 4. Unifies Taa Marbuta (ة -> ه)
  /// 5. Unifies Alef Maqsura (ى -> ي)
  /// 6. Strips punctuation
  /// 7. Replaces Egyptian dialect synonyms
  /// 8. Cleans and condenses whitespace
  static String normalize(String text) {
    if (text.isEmpty) return '';

    // 1. Remove diacritics (tashkeel + tatweel)
    var result = removeDiacritics(text);

    // 2. Convert digits
    result = convertArabicDigits(result);

    // 3. Unify Alef forms: أ, إ, آ, ٱ -> ا
    result = result.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // 4. Unify Taa Marbuta: ة -> ه
    result = result.replaceAll('ة', 'ه');

    // 5. Unify Yaa / Alef Maqsura: ى -> ي
    result = result.replaceAll('ى', 'ي');

    // 6. Remove punctuation
    result = result.replaceAll(_punctuationRegex, ' ');

    // 7. Clean whitespace
    result = cleanWhitespace(result);

    // 8. Replace dialect terms token by token or phrase
    result = _replaceDialectTerms(result);

    return result;
  }

  /// Removes Arabic diacritics and tatweel
  static String removeDiacritics(String text) {
    return text.replaceAll(_diacriticsRegex, '');
  }

  /// Converts Arabic-Indic digits to ASCII Western digits
  static String convertArabicDigits(String text) {
    var buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(_arabicDigitsMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Condenses multiple spaces into a single space and trims
  static String cleanWhitespace(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Replaces common dialect phrases and words
  static String _replaceDialectTerms(String text) {
    var working = text;
    // Multi-word replacements first
    _dialectReplacements.forEach((from, to) {
      if (from.contains(' ')) {
        working = working.replaceAll(from, to);
      }
    });

    // Single-word replacements
    final tokens = working.split(' ');
    final mapped = tokens.map((t) => _dialectReplacements[t] ?? t);
    return mapped.join(' ');
  }
}
