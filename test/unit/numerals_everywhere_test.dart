import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:enjaz/core/utils/date_formatter.dart';
import 'package:enjaz/core/utils/money_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar', null);
  });

  group('Numerals Everywhere Verification (PLAN.md Section 7 Batch 4)', () {
    test('Digit conversion between Western and Arabic-Indic numerals', () {
      const western = '0123456789';
      const arabic = '٠١٢٣٤٥٦٧٨٩';

      expect(
        AppFormatter.formatStringDigits(western, format: NumeralsFormat.arabicIndic),
        equals(arabic),
      );
      expect(
        AppFormatter.formatStringDigits(arabic, format: NumeralsFormat.western),
        equals(western),
      );
    });

    test('Number formatting converts integers and floats accurately', () {
      expect(
        AppFormatter.formatNumber(100, format: NumeralsFormat.arabicIndic),
        equals('١٠٠'),
      );
      expect(
        AppFormatter.formatNumber(100, format: NumeralsFormat.western),
        equals('100'),
      );
      expect(
        AppFormatter.formatNumber(2026, format: NumeralsFormat.arabicIndic),
        equals('٢٠٢٦'),
      );
    });

    test('Date formatting applies chosen numeral system to Arabic locale output', () {
      final date = DateTime(2026, 11, 12);

      final arabicFormatted = AppFormatter.formatDate(
        date,
        locale: 'ar',
        format: NumeralsFormat.arabicIndic,
      );
      expect(arabicFormatted, contains('٢٠٢٦'));
      expect(arabicFormatted, contains('١٢'));

      final westernFormatted = AppFormatter.formatDate(
        date,
        locale: 'ar',
        format: NumeralsFormat.western,
      );
      expect(westernFormatted, contains('2026'));
      expect(westernFormatted, contains('12'));
    });

    test('Date and Time formatting applies chosen numeral system', () {
      final dateTime = DateTime(2026, 5, 20, 14, 30);

      final arTime = AppFormatter.formatDateTime(
        dateTime,
        locale: 'ar',
        format: NumeralsFormat.arabicIndic,
      );
      expect(arTime, contains('٢٠٢٦'));
      expect(arTime, contains('٢٠'));

      final westTime = AppFormatter.formatDateTime(
        dateTime,
        locale: 'ar',
        format: NumeralsFormat.western,
      );
      expect(westTime, contains('2026'));
      expect(westTime, contains('20'));
    });

    test('MoneyFormatter formatAmount formats minor units according to numeral setting', () {
      // 125000 minor units = 1250 major
      expect(
        MoneyFormatter.formatAmount(125000, format: NumeralsFormat.western, showDecimals: false),
        equals('1250'),
      );
      expect(
        MoneyFormatter.formatAmount(125000, format: NumeralsFormat.arabicIndic, showDecimals: false),
        equals('١٢٥٠'),
      );

      // Decimals (e.g. 1250.75)
      expect(
        MoneyFormatter.formatAmount(125075, format: NumeralsFormat.western),
        equals('1250.75'),
      );
      expect(
        MoneyFormatter.formatAmount(125075, format: NumeralsFormat.arabicIndic),
        equals('١٢٥٠.٧٥'),
      );
    });

    test('MoneyFormatter formatWithCurrency includes currency symbol and respects numerals', () {
      final westCurrency = MoneyFormatter.formatWithCurrency(
        50000,
        currency: 'ج.م',
        format: NumeralsFormat.western,
        showDecimals: false,
      );
      expect(westCurrency, equals('500 ج.م'));

      final arCurrency = MoneyFormatter.formatWithCurrency(
        50000,
        currency: 'ج.م',
        format: NumeralsFormat.arabicIndic,
        showDecimals: false,
      );
      expect(arCurrency, equals('٥٠٠ ج.م'));
    });

    test('MoneyFormatter handles masked mode consistently across numerals', () {
      expect(
        MoneyFormatter.formatAmount(99999, masked: true, format: NumeralsFormat.arabicIndic),
        equals('••••'),
      );
      expect(
        MoneyFormatter.formatWithCurrency(99999, masked: true, currency: 'ج.م'),
        equals('•••• ج.م'),
      );
    });

    test('MoneyFormatter parseToMinor correctly parses both Western and Arabic-Indic user input', () {
      expect(MoneyFormatter.parseToMinor('150'), equals(15000));
      expect(MoneyFormatter.parseToMinor('١٥٠'), equals(15000));
      expect(MoneyFormatter.parseToMinor('25.50'), equals(2550));
      expect(MoneyFormatter.parseToMinor('٢٥٫٥٠'), equals(2550));
      expect(MoneyFormatter.parseToMinor('٢٥.٥'), equals(2550));
    });
  });
}
