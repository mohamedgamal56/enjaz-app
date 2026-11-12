import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('L10n Hardcoded Text Verification (PLAN.md Section 7 Batch 4)', () {
    test('Scans all presentation widgets and ensures no user-visible hardcoded Arabic strings exist', () {
      final arabicRegex = RegExp(r'[\u0600-\u06FF]');
      // Matches Text('...arabic...') or Text("...arabic...") where arabic characters are hardcoded
      final hardcodedTextRegex = RegExp(r'''Text\(\s*['"]([^'"]*[\u0600-\u06FF][^'"]*)['"]''');

      final presentationDir = Directory('lib/features');
      expect(presentationDir.existsSync(), isTrue, reason: 'lib/features directory must exist');

      final violations = <String>[];

      for (final entity in presentationDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart') && entity.path.contains('presentation')) {
          final lines = entity.readAsLinesSync();
          for (int i = 0; i < lines.length; i++) {
            final line = lines[i];
            // Skip comments
            final trimmed = line.trim();
            if (trimmed.startsWith('//') || trimmed.startsWith('/*')) continue;

            final match = hardcodedTextRegex.firstMatch(line);
            if (match != null) {
              final text = match.group(1);
              if (text != null && arabicRegex.hasMatch(text)) {
                violations.add('${entity.path}:${i + 1} -> "$text"');
              }
            }
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Hardcoded user-visible text found outside ARB files in presentation widgets:\n${violations.join('\n')}\n'
            'All presentation strings must be loaded via AppLocalizations (e.g. l10n.key).',
      );
    });

    test('All required Batch 4 localization keys are present in app_ar.arb and app_en.arb', () {
      final arFile = File('lib/l10n/app_ar.arb');
      final enFile = File('lib/l10n/app_en.arb');

      expect(arFile.existsSync(), isTrue);
      expect(enFile.existsSync(), isTrue);

      final arContent = arFile.readAsStringSync();
      final enContent = enFile.readAsStringSync();

      const requiredKeys = [
        'assistantTitle',
        'assistantRecordByVoice',
        'assistantSettingsAndHelp',
        'assistantUnrecognizedTitle',
        'assistantClearUnrecognized',
        'assistantSpeakResponses',
        'assistantSpeakSensitive',
        'assistantConfirmByVoice',
        'assistantLogUnrecognized',
        'assistantSpeechRate',
        'assistantConfirmWindow',
        'assistantTestVoice',
        'assistantStopSpeaking',
        'assistantDeviceSpeechSettings',
        'assistantTestMic',
        'assistantSettingsHelpNote',
        'assistantPleaseConfirm',
        'assistantAmbiguousCandidateTitle',
        'assistantDateChipNone',
        'assistantDateChipToday',
        'assistantDateChipTomorrow',
        'assistantDateChipCustom',
        'assistantMissingReasonPrompt',
        'assistantBlockedAction',
        'assistantProcessingLocally',
        'assistantCopiedExample',
        'financeInvalidAmount',
        'financeSelectCategory',
        'financeNoCategoriesAvailable',
        'voiceTestScreenTitle',
        'voiceTestReportCopied',
      ];

      for (final key in requiredKeys) {
        expect(arContent, contains('"$key"'), reason: 'Missing $key in app_ar.arb');
        expect(enContent, contains('"$key"'), reason: 'Missing $key in app_en.arb');
      }
    });
  });
}
