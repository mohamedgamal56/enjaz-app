import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'word_merge_helper.dart';

/// State of the voice recognition engine (VOICE.md Section 2.3 & 3.2).
enum VoiceInputState { idle, listening, processing, error, unsupported }

/// Abstract speech recognition source interface for testability and mocking (VOICE.md Section 10.4).
abstract class SpeechRecognizerSource {
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  });

  Future<bool> listen({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  });

  Future<void> stop();

  Future<void> cancel();

  bool get isListening;

  bool get isAvailable;

  Future<List<String>> getSupportedLocales();
}

/// Production implementation of [SpeechRecognizerSource] wrapping Android's SpeechRecognizer via `speech_to_text`.
class RealSpeechToTextSource implements SpeechRecognizerSource {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    return _stt.initialize(
      onStatus: onStatus,
      onError: (SpeechRecognitionError err) => onError(err.errorMsg),
      debugLogging: false,
    );
  }

  @override
  Future<bool> listen({
    required void Function(String recognizedWords, bool isFinal) onResult,
    String? localeId,
  }) async {
    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenMode: ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
      pauseFor: const Duration(seconds: 3),
    );
    return _stt.isListening;
  }

  @override
  Future<void> stop() => _stt.stop();

  @override
  Future<void> cancel() => _stt.cancel();

  @override
  bool get isListening => _stt.isListening;

  @override
  bool get isAvailable => _stt.isAvailable;

  @override
  Future<List<String>> getSupportedLocales() async {
    final locales = await _stt.locales();
    return locales.map((l) => l.localeId).toList();
  }
}

/// Voice input service managing chained sessions, boundary deduplication, and 60-second limit (VOICE.md Section 3).
class VoiceInputService {
  final SpeechRecognizerSource _source;
  final Duration maxSessionDuration;
  final Future<bool> Function()? permissionChecker;

  VoiceInputState _state = VoiceInputState.idle;
  bool _isUserIntendedListening = false;
  String _accumulatedTranscript = '';
  String _currentSessionTranscript = '';
  String? _selectedLocaleId;
  Timer? _safetyTimeoutTimer;
  Timer? _restartTimer;
  String? lastErrorCode;
  bool _starting = false;
  bool _disposed = false;
  int _generation = 0;
  int _recognizerSession = 0;
  bool _sessionStarting = false;
  bool _stopping = false;

  final _transcriptController = StreamController<String>.broadcast();
  final _finalController = StreamController<String>.broadcast();
  Stream<String> get finalTranscriptStream => _finalController.stream;
  final _stateController = StreamController<VoiceInputState>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  VoiceInputService({
    SpeechRecognizerSource? source,
    this.maxSessionDuration = const Duration(seconds: 60),
    this.permissionChecker,
  }) : _source = source ?? RealSpeechToTextSource();

  VoiceInputState get state => _state;
  bool get isListening => _isUserIntendedListening;
  String get currentTranscript => _buildDisplayTranscript();

  Stream<String> get transcriptStream => _transcriptController.stream;
  Stream<VoiceInputState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Starts listening session with tap-to-start and chained sessions (Section 3.2).
  Future<bool> startListening({String? localePreference}) async {
    if (_disposed || _starting) return false;
    if (_isUserIntendedListening) return true;
    lastErrorCode = null;
    _starting = true;
    final generation = ++_generation;
    try {
      // Check microphone permission
      if (permissionChecker != null) {
        final granted = await permissionChecker!();
        if (!granted) {
          _fail('microphone_denied');
          return false;
        }
      } else {
        final permStatus = await Permission.microphone.request();
        if (!permStatus.isGranted) {
          _fail(permStatus.isPermanentlyDenied ? 'microphone_permanent' : 'microphone_denied');
          return false;
        }
      }

      if (_disposed || generation != _generation) return false;

      // Trigger brief haptic vibration per Section 2.3
      {
        try {
          unawaited(HapticFeedback.lightImpact().catchError((_) {}));
        } catch (_) {}
      }

      // Initialize recognizer
      final initSuccess = await _source.initialize(
        onStatus: (status) {
          if (!_disposed && generation == _generation) _handleStatusChanged(status);
        },
        onError: (error) {
          if (!_disposed && generation == _generation) _handleError(error);
        },
      );

      if (_disposed || generation != _generation) return false;
      if (!initSuccess || lastErrorCode != null) {
        _setState(VoiceInputState.unsupported);
        lastErrorCode ??= 'speech_unavailable';
        if (!_errorController.isClosed) _errorController.add(lastErrorCode!);
        return false;
      }

      // Determine Egyptian Arabic locale (Section 3.1)
      final supportedLocales = await _source.getSupportedLocales();
      if (_disposed || generation != _generation) return false;
      _selectedLocaleId = _resolveArabicLocale(
        supportedLocales,
        localePreference,
      );
      if (_selectedLocaleId == null) {
        _setState(VoiceInputState.unsupported);
        lastErrorCode = 'arabic_missing';
        if (!_errorController.isClosed) _errorController.add(lastErrorCode!);
        return false;
      }

      _isUserIntendedListening = true;
      _accumulatedTranscript = '';
      _currentSessionTranscript = '';
      _emitTranscript('');
      _setState(VoiceInputState.listening);

      // 60-second maximum timeout per Section 3.2
      _safetyTimeoutTimer?.cancel();
      {
        _safetyTimeoutTimer = Timer(maxSessionDuration, () {
          if (_isUserIntendedListening) {
            stopListening();
          }
        });
      }

      return await _startSingleRecognizerSession();
    } catch (error) {
      _fail(error is PlatformException ? error.code : 'speech_failed');
      return false;
    } finally {
      _starting = false;
    }
  }

