import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/reminders/domain/alarm_payload.dart';

void main() {
  test('two reminders for one task preserve different Android IDs', () {
    for (final id in [73, 92]) {
      final decoded = AlarmPayload.decode(AlarmPayload(
              id: id, owner: 'task:4', title: 'موعد: مهم', sensitive: true)
          .encode())!;
      expect(decoded.id, id);
      expect(decoded.taskId, 4);
      expect(decoded.title, 'موعد: مهم');
      expect(decoded.sensitive, isTrue);
    }
  });
  test('legacy upgrade uses actual response ID, never task ID', () {
    expect(AlarmPayload.decode('alarm:task:4'), isNull);
    final alarm = AlarmPayload.decode('alarm:task:4', notificationId: 73)!;
    expect(alarm.id, 73);
    expect(alarm.taskId, 4);
    expect(alarm.sensitive, isTrue);
  });
  test('non-task alarms preserve identity and malformed payload is ignored',
      () {
    final alarm = AlarmPayload.decode(
        const AlarmPayload(id: 37, owner: 'treatment:12', sensitive: true)
            .encode())!;
    expect(alarm.id, 37);
    expect(alarm.taskId, isNull);
    expect(alarm.owner, 'treatment:12');
    expect(AlarmPayload.decode('alarm:v2:broken'), isNull);
  });
}
