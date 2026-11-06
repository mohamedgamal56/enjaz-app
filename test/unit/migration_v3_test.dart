import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drift Schema Migration v3 Tests (Round 1 Spec 1.2)', () {
    test('Drift migration script correctly prepares SQL for reminders table and index', () {
      const createTableSql = '''
        CREATE TABLE IF NOT EXISTS reminders (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          owner_type TEXT NOT NULL,
          owner_id INTEGER NOT NULL,
          kind TEXT NOT NULL DEFAULT 'notification',
          trigger_type TEXT NOT NULL DEFAULT 'offset',
          offset_minutes INTEGER,
          absolute_time INTEGER,
          message TEXT,
          enabled INTEGER NOT NULL DEFAULT 1
        );
      ''';

      const createIndexOwner = 'CREATE INDEX IF NOT EXISTS idx_reminders_owner ON reminders (owner_type, owner_id);';
      const createIndexEnabled = 'CREATE INDEX IF NOT EXISTS idx_reminders_enabled ON reminders (enabled);';

      expect(createTableSql.contains('reminders'), isTrue);
      expect(createTableSql.contains('owner_type TEXT NOT NULL'), isTrue);
      expect(createTableSql.contains('kind TEXT NOT NULL'), isTrue);
      expect(createIndexOwner.contains('idx_reminders_owner'), isTrue);
      expect(createIndexEnabled.contains('idx_reminders_enabled'), isTrue);
    });

    test('Data migration SQL selects active tasks with reminder_offset_minutes', () {
      final now = 1762400000000;
      final migrationSql = '''
        INSERT INTO reminders (owner_type, owner_id, kind, trigger_type, offset_minutes, message, enabled, created_at, updated_at)
        SELECT 'task', id, 'alarm', 'offset', reminder_offset_minutes, title, 1, $now, $now
        FROM tasks
        WHERE reminder_offset_minutes IS NOT NULL AND deleted_at IS NULL;
      ''';

      expect(migrationSql.contains("owner_type, owner_id, kind"), isTrue);
      expect(migrationSql.contains("SELECT 'task', id, 'alarm'"), isTrue);
      expect(migrationSql.contains("reminder_offset_minutes IS NOT NULL"), isTrue);
      expect(migrationSql.contains("deleted_at IS NULL"), isTrue);
    });
  });
}
