import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NumeralsFormat { western, arabicIndic }

final numeralsProvider =
    StateNotifierProvider<NumeralsNotifier, NumeralsFormat>((ref) {
  return NumeralsNotifier();
});

class NumeralsNotifier extends StateNotifier<NumeralsFormat> {
  NumeralsNotifier() : super(NumeralsFormat.western) {
    _load();
  }

  static const _key = 'app_numerals';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    if (val == 'arabic') {
      state = NumeralsFormat.arabicIndic;
    } else {
      state = NumeralsFormat.western;
    }
  }

  Future<void> setFormat(NumeralsFormat format) async {
    state = format;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      format == NumeralsFormat.arabicIndic ? 'arabic' : 'western',
    );
  }
}

class AppFormatter {
  AppFormatter._();

  static const Map<String, String> _westernToArabicDigits = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };

  static const Map<String, String> _arabicToWesternDigits = {
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

  static String formatNumber(num number, {NumeralsFormat format = NumeralsFormat.western}) {
    final str = number.toString();
    if (format == NumeralsFormat.western) {
      return str.split('').map((char) => _arabicToWesternDigits[char] ?? char).join();
    }
    return str.split('').map((char) => _westernToArabicDigits[char] ?? char).join();
  }

  static String formatDate(DateTime date, {required String locale, NumeralsFormat format = NumeralsFormat.western}) {
    final formatted = DateFormat.yMMMMd(locale).format(date);
    if (format == NumeralsFormat.arabicIndic) {
      return formatted.split('').map((char) => _westernToArabicDigits[char] ?? char).join();
    }
    return formatted.split('').map((char) => _arabicToWesternDigits[char] ?? char).join();
  }

  static String formatDateTime(DateTime date, {required String locale, NumeralsFormat format = NumeralsFormat.western}) {
    final formatted = DateFormat.yMMMd(locale).add_jm().format(date);
    if (format == NumeralsFormat.arabicIndic) {
      return formatted.split('').map((char) => _westernToArabicDigits[char] ?? char).join();
    }
    return formatted.split('').map((char) => _arabicToWesternDigits[char] ?? char).join();
  }

  static String formatWeekday(DateTime date, {required String locale}) {
    return DateFormat.EEEE(locale).format(date);
  }
}
