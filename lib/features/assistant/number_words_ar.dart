import 'text_normalizer.dart';

/// Pure Dart converter for Egyptian Arabic number words into numbers (VOICE.md Section 4.3).
class NumberWordsAr {
  const NumberWordsAr._();

  static const Map<String, double> _units = {
    'صفر': 0,
    'واحد': 1,
    'واحده': 1,
    'واحدة': 1,
    'اتنين': 2,
    'اثنين': 2,
    'تلاته': 3,
    'تلاتة': 3,
    'تلات': 3,
    'ثلاثة': 3,
    'ثلاثه': 3,
    'ثلاث': 3,
    'اربعه': 4,
    'اربعة': 4,
    'اربع': 4,
    'أربعة': 4,
    'أربعه': 4,
    'أربع': 4,
    'خمسه': 5,
    'خمسة': 5,
    'خمس': 5,
    'سته': 6,
    'ستة': 6,
    'ست': 6,
    'سبعه': 7,
    'سبعة': 7,
    'سبع': 7,
    'تمانيه': 8,
    'تمانية': 8,
    'تمنيه': 8,
    'تمنية': 8,
    'تمن': 8,
    'ثمانية': 8,
    'ثمانيه': 8,
    'ثمان': 8,
    'تسعه': 9,
    'تسعة': 9,
    'تسع': 9,
    'عشره': 10,
    'عشرة': 10,
    'عشر': 10,
  };

  static const Map<String, double> _teens = {
    'حداشر': 11,
    'احد عشر': 11,
    'اتناشر': 12,
    'اثنا عشر': 12,
    'اثني عشر': 12,
    'تلتاشر': 13,
    'ثلاثة عشر': 13,
    'اربعتاشر': 14,
    'أربعتاشر': 14,
    'اربعه عشر': 14,
    'خمستاشر': 15,
    'خمسة عشر': 15,
    'ستاشر': 16,
    'ستة عشر': 16,
    'سبعتاشر': 17,
    'سبعة عشر': 17,
    'تمنتاشر': 18,
    'ثمانية عشر': 18,
    'تسعتاشر': 19,
    'تسعة عشر': 19,
  };

  static const Map<String, double> _tens = {
    'عشرين': 20,
    'تلاتين': 30,
    'ثلاثين': 30,
    'اربعين': 40,
    'أربعين': 40,
    'خمسين': 50,
    'ستين': 60,
    'سبعين': 70,
    'تمانين': 80,
    'تمنين': 80,
    'ثمانين': 80,
    'تسعين': 90,
  };

  static const Map<String, double> _hundreds = {
    'ميه': 100,
    'مية': 100,
    'مائه': 100,
    'مائة': 100,
    'ميتين': 200,
    'مئتين': 200,
    'مائتين': 200,
    'تلتميه': 300,
    'تلتمية': 300,
    'ثلاثمائة': 300,
    'اربعميه': 400,
    'اربعمية': 400,
    'أربعميه': 400,
    'أربعمية': 400,
    'خمسميه': 500,
    'خمسمية': 500,
    'ستميه': 600,
    'ستمية': 600,
    'سبعميه': 700,
    'سبعمية': 700,
    'تمنميه': 800,
    'تمنمية': 800,
    'تسعميه': 900,
    'تسعمية': 900,
  };

  static const Map<String, double> _thousands = {
    'الف': 1000,
    'ألف': 1000,
    'الفين': 2000,
    'ألفين': 2000,
    'تلات تلاف': 3000,
    'تلات الاف': 3000,
    'اربع تلاف': 4000,
    'اربع الاف': 4000,
    'خمس تلاف': 5000,
    'خمس الاف': 5000,
    'ست تلاف': 6000,
    'ست الاف': 6000,
    'سبع تلاف': 7000,
    'سبع الاف': 7000,
    'تمن تلاف': 8000,
    'تمن الاف': 8000,
    'تسع تلاف': 9000,
    'تسع الاف': 9000,
    'عشر تلاف': 10000,
    'عشر الاف': 10000,
  };

  static const Map<String, double> _fractions = {
    'نص': 0.5,
    'نصف': 0.5,
    'ربع': 0.25,
    'تلت': 0.333,
    'ثلث': 0.333,
  };

  /// Common Egyptian dual suffixes or dual forms
  static const Map<String, double> _duals = {
    'يومين': 2,
    'ساعتين': 2,
    'دقيقتين': 2,
    'كوبايتين': 2,
    'كوبين': 2,
    'اسبوعين': 2,
    'أسبوعين': 2,
    'شهرين': 2,
    'سنتين': 2,
    'جنيهين': 2,
    'قرشين': 2,
    'حبتين': 2,
    'قرصين': 2,
    'مرتين': 2,
    'مهمتين': 2,
  };

