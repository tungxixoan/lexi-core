import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/reading_passage_source.dart';
import '../entities/reading_passage.dart';

class GenerateReadingPassageUseCase {
  const GenerateReadingPassageUseCase(this._source);
  final ReadingPassageSource _source;

  Future<ReadingPassage> execute({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) =>
      _source.generate(
        words: words,
        level: level,
        context: context,
        targetLanguage: targetLanguage,
      );
}
