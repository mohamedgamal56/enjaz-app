import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _engine = FlutterTts();
  bool _closed = false;
  int _generation = 0;
  Future<bool> speak(String text, {double rate = 0.5}) async {
    if (_closed) return false;
    final generation = ++_generation;
    try {
      final voices = await _engine.getVoices as List;
      final localArabic = voices
          .where(
            (v) =>
                v['locale'].toString().startsWith('ar') &&
                v['network_required'] != true,
          )
          .toList();
      if (localArabic.isEmpty || _closed || generation != _generation) return false;
      final voice = localArabic.first;
      await _engine.setVoice({
        'name': voice['name'].toString(),
        'locale': voice['locale'].toString(),
      });
      await _engine.setSpeechRate(rate.clamp(0.2, 0.8));
      await _engine.awaitSpeakCompletion(true);
      if (_closed || generation != _generation) return false;
      await _engine.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _generation++;
    try {
      await _engine.stop();
    } catch (_) {}
  }

  void dispose() {
    _closed = true;
    stop();
  }
}
