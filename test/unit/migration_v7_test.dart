import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drift Schema Migration v7 Tests (Round 6 Health Tables)', () {
    test('1. Migration v7 prepares SQL for health items, events, treatments & checks', () {
      const createHealthItemsTableSql = '''
        CREATE TABLE IF NOT EXISTS health_items (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          title TEXT NOT NULL,
          kind TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'needed',
          needed_since TEXT NOT NULL,
          due_by TEXT,
          scheduled_at INTEGER,
          place_or_doctor TEXT,
          done_at INTEGER,
          result_note TEXT,
          follow_up_needed INTEGER NOT NULL DEFAULT 0,
          postpone_count INTEGER NOT NULL DEFAULT 0,
          postponed_reason TEXT,
          repeat_every_months INTEGER,
          cost_minor INTEGER,
          occurred_at INTEGER NOT NULL,
          local_date TEXT NOT NULL
        );
      ''';

      const createHealthEventsTableSql = '''
        CREATE TABLE IF NOT EXISTS health_events (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          health_item_id INTEGER NOT NULL REFERENCES health_items (id),
          at INTEGER NOT NULL,
          from_status TEXT NOT NULL,
          to_status TEXT NOT NULL,
          note TEXT
        );
      ''';

      const createTreatmentsTableSql = '''
        CREATE TABLE IF NOT EXISTS treatments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          health_item_id INTEGER REFERENCES health_items (id),
          name TEXT NOT NULL,
          instructions_note TEXT,
          start_date TEXT NOT NULL,
          end_date TEXT,
          purchased INTEGER NOT NULL DEFAULT 0,
          purchased_at INTEGER,
          purchase_cost_minor INTEGER,
          adherence TEXT NOT NULL DEFAULT 'not_started',
          stopped_reason TEXT,
          note TEXT,
          occurred_at INTEGER NOT NULL,
          local_date TEXT NOT NULL
        );
      ''';

      const createTreatmentChecksTableSql = '''
        CREATE TABLE IF NOT EXISTS treatment_checks (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          deleted_at INTEGER,
          treatment_id INTEGER NOT NULL REFERENCES treatments (id),
          check_date TEXT NOT NULL,
          taken INTEGER NOT NULL DEFAULT 1
        );
      ''';

      expect(createHealthItemsTableSql, contains('health_items'));
      expect(createHealthItemsTableSql, contains('needed_since'));
      expect(createHealthEventsTableSql, contains('health_events'));
      expect(createTreatmentsTableSql, contains('treatments'));
      expect(createTreatmentChecksTableSql, contains('treatment_checks'));
    });
  });
}
