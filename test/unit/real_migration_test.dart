import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:enjaz/core/db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File tempDbFile;
  late AppDatabase db;

  setUp(() async {
    final assetFile = File(p.join('test', 'assets', 'enjaz_v1.1.5_sample.sqlite'));
    expect(await assetFile.exists(), isTrue, reason: 'v1.1.5 asset file must exist');

    final tempDir = await Directory.systemTemp.createTemp('enjaz_migration_test_');
    tempDbFile = File(p.join(tempDir.path, 'migrated_enjaz.sqlite'));
    await assetFile.copy(tempDbFile.path);

    // Open real SQLite database file with NativeDatabase executor
    db = AppDatabase(NativeDatabase(tempDbFile));
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDbFile.exists()) {
        await tempDbFile.delete();
      }
    } catch (_) {}
  });

  group('Real SQLite Migration Tests (v1.1.5 Schema v2 -> Current Schema v8)', () {
    test('Migrates real SQLite database file successfully without data loss', () async {
      // 1. Verify schema version upgraded to 8
      expect(db.schemaVersion, equals(8));

      // 2. Query original v1.1.5 tasks
      final tasks = await db.getAllTasksList();
      expect(tasks.length, equals(2));

      final task1 = tasks.firstWhere((t) => t.id == 1);
      expect(task1.title, equals('مهمة عمل هامة'));
      expect(task1.status, equals('todo'));
      expect(task1.priority, equals('high'));
      expect(task1.dueDate, equals('2026-11-20'));
      expect(task1.dueTime, equals('10:00'));

      final task2 = tasks.firstWhere((t) => t.id == 2);
      expect(task2.title, equals('مهمة منتهية'));
      expect(task2.status, equals('done'));

      // 3. Verify task reminders were migrated into shared reminders table (Round 1 Spec 1.2)
      final reminders = await db.getRemindersForOwner('task', 1);
      expect(reminders.isNotEmpty, isTrue);
      expect(reminders.first.offsetMinutes, equals(15));
      expect(reminders.first.kind, equals('alarm'));

      // 4. Verify original goals remain intact
      final goals = await (db.select(db.goals)).get();
      expect(goals.length, equals(1));
      expect(goals.first.title, equals('قراءة 10 كتب'));
      expect(goals.first.targetValue, equals(10.0));
      expect(goals.first.currentValue, equals(3.0));

      // 5. Verify original ideas remain intact
      final ideas = await (db.select(db.ideas)).get();
      expect(ideas.length, equals(1));
      expect(ideas.first.title, equals('فكرة مشروع إنجاز'));

      // 6. Verify original settings remain intact
      final setting = await db.getSetting('app_theme');
      expect(setting, equals('dark'));

      // 7. Verify original voice notes remain intact
      final voiceNotes = await db.getAllVoiceNotesList();
      expect(voiceNotes.length, equals(1));
      expect(voiceNotes.first.fileName, equals('voice/voice_sample.m4a'));
      expect(voiceNotes.first.parentId, equals(1));

      // 8. Verify all new tables created in migrations v4-v8 can receive operations
      // Note table (v4)
      final noteId = await db.insertNote(
        NotesCompanion.insert(
          body: 'ملاحظة بعد الترحيل',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      expect(noteId, isPositive);

      // Habit table (v5)
      final habitId = await db.insertHabit(
        HabitsCompanion.insert(
          nameAr: 'عادة القراءة',
          type: 'check',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      expect(habitId, isPositive);

      // Finance transaction (v6)
      final txId = await db.insertTransaction(
        TransactionsCompanion.insert(
          kind: 'expense',
          amountMinor: 5000,
          categoryId: 1,
          occurredAt: DateTime.now().millisecondsSinceEpoch,
          localDate: '2026-11-10',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      expect(txId, isPositive);

      // Health item (v7)
      final healthId = await db.insertHealthItemWithEvent(
        HealthItemsCompanion.insert(
          title: 'فحص دوري',
          kind: 'checkup',
          neededSince: '2026-11-10',
          occurredAt: DateTime.now().millisecondsSinceEpoch,
          localDate: '2026-11-10',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      expect(healthId, isPositive);
    });
  });
}