  /// Currency indicators
  static const Set<String> currencyWords = {
    'جنيه',
    'جنية',
    'جنيها',
    'جنيهاً',
    'ج',
    'egp',
    'قرش',
    'قروش',
  };

  /// Parses an isolated number phrase in Egyptian Arabic (e.g. "ألف وخمسمية", "اتنين ونص", "خمسة وعشرين")
  /// Returns null if cannot parse.
  static double? parseNumber(String phrase) {
    var raw = phrase.trim();
    if (raw.isEmpty) return null;

    // Check direct numeric parse
    final direct = double.tryParse(raw);
    if (direct != null) return direct;

    final norm = TextNormalizer.normalize(raw);

    // Check direct numeric parse after normalization (e.g. converted Arabic-Indic digits)
    final normNum = double.tryParse(norm);
    if (normNum != null) return normNum;

    // Check duals
    if (_duals.containsKey(norm)) {
      return _duals[norm];
    }

    // Single token checks
    if (_units.containsKey(norm)) return _units[norm];
    if (_teens.containsKey(norm)) return _teens[norm];
    if (_tens.containsKey(norm)) return _tens[norm];
    if (_hundreds.containsKey(norm)) return _hundreds[norm];
    if (_thousands.containsKey(norm)) return _thousands[norm];
    if (_fractions.containsKey(norm)) return _fractions[norm];

    // Compound phrases
    // Pattern 1: X ونص (e.g. "اتنين ونص" -> 2.5, "الف ونص" -> 1500)
    final halfMatch = RegExp(r'^(.+?)\s+و\s*(نص|نصف)$').firstMatch(norm);
    if (halfMatch != null) {
      final baseStr = halfMatch.group(1)!.trim();
      final baseVal = parseNumber(baseStr);
      if (baseVal != null) {
        if (baseVal >= 1000) {
          return baseVal + 500; // e.g. "الف ونص" = 1500
        } else if (baseVal >= 100) {
          return baseVal + 50; // e.g. "مية ونص" = 150
        }
        return baseVal + 0.5; // e.g. "اتنين ونص" = 2.5
      }
    }

    // Pattern 2: X وربع (e.g. "خمسة وربع" -> 5.25, "الف وربع" -> 1250)
    final quarterMatch = RegExp(r'^(.+?)\s+و\s*ربع$').firstMatch(norm);
    if (quarterMatch != null) {
      final baseStr = quarterMatch.group(1)!.trim();
      final baseVal = parseNumber(baseStr);
      if (baseVal != null) {
        if (baseVal >= 1000) {
          return baseVal + 250;
        }
        return baseVal + 0.25;
      }
    }

    // Pattern 3: Thousands + Hundreds (e.g. "الف وخمسميه", "الفين وميتين")
    final thouHunMatch = RegExp(r'^(الف|الفين|.+?\s+تلاف|.+?\s+الاف)\s+و\s*(.+)$').firstMatch(norm);
    if (thouHunMatch != null) {
      final thouPart = thouHunMatch.group(1)!.trim();
      final restPart = thouHunMatch.group(2)!.trim();
      final thouVal = parseNumber(thouPart);
      final restVal = parseNumber(restPart);
      if (thouVal != null && restVal != null) {
        return thouVal + restVal;
      }
    }

    // Pattern 4: Unit + Ten (e.g. "خمسة وعشرين" -> 25, "سبعة وتمانين" -> 87)
    final unitTenMatch = RegExp(r'^(.+?)\s+و\s*(عشرين|تلاتين|ثلاثين|اربعين|خمسين|ستين|سبعين|تمانين|تمنين|ثمانين|تسعين)$').firstMatch(norm);
    if (unitTenMatch != null) {
      final unitPart = unitTenMatch.group(1)!.trim();
      final tenPart = unitTenMatch.group(2)!.trim();
      final uVal = _units[unitPart] ?? parseNumber(unitPart);
      final tVal = _tens[tenPart];
      if (uVal != null && tVal != null) {
        return tVal + uVal;
      }
    }

    // Pattern 5: Hundred + remainder (e.g. "مية وخمسين" -> 150, "تلتمية وخمسة" -> 305)
    final hunRestMatch = RegExp(r'^(ميه|مية|مائة|ميتين|مئتين|.+?ميه|.+?مية)\s+و\s*(.+)$').firstMatch(norm);
    if (hunRestMatch != null) {
      final hunPart = hunRestMatch.group(1)!.trim();
      final restPart = hunRestMatch.group(2)!.trim();
      final hVal = _hundreds[hunPart] ?? parseNumber(hunPart);
      final rVal = parseNumber(restPart);
      if (hVal != null && rVal != null) {
        return hVal + rVal;
      }
    }

    return null;
  }

