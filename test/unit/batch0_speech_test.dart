import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/features/assistant/voice_input_service.dart';

class Source implements SpeechRecognizerSource {
  bool available = true, starts = true;
  String? initError, listenError;
  List<String> locales = ['ar_EG'];
  void Function(String)? error;
  @override
  bool isListening = false;
  @override
  bool get isAvailable => available;
  @override
  Future<bool> initialize(
      {required void Function(String) onStatus,
      required void Function(String) onError}) async {
    error = onError;
    if (initError != null) onError(initError!);
    return available;
  }

  @override
  Future<bool> listen(
      {required void Function(String, bool) onResult, String? localeId}) async {
    if (listenError != null) error!(listenError!);
    return isListening = starts;
  }

  @override
  Future<List<String>> getSupportedLocales() async => locales;
  @override
  Future<void> cancel() async {
    isListening = false;
  }

  @override
  Future<void> stop() async {
    isListening = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Source source;
  late VoiceInputService service;
  setUp(() {
    source = Source();
    service =
        VoiceInputService(source: source, permissionChecker: () async => true);
  });
  tearDown(() => service.dispose());
  test('denied microphone preserves actionable failure', () async {
    service.dispose();
    service =
        VoiceInputService(source: source, permissionChecker: () async => false);
    expect(await service.startListening(), false);
    expect(service.lastErrorCode, 'microphone_denied');
  });
  test('missing recognizer is unsupported', () async {
    source.available = false;
    expect(await service.startListening(), false);
    expect(service.state, VoiceInputState.unsupported);
    expect(service.lastErrorCode, 'speech_unavailable');
  });
  test('initialization network error is not lost', () async {
    source.initError = 'error_network';
    expect(await service.startListening(), false);
    expect(service.lastErrorCode, 'error_network');
  });
  test('missing Arabic in locales list falls back to ar_EG and starts listening', () async {
    source.locales = ['en_US'];
    expect(await service.startListening(), true);
    expect(service.isListening, true);
    expect(service.lastErrorCode, isNull);
  });
  test('failed listen never leaves listening state active', () async {
    source.starts = false;
    expect(await service.startListening(), false);
    expect(service.isListening, false);
    expect(service.state, VoiceInputState.error);
  });
  test('fatal synchronous listen callback cannot become success', () async {
    source.listenError = 'error_network_timeout';
    expect(await service.startListening(), false);
    expect(service.lastErrorCode, 'error_network_timeout');
  });
  test('cancel while permission dialog is open prevents late initialization',
      () async {
    service.dispose();
    final permission = Completer<bool>();
    service = VoiceInputService(
        source: source, permissionChecker: () => permission.future);
    final started = service.startListening();
    await service.cancel();
    permission.complete(true);
    expect(await started, false);
    expect(source.error, isNull);
  });
}
