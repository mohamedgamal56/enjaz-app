import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores technical outcomes only, without notification titles or user data.
class NotificationDiagnostics {
  static const key = 'notification_diagnostics_v1';
  static Future<void> _writes = Future.value();

  static Future<void> record(String code, {int? id}) {
    _writes = _writes.then((_) => _record(code, id: id)).catchError((_) {});
    return _writes;
  }

  static Future<void> _record(String code, {int? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(key) ?? [];
    entries.insert(
        0,
        jsonEncode({
          'at': DateTime.now().toIso8601String(),
          'code': code,
          'id': id,
        }));
    await prefs.setStringList(key, entries.take(30).toList());
  }

  static Future<List<String>> read() async {
    await _writes;
    return (await SharedPreferences.getInstance()).getStringList(key) ?? [];
  }
}
