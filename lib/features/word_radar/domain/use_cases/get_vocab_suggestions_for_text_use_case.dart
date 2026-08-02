import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'find_known_headwords_use_case.dart';
import 'generate_word_suggestions_use_case.dart';
import '../entities/word_radar_ai_result.dart';

class GetVocabSuggestionsForTextUseCase {
  const GetVocabSuggestionsForTextUseCase(this._findKnown, this._generate);
  final FindKnownHeadwordsUseCase _findKnown;
  final GenerateWordSuggestionsUseCase _generate;

  Future<WordRadarAiResult> execute({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
  }) async {
    final known = await _findKnown.execute(text: text, language: targetLanguage);
    return _generate.execute(
      text: text,
      targetLanguage: targetLanguage,
      targetCefrLevel: targetCefrLevel,
      knownHeadwords: known.map((r) => r.headword).toList(),
      includeTranslation: false,
    );
  }
}
