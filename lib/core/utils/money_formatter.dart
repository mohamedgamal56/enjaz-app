import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'date_formatter.dart';

final financeMaskedProvider = StateNotifierProvider<FinanceMaskedNotifier, bool>((ref) {
  return FinanceMaskedNotifier();
});

class FinanceMaskedNotifier extends StateNotifier<bool> {
  FinanceMaskedNotifier() : super(false) {
    _load();
  }

  static const _key = 'finance_amounts_masked';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }

  Future<void> setMasked(bool masked) async {
    state = masked;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, masked);
  }
}

class MoneyFormatter {
  MoneyFormatter._();

  /// Converts piasters/minor units to major unit string (e.g. 1250 piasters -> "12.50" or "12.5")
  static String formatAmount(
    int minorUnits, {
    bool masked = false,
    NumeralsFormat format = NumeralsFormat.western,
    bool showDecimals = true,
  }) {
    if (masked) {
      return '••••';
    }

    final isNegative = minorUnits < 0;
    final absMinor = minorUnits.abs();
    final major = absMinor ~/ 100;
    final remainder = absMinor % 100;

    String text;
    if (remainder == 0 && !showDecimals) {
      text = major.toString();
    } else if (remainder == 0) {
      text = '$major';
    } else if (remainder % 10 == 0) {
      text = '$major.${remainder ~/ 10}';
    } else {
      text = '$major.${remainder.toString().padLeft(2, '0')}';
    }

    final formatted = AppFormatter.formatStringDigits(text, format: format);
    return isNegative ? '-$formatted' : formatted;
  }

  /// Formats amount with currency (e.g. "12.50 ج.م" or "•••• ج.م")
  static String formatWithCurrency(
    int minorUnits, {
    String currency = 'ج.م',
    bool masked = false,
    NumeralsFormat format = NumeralsFormat.western,
    bool showDecimals = true,
  }) {
    if (masked) {
      return '•••• $currency';
    }
    final amountStr = formatAmount(
      minorUnits,
      masked: false,
      format: format,
      showDecimals: showDecimals,
    );
    return '$amountStr $currency';
  }

  /// Convenience alias for formatWithCurrency
  static String formatMinorWithCurrency(
    int minorUnits, {
    String currency = 'ج.م',
    bool masked = false,
    NumeralsFormat format = NumeralsFormat.western,
    bool showDecimals = true,
  }) {
    return formatWithCurrency(
      minorUnits,
      currency: currency,
      masked: masked,
      format: format,
      showDecimals: showDecimals,
    );
  }

  /// Parses decimal text entered by user (e.g. "25.50" or "25,5" or Arabic digits "٢٥٫٥") into minor units
  static int parseToMinor(String input) {
    if (input.trim().isEmpty) return 0;
    // Normalize Arabic digits and commas
    var normalized = AppFormatter.formatStringDigits(input, format: NumeralsFormat.western);
    normalized = normalized.replaceAll('،', '.').replaceAll(',', '.').trim();

    final val = double.tryParse(normalized);
    if (val == null) return 0;
    return (val * 100).round();
  }
}
