import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../data/sources/dictation_source.dart';
import '../entities/dictation_item.dart';

class GenerateDictationItemUseCase {
  const GenerateDictationItemUseCase(this._source);
  final DictationSource _source;

  Future<DictationItem> execute({
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
