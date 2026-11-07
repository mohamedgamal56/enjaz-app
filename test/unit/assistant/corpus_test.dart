import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/rule_based_intent_parser.dart';

void main() {
  group('150-Phrase Egyptian Arabic Corpus Acceptance Test (VOICE.md 10.1)', () {
    final file = File('test/assistant_corpus_ar.json');
    if (!file.existsSync()) {
      fail('Corpus file test/assistant_corpus_ar.json does not exist!');
    }

    final rawJson = file.readAsStringSync();
    final List<dynamic> entries = jsonDecode(rawJson);

    test('Corpus contains at least 150 entries', () {
      expect(entries.length, greaterThanOrEqualTo(150),
          reason: 'Specification 10.1 requires at least 150 corpus phrases');
    });

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i] as Map<String, dynamic>;
      final phrase = entry['phrase'] as String;
      final nowStr = entry['now'] as String;
      final expectedIntent = entry['expected_intent'] as String;
      final expectedSlots = entry['expected_slots'] as Map<String, dynamic>? ?? {};

      final refNow = DateTime.parse(nowStr);
      final parser = RuleBasedIntentParser(nowProvider: () => refNow);

      test('[$i] $expectedIntent: "$phrase"', () {
        final result = parser.parse(phrase, referenceNow: refNow);

        // 1. Validate Intent Type
        expect(
          result.type.nameStr,
          equals(expectedIntent),
          reason: 'Failed intent for phrase: "$phrase" (got: ${result.type.nameStr}, expected: $expectedIntent)',
        );

        // 2. Validate Slots
        for (final slotKey in expectedSlots.keys) {
          final expectedValue = expectedSlots[slotKey];

          switch (slotKey) {
            case 'title':
              expect(result.title, isNotNull, reason: 'Title slot was null in phrase: "$phrase"');
              final expectedTitle = expectedValue.toString();
              final actualTitle = result.title!;
              final matches = actualTitle.contains(expectedTitle) || expectedTitle.contains(actualTitle);
              expect(
                matches,
                isTrue,
                reason: 'Title mismatch for phrase "$phrase": got "$actualTitle", expected to contain "$expectedTitle"',
              );
              break;

            case 'date':
              expect(
                result.dateStr,
                equals(expectedValue),
                reason: 'Date mismatch for phrase "$phrase": got "${result.dateStr}", expected "$expectedValue"',
              );
              break;

            case 'time':
              expect(
                result.timeStr,
                equals(expectedValue),
                reason: 'Time mismatch for phrase "$phrase": got "${result.timeStr}", expected "$expectedValue"',
              );
              break;

            case 'amount':
              final expAmount = (expectedValue as num).toDouble();
              expect(
                result.amount,
                equals(expAmount),
                reason: 'Amount mismatch for phrase "$phrase": got ${result.amount}, expected $expAmount',
              );
              break;

            case 'category':
              expect(
                result.category,
                equals(expectedValue),
                reason: 'Category mismatch for phrase "$phrase": got "${result.category}", expected "$expectedValue"',
              );
              break;

            case 'status':
              expect(
                result.status,
                equals(expectedValue),
                reason: 'Status mismatch for phrase "$phrase": got "${result.status}", expected "$expectedValue"',
              );
              break;

            case 'reason':
              expect(result.reason, isNotNull, reason: 'Reason slot was null for phrase: "$phrase"');
              final expectedReason = expectedValue.toString();
              final actualReason = result.reason!;
              final matches = actualReason.contains(expectedReason) || expectedReason.contains(actualReason);
              expect(
                matches,
                isTrue,
                reason: 'Reason mismatch for phrase "$phrase": got "$actualReason", expected to contain "$expectedReason"',
              );
              break;

            case 'habitKey':
              expect(
                result.habitKey,
                equals(expectedValue),
                reason: 'HabitKey mismatch for phrase "$phrase": got "${result.habitKey}", expected "$expectedValue"',
              );
              break;

            case 'statusFilter':
              expect(
                result.statusFilter,
                equals(expectedValue),
                reason: 'StatusFilter mismatch for phrase "$phrase": got "${result.statusFilter}", expected "$expectedValue"',
              );
              break;

            case 'noteKind':
              expect(
                result.noteKind,
                equals(expectedValue),
                reason: 'NoteKind mismatch for phrase "$phrase": got "${result.noteKind}", expected "$expectedValue"',
              );
              break;

            case 'voiceNoteKind':
              expect(
                result.voiceNoteKind,
                equals(expectedValue),
                reason: 'VoiceNoteKind mismatch for phrase "$phrase": got "${result.voiceNoteKind}", expected "$expectedValue"',
              );
              break;

            case 'healthStatus':
              expect(
                result.healthStatus,
                equals(expectedValue),
                reason: 'HealthStatus mismatch for phrase "$phrase": got "${result.healthStatus}", expected "$expectedValue"',
              );
              break;

            case 'reminderOffsetMinutes':
              expect(
                result.reminderOffsetMinutes,
                equals(expectedValue),
                reason: 'ReminderOffsetMinutes mismatch for phrase "$phrase": got ${result.reminderOffsetMinutes}, expected $expectedValue',
              );
              break;

            case 'period':
              expect(result.slots['period'], isNotNull, reason: 'Period slot was null for phrase "$phrase"');
              expect(
                result.slots['period'].toString(),
                contains(expectedValue.toString()),
                reason: 'Period mismatch for phrase "$phrase": got "${result.slots['period']}", expected "${expectedValue}"',
              );
              break;
          }
        }
      });
    }
  });
}
