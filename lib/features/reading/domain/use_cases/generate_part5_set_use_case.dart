import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part5_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part5_question.dart';

class GeneratePart5SetUseCase {
  const GeneratePart5SetUseCase(this._source);
  final Part5Source _source;

  Future<Part5Set> execute({
    required AppContext context,
    required Language targetLanguage,
    required Set<EconomyVolume> volumes,
  }) =>
      _source.generate(
        context: context,
        targetLanguage: targetLanguage,
        volumes: volumes,
      );
}
