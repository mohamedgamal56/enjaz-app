import 'dart:convert';

/// Notification identity is independent of the task/reminder owner identity.
class AlarmPayload {
  final int id;
  final String owner;
  final String title;
  final bool sensitive;
  final String languageCode;
  final DateTime? expiresAt;
  final bool snoozed;

  const AlarmPayload(
      {required this.id,
      required this.owner,
      this.title = 'منبه إنجاز',
      this.sensitive = false,
      this.languageCode = 'ar',
      this.expiresAt,
      this.snoozed = false});

  int? get taskId =>
      owner.startsWith('task:') ? int.tryParse(owner.substring(5)) : null;

  String encode() => 'alarm:v2:${jsonEncode({
            'id': id,
            'owner': owner,
            'title': title,
            'sensitive': sensitive,
            'language': languageCode,
            'expiresAt': expiresAt?.toIso8601String(),
            'snoozed': snoozed,
          })}';

  static AlarmPayload? decode(String? payload, {int? notificationId}) {
    if (payload == null || !payload.startsWith('alarm:')) return null;
    if (payload.startsWith('alarm:v2:')) {
      try {
        final data = jsonDecode(payload.substring(9)) as Map<String, dynamic>;
        return AlarmPayload(
            id: notificationId ?? data['id'] as int,
            owner: data['owner'] as String,
            title: data['title'] as String,
            sensitive: data['sensitive'] == true,
            snoozed: data['snoozed'] == true,
            languageCode: data['language'] as String? ?? 'ar',
            expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? ''));
      } catch (_) {
        return null;
      }
    }
    // Old notifications must supply Android's real ID. Never guess from owner.
    if (notificationId == null) return null;
    return AlarmPayload(
        id: notificationId, owner: payload.substring(6), sensitive: true);
  }
}
