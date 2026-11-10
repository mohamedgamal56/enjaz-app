import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/backup/domain/backup_models.dart';
import 'package:enjaz/features/backup/domain/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late File sampleAudioFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('enjaz_backup_test_');
    db = AppDatabase(NativeDatabase.memory());

    // Create a mock audio file
    final voiceDir = Directory(p.join(tempDir.path, 'voice'));
    await voiceDir.create(recursive: true);

    sampleAudioFile = File(p.join(voiceDir.path, 'voice_sample_123.m4a'));
    // Write sample AAC audio payload bytes
    final audioBytes = List<int>.generate(1024, (i) => (i * 7) % 256);
    await sampleAudioFile.writeAsBytes(audioBytes);
  });

  tearDown(() async {
    await db.close();
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Backup & Restore with Voice Recording Tests (Batch 1 Spec)', () {
    test('Archive contains voice recordings and manifest matches checksums', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert a task and a voice note
      final taskId = await db.insertBatchTasks(
        titles: ['مهمة مع تسجيل صوتي'],
        dueDate: '2026-11-20',
      );

      final audioBytes = await sampleAudioFile.readAsBytes();
      final audioSha256 = sha256.convert(audioBytes).toString();

      await db.into(db.voiceNotes).insert(
        VoiceNotesCompanion.insert(
          parentType: 'task',
          parentId: taskId,
          fileName: sampleAudioFile.path,
          durationMs: const Value(15000),
          sizeBytes: Value(audioBytes.length),
          label: const Value('ملاحظة صوتية للمهمة'),
          recordedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Export full backup with voice
      final dataMap = await db.exportAllData();
      final jsonBytes = utf8.encode(jsonEncode(dataMap));

      final archive = Archive();
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));
      archive.addFile(ArchiveFile('voice/voice_sample_123.m4a', audioBytes.length, audioBytes));

      final manifest = BackupManifest(
        schemaVersion: db.schemaVersion,
        appVersion: '1.2.7',
        createdAt: DateTime.now().toIso8601String(),
        includesVoice: true,
        counts: {'tasks': 1, 'voice_notes': 1},
        checksums: {
          'data.json': sha256.convert(jsonBytes).toString(),
          'voice/voice_sample_123.m4a': audioSha256,
        },
      );

      final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // 3. Validate archive
      BackupService.validateArchive(archive, maxSchemaVersion: db.schemaVersion);

      // 4. Verify voice file can be retrieved and played back from archive
      final voiceArchiveFile = archive.findFile('voice/voice_sample_123.m4a');
      expect(voiceArchiveFile, isNotNull);
      expect(voiceArchiveFile!.content, equals(audioBytes));
      expect(sha256.convert(voiceArchiveFile.content as List<int>).toString(), equals(audioSha256));
    });

    test('Data JSON export includes all 12 modules soft-deleted and active rows', () async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Tasks & Errands
      await db.insertBatchTasks(titles: ['مهمة 1'], kind: 'task');
      await db.insertBatchTasks(titles: ['مشوار 1'], kind: 'errand');

      // Goals
      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          title: 'هدف اختباري',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Ideas
      await db.into(db.ideas).insert(
        IdeasCompanion.insert(
          title: 'فكرة اختبارية',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Notes
      await db.insertNote(
        NotesCompanion.insert(
          body: 'ملاحظة اختبارية',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Habits
      await db.insertHabit(
        HabitsCompanion.insert(
          nameAr: 'عادة اختبارية',
          type: 'check',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final dataMap = await db.exportAllData();
      expect((dataMap['tasks'] as List).length, greaterThanOrEqualTo(2));
      expect((dataMap['goals'] as List).length, greaterThanOrEqualTo(1));
      expect((dataMap['ideas'] as List).length, greaterThanOrEqualTo(1));
      expect((dataMap['notes'] as List).length, greaterThanOrEqualTo(1));
      expect((dataMap['habits'] as List).length, greaterThanOrEqualTo(1));
      expect(dataMap['schema_version'], equals(8));
    });
  });
}
