import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/utils/date_formatter.dart';

void main() {
  group('AppFormatter Numerals Tests (Round 0)', () {
    test('Formats numbers with Western digits by default', () {
      expect(AppFormatter.formatNumber(0, format: NumeralsFormat.western), '0');
      expect(AppFormatter.formatNumber(42, format: NumeralsFormat.western), '42');
      expect(AppFormatter.formatNumber(2026, format: NumeralsFormat.western), '2026');
    });

    test('Formats numbers with Arabic-Indic digits when selected', () {
      expect(AppFormatter.formatNumber(0, format: NumeralsFormat.arabicIndic), '٠');
      expect(AppFormatter.formatNumber(42, format: NumeralsFormat.arabicIndic), '٤٢');
      expect(AppFormatter.formatNumber(2026, format: NumeralsFormat.arabicIndic), '٢٠٢٦');
    });

    test('Ensures dates in Arabic locale use Western digits when NumeralsFormat.western is set', () {
      final date = DateTime(2026, 11, 6);
      final formatted = AppFormatter.formatDate(date, locale: 'ar', format: NumeralsFormat.western);
      // Must contain Western digits 6 and 2026, not ٦ or ٢٠٢٦
      expect(formatted.contains('2026'), isTrue);
      expect(formatted.contains('6'), isTrue);
      expect(formatted.contains('٢٠٢٦'), isFalse);
      expect(formatted.contains('٦'), isFalse);
    });

    test('Ensures dates in Arabic locale use Arabic-Indic digits when NumeralsFormat.arabicIndic is set', () {
      final date = DateTime(2026, 11, 6);
      final formatted = AppFormatter.formatDate(date, locale: 'ar', format: NumeralsFormat.arabicIndic);
      expect(formatted.contains('٢٠٢٦'), isTrue);
      expect(formatted.contains('٦'), isTrue);
    });
  });
}
