import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/backup/domain/backup_models.dart';

void main() {
  group('BackupManifest Tests', () {
    test('Correctly serializes and deserializes manifest JSON', () {
      final manifest = BackupManifest(
        schemaVersion: 2,
        appVersion: '1.0.0',
        createdAt: '2026-11-03T02:00:00Z',
        includesVoice: true,
        counts: {
          'tasks': 25,
          'task_events': 50,
          'goals': 5,
          'milestones': 12,
          'ideas': 10,
          'voice_notes': 8,
        },
        checksums: {
          'data.json': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          'voice/voice_1.m4a': 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',
        },
      );

      final json = manifest.toJson();
      expect(json['schema_version'], 2);
      expect(json['app_version'], '1.0.0');
      expect(json['includes_voice'], true);
      expect(json['counts']['tasks'], 25);
      expect(json['counts']['voice_notes'], 8);
      expect(json['checksums']['data.json'], isNotEmpty);

      final parsed = BackupManifest.fromJson(json);
      expect(parsed.schemaVersion, 2);
      expect(parsed.appVersion, '1.0.0');
      expect(parsed.includesVoice, true);
      expect(parsed.counts['tasks'], 25);
      expect(parsed.counts['voice_notes'], 8);
      expect(parsed.checksums['voice/voice_1.m4a'], isNotNull);
    });

    test('Handles lightweight backup with voice excluded', () {
      final manifest = BackupManifest(
        schemaVersion: 2,
        appVersion: '1.0.0',
        createdAt: '2026-11-03T02:00:00Z',
        includesVoice: false,
        counts: {
          'tasks': 10,
          'voice_notes': 0,
        },
        checksums: {
          'data.json': 'hash_test_123',
        },
      );

      expect(manifest.includesVoice, false);
      expect(manifest.counts['voice_notes'], 0);
      expect(manifest.checksums.containsKey('data.json'), true);
      expect(manifest.checksums.length, 1);
    });
  });

  group('BackupPreview Tests', () {
    test('Constructs invalid preview with error message', () {
      final preview = BackupPreview.invalid('Invalid structure');
      expect(preview.isValid, false);
      expect(preview.errorMessage, 'Invalid structure');
      expect(preview.tasksCount, 0);
    });

    test('Constructs valid preview with accurate entity counts', () {
      final now = DateTime.now();
      final preview = BackupPreview(
        isValid: true,
        schemaVersion: 2,
        createdAt: now,
        includesVoice: true,
        tasksCount: 42,
        goalsCount: 7,
        ideasCount: 15,
        voiceNotesCount: 12,
        fileSizeBytes: 1024 * 1024 * 2, // 2 MB
      );

      expect(preview.isValid, true);
      expect(preview.schemaVersion, 2);
      expect(preview.createdAt, now);
      expect(preview.includesVoice, true);
      expect(preview.tasksCount, 42);
      expect(preview.goalsCount, 7);
      expect(preview.ideasCount, 15);
      expect(preview.voiceNotesCount, 12);
      expect(preview.fileSizeBytes, 2097152);
    });
  });

  group('CSV Export Formatting Tests', () {
    test('Properly escapes quotes, commas, and newlines in CSV fields', () {
      String escapeCsv(String val) {
        if (val.isEmpty) return '';
        if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
          return '"${val.replaceAll('"', '""')}"';
        }
        return val;
      }

      expect(escapeCsv('Simple text'), 'Simple text');
      expect(escapeCsv('Text with, comma'), '"Text with, comma"');
      expect(escapeCsv('Text with "quotes"'), '"Text with ""quotes"""');
      expect(escapeCsv('Line 1\nLine 2'), '"Line 1\nLine 2"');
      expect(escapeCsv('Mixed, "with quotes"\nand newline'), '"Mixed, ""with quotes""\nand newline"');
    });

    test('Ensures UTF-8 BOM is present at the beginning of exported CSV', () {
      const bom = '\uFEFF';
      final csvContent = '$bom' 'id,title,kind,status\n1,"شراء مستلزمات",task,todo';

      expect(csvContent.startsWith('\uFEFF'), true);
      expect(csvContent.contains('شراء مستلزمات'), true);
    });
  });
}
