import 'package:flutter_tts/flutter_tts.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

abstract class TtsService {
  Future<void> speak(String text, Language language);
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  FlutterTtsService(this._tts);

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, Language language) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
