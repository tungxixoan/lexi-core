import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/word_radar_source.dart';
import '../entities/word_radar_ai_result.dart';

class GenerateWordSuggestionsUseCase {
  const GenerateWordSuggestionsUseCase(this._source);
  final WordRadarSource _source;

  Future<WordRadarAiResult> execute({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
  }) =>
      _source.scan(
        text: text,
        targetLanguage: targetLanguage,
        targetCefrLevel: targetCefrLevel,
        knownHeadwords: knownHeadwords,
      );
}
