import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/voice_notes/domain/voice_note_service.dart';

void main() {
  group('VoiceNoteService Tests (Addendum v1.1)', () {
    test('formatDuration formats milliseconds correctly', () {
      expect(VoiceNoteService.formatDuration(0), '00:00');
      expect(VoiceNoteService.formatDuration(5000), '00:05');
      expect(VoiceNoteService.formatDuration(65000), '01:05');
      expect(VoiceNoteService.formatDuration(3600000), '60:00');
    });

    test('formatFileSize formats bytes correctly', () {
      expect(VoiceNoteService.formatFileSize(0), '0 KB');
      expect(VoiceNoteService.formatFileSize(512 * 1024), '512 KB');
      expect(VoiceNoteService.formatFileSize(1572864), '1.5 MB'); // 1.5 * 1024 * 1024
    });

    test('requiresDiscardConfirmation returns true only after 5000ms', () {
      expect(VoiceNoteService.requiresDiscardConfirmation(2000), false);
      expect(VoiceNoteService.requiresDiscardConfirmation(5000), false);
      expect(VoiceNoteService.requiresDiscardConfirmation(5001), true);
      expect(VoiceNoteService.requiresDiscardConfirmation(10000), true);
    });

    test('generateVoiceOnlyTitle creates correct title in Arabic and English', () {
      final date = DateTime(2026, 11, 2, 10, 30);
      final arTitle = VoiceNoteService.generateVoiceOnlyTitle(date: date, isArabic: true);
      expect(arTitle, contains('تسجيل صوتي'));
      expect(arTitle, contains('نوفمبر'));
      expect(arTitle, contains('2'));

      final enTitle = VoiceNoteService.generateVoiceOnlyTitle(date: date, isArabic: false);
      expect(enTitle, contains('Voice note'));
      expect(enTitle, contains('Nov'));
    });
  });
}
