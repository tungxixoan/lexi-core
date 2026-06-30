import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';

class InputDetector {
  InputDetector._();

  static const _phraseMaxWords = 4;
  static final _terminalPunctuation = RegExp(r'[.?!]\s*$');

  static InputType detect(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return InputType.word;
    if (_terminalPunctuation.hasMatch(trimmed)) return InputType.sentence;

    final wordCount = trimmed.split(RegExp(r'\s+')).length;
    if (wordCount > _phraseMaxWords) return InputType.sentence;
    if (wordCount >= 2) return InputType.phrase;
    return InputType.word;
  }
}