  /// Stops listening session (Tap-to-stop per Section 3.2) and returns the full merged transcript.
  Future<String> stopListening() async {
    _restartTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    _isUserIntendedListening = false;

    if (_state != VoiceInputState.listening) {
      return _buildDisplayTranscript();
    }

    _setState(VoiceInputState.processing);
    _stopping = true;

    try {
      await _source.stop();
    } catch (_) {}
    _stopping = false;
    _generation++;

    // Finalize merge
    if (_currentSessionTranscript.isNotEmpty) {
      _accumulatedTranscript = WordMergeHelper.merge(
        _accumulatedTranscript,
        _currentSessionTranscript,
      );
      _currentSessionTranscript = '';
    }

    final finalTranscript = _accumulatedTranscript.trim();
    _emitTranscript(finalTranscript);
    _setState(VoiceInputState.idle);

    return finalTranscript;
  }

  /// Cancels listening and resets state without emitting final transcript.
  Future<void> cancel() async {
    _generation++;
    _stopping = false;
    _restartTimer?.cancel();
    _safetyTimeoutTimer?.cancel();
    _isUserIntendedListening = false;
    _accumulatedTranscript = '';
    _currentSessionTranscript = '';
    try {
      await _source.cancel();
    } catch (_) {}
    _emitTranscript('');
    _setState(VoiceInputState.idle);
  }

  /// Internal method to start one underlying recognition session.
  Future<bool> _startSingleRecognizerSession() async {
    if (_disposed || !_isUserIntendedListening || _sessionStarting) return false;
    _sessionStarting = true;
    final generation = _generation;
    final session = ++_recognizerSession;
    try {
      final started = await _source.listen(
        onResult: (words, isFinal) {
          if (_disposed || generation != _generation || session != _recognizerSession || (!_isUserIntendedListening && !_stopping)) return;
          _currentSessionTranscript = words;
          _emitTranscript(_buildDisplayTranscript());

          if (isFinal) {
            if (!_finalController.isClosed) _finalController.add(words);
            _accumulatedTranscript = WordMergeHelper.merge(
              _accumulatedTranscript,
              _currentSessionTranscript,
            );
            _currentSessionTranscript = '';
          }
        },
        localeId: _selectedLocaleId,
      );
      if (_disposed || generation != _generation) return false;
      if (!started && lastErrorCode == null) _fail('speech_failed');
      return started && _isUserIntendedListening;
    } catch (e) {
      _fail(e is PlatformException ? e.code : 'speech_failed');
      return false;
    } finally {
      _sessionStarting = false;
    }
  }

  /// Handles status changes from Android recognizer for session chaining.
  void _handleStatusChanged(String status) {
    if (!_isUserIntendedListening) return;

    // When session completes due to silence, chain a new session seamlessly
    if (status == 'notListening' || status == 'done') {
      if (_currentSessionTranscript.isNotEmpty) {
        _accumulatedTranscript = WordMergeHelper.merge(
          _accumulatedTranscript,
          _currentSessionTranscript,
        );
        _currentSessionTranscript = '';
        _emitTranscript(_accumulatedTranscript);
      }

      // Chain next session after tiny delay to allow recognizer to cycle
      _restartTimer?.cancel();
      _restartTimer = Timer(const Duration(milliseconds: 250), () {
        if (_isUserIntendedListening && _state == VoiceInputState.listening) {
          _startSingleRecognizerSession();
        }
      });
    }
  }

  void _handleError(String errorMsg) {
    if (_disposed || (!_isUserIntendedListening && !_starting)) return;

    // On non-fatal pause errors, try to chain next session if still intended to listen
    if (errorMsg.contains('error_no_match') ||
        errorMsg.contains('error_speech_timeout')) {
      if (_isUserIntendedListening) {
        _restartTimer?.cancel();
        _restartTimer = Timer(const Duration(milliseconds: 250), () {
          if (_isUserIntendedListening) {
            _startSingleRecognizerSession();
          }
        });
        return;
      }
    }

    _fail(errorMsg);
  }

  void _fail(String message) {
    if (_disposed) return;
    lastErrorCode = message;
    _isUserIntendedListening = false;
    _safetyTimeoutTimer?.cancel();
    _restartTimer?.cancel();
    _setState(VoiceInputState.error);
    if (!_errorController.isClosed) _errorController.add(message);
    unawaited(_source.cancel().catchError((_) {}));
  }

  String _buildDisplayTranscript() {
    if (_accumulatedTranscript.isEmpty) {
      return _currentSessionTranscript;
    }
    if (_currentSessionTranscript.isEmpty) {
      return _accumulatedTranscript;
    }
    return WordMergeHelper.merge(
      _accumulatedTranscript,
      _currentSessionTranscript,
    );
  }

  void _setState(VoiceInputState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void _emitTranscript(String text) {
    if (!_transcriptController.isClosed) {
      _transcriptController.add(text);
    }
  }

  /// Resolves the optimal Arabic locale: prefer ar_EG, fallback to ar.
  String? _resolveArabicLocale(List<String> locales, String? preference) {
    if (preference != null && locales.contains(preference)) {
      return preference;
    }
    // Check for Egyptian Arabic variants
    for (final loc in locales) {
      final l = loc.toLowerCase().replaceAll('-', '_');
      if (l == 'ar_eg') return loc;
    }
    // Check for general Arabic
    for (final loc in locales) {
      final l = loc.toLowerCase();
      if (l.startsWith('ar')) return loc;
    }
    return null;
  }

  void dispose() {
    _disposed = true;
    _isUserIntendedListening = false;
    _generation++;
    _restartTimer?.cancel();
    unawaited(_source.cancel().catchError((_) {}));
    _safetyTimeoutTimer?.cancel();
    _transcriptController.close();
    _finalController.close();
    _stateController.close();
    _errorController.close();
  }
}
