import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:enjaz/core/db/app_database.dart';
import 'package:enjaz/features/assistant/presentation/assistant_sheet.dart';
import 'package:enjaz/features/assistant/presentation/voice_test_screen.dart';
import 'package:enjaz/features/assistant/voice_input_service.dart';

class FakeSpeechRecognizerSource implements SpeechRecognizerSource {
  @override
  bool isListening = false;

  @override
  bool isAvailable = true;

  void Function(String words, bool isFinal)? onResultCallback;

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    return true;
  }

  @override
  Future<bool> listen({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    isListening = true;
    onResultCallback = onResult;
    return true;
  }

  @override
  Future<void> stop() async {
    isListening = false;
  }

  @override
  Future<void> cancel() async {
    isListening = false;
  }

  @override
  Future<List<String>> getSupportedLocales() async => ['ar_EG', 'en_US'];

  void emitTranscript(String words, {bool isFinal = false}) {
    onResultCallback?.call(words, isFinal);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSpeechRecognizerSource fakeSource;
  late VoiceInputService voiceService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeSource = FakeSpeechRecognizerSource();
    voiceService = VoiceInputService(source: fakeSource);
  });

  tearDown(() async {
    voiceService.dispose();
    await db.close();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar', 'EG'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ar', 'EG'),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Voice Input UI Tests (VOICE.md Step 5 & Section 10.4)', () {
    testWidgets('AssistantSheet renders mic button and updates on live speech transcript', (tester) async {
      await tester.pumpWidget(createTestWidget(AssistantSheet(voiceService: voiceService)));
      await tester.pump();

      // Verify microphone button exists
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('اضغط على المايك وابدأ الكلام'), findsOneWidget);

      // Verify test wizard shortcut button exists
      expect(find.byIcon(Icons.science_outlined), findsOneWidget);

      // Tap mic to start listening
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(voiceService.isListening, isTrue);

      // Simulate spoken words
      fakeSource.emitTranscript('صرفت 100 جنيه بنزين للموتوسيكل');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify transcript is rendered
      expect(find.text('صرفت 100 جنيه بنزين للموتوسيكل'), findsOneWidget);
    });

    testWidgets('VoiceTestScreen renders all 30 test sentences and allows test interaction', (tester) async {
      await tester.pumpWidget(createTestWidget(VoiceTestScreen(voiceService: voiceService)));
      await tester.pumpAndSettle();

      // Verify title and copy button
      expect(find.text('اختبار التعرف الصوتي (30 جملة)'), findsOneWidget);
      expect(find.byIcon(Icons.copy_all_rounded), findsOneWidget);

      // Verify first sentence
      expect(find.text('صرفت 100 جنيه بنزين للموتوسيكل النهارده'), findsOneWidget);

      // Verify mode toggle
      expect(find.text('🌐 وضع عادي'), findsOneWidget);
      await tester.tap(find.text('🌐 وضع عادي'));
      await tester.pumpAndSettle();
      expect(find.text('✈️ وضع الطيران'), findsOneWidget);
    });
  });
}
