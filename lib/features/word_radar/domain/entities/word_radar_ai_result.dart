import '../../../dictionary/domain/entities/lookup_result.dart';

final class WordRadarAiResult {
  const WordRadarAiResult(
      {required this.translation, required this.suggestions});

  final String translation;
  final List<WordPhraseResult> suggestions;
}
