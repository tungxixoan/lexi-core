import 'package:flutter_tts/flutter_tts.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

abstract class TtsService {
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate});
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  FlutterTtsService(this._tts) {
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate}) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.setPitch(pitch);
    if (rate != null) await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