  /// Extracts an amount and currency from an expression or text.
  /// Examples:
  /// - "100 جنيه" -> (amount: 100.0, currency: 'EGP')
  /// - "شاي بـ 25 جنيه" -> (amount: 25.0, currency: 'EGP')
  /// - "ألف وخمسمية جنيه" -> (amount: 1500.0, currency: 'EGP')
  /// - "بعشرة جنيه" -> (amount: 10.0, currency: 'EGP')
  /// - "بجنيهين" -> (amount: 2.0, currency: 'EGP')
  /// - "50 قرش" -> (amount: 0.5, currency: 'EGP')
  static ({double amount, String currency})? extractMoney(String text) {
    if (text.isEmpty) return null;
    final norm = TextNormalizer.normalize(text);

    // Direct match for dual currency "بجنيهين" or "جنيهين"
    if (norm.contains('جنيهين') || norm.contains('بجنيهين')) {
      return (amount: 2.0, currency: 'EGP');
    }

    // Match patterns like "بـ 100", "ب100", "100 جنيه", "100 ج", "100 EGP"
    // 1. Numeric with currency word
    final numCurrencyReg = RegExp(
      r'(?:بـ?|سعرها|مبلغ)?\s*(\d+(?:\.\d+)?)\s*(جنيه|جنية|ج|egp|قرش|قروش)?',
      caseSensitive: false,
    );
    for (final match in numCurrencyReg.allMatches(norm)) {
      final numStr = match.group(1);
      final currStr = match.group(2);
      if (numStr != null) {
        final val = double.tryParse(numStr);
        if (val != null && val > 0) {
          // If word is قرش, convert to fraction of EGP
          final isQirsh = currStr != null && (currStr == 'قرش' || currStr == 'قروش');
          final finalAmount = isQirsh ? val / 100.0 : val;
          return (amount: finalAmount, currency: 'EGP');
        }
      }
    }

    // 2. Word numbers: "بـ خمسين جنيه", "ألف وخمسمية جنيه", "بعشرة جنيه", "اشتريت حاجات بألف وخمسمية جنيه"
    final wordWithCurrencyReg = RegExp(
      r'([أ-ي0-9\s]+?)\s*(جنيه|جنية|ج|egp|قرش|قروش)',
      caseSensitive: false,
    );
    for (final match in wordWithCurrencyReg.allMatches(norm)) {
      final textBefore = match.group(1)!.trim();
      final currStr = match.group(2);

      // Split into words and test suffixes backwards
      final words = textBefore.split(RegExp(r'\s+'));
      for (var i = 0; i < words.length; i++) {
        final candidate = words.sublist(i).join(' ');
        var cleanCandidate = candidate;
        if (cleanCandidate.startsWith('ب') && cleanCandidate.length > 2 && !cleanCandidate.startsWith('بعد')) {
          cleanCandidate = cleanCandidate.substring(1).trim();
        }
        final parsed = parseNumber(cleanCandidate) ?? parseNumber(candidate);
        if (parsed != null && parsed > 0) {
          final isQirsh = currStr != null && (currStr == 'قرش' || currStr == 'قروش');
          final finalAmount = isQirsh ? parsed / 100.0 : parsed;
          return (amount: finalAmount, currency: 'EGP');
        }
      }
    }

    return null;
  }

  /// Replaces written Arabic number words in a sentence with numeric digits.
  /// Example: "فكرني بعد تلات ايام" -> "فكرني بعد 3 ايام"
  static String convertNumberWordsToDigits(String text) {
    if (text.isEmpty) return text;
    var result = text;

    // Check duals first
    _duals.forEach((word, num) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(word) + '(?=[\\s\u060C,]|\$)');
      if (reg.hasMatch(result)) {
        // e.g. "يومين" -> "2 يوم", "كوبايتين" -> "2 كوباية"
        result = result.replaceAll(reg, '${num.toInt()} $word');
      }
    });

    // Check thousands compounds
    _thousands.forEach((phrase, val) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(phrase) + '(?=[\\s\u060C,]|\$)');
      result = result.replaceAll(reg, val.toInt().toString());
    });

    // Check hundreds
    _hundreds.forEach((phrase, val) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(phrase) + '(?=[\\s\u060C,]|\$)');
      result = result.replaceAll(reg, val.toInt().toString());
    });

    // Check tens
    _tens.forEach((phrase, val) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(phrase) + '(?=[\\s\u060C,]|\$)');
      result = result.replaceAll(reg, val.toInt().toString());
    });

    // Check teens
    _teens.forEach((phrase, val) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(phrase) + '(?=[\\s\u060C,]|\$)');
      result = result.replaceAll(reg, val.toInt().toString());
    });

    // Check single units
    _units.forEach((phrase, val) {
      final reg = RegExp('(?<=^|[\\s\u060C,])' + RegExp.escape(phrase) + '(?=[\\s\u060C,]|\$)');
      result = result.replaceAll(reg, val.toInt().toString());
    });

    return result;
  }
}
