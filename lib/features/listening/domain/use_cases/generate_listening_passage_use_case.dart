import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/listening_passage_source.dart';
import '../entities/listening_passage.dart';

class GenerateListeningPassageUseCase {
  const GenerateListeningPassageUseCase(this._source);
  final ListeningPassageSource _source;

  Future<ListeningPassage> execute({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) =>
      _source.generate(
        level: level,
        context: context,
        targetLanguage: targetLanguage,
      );
}
