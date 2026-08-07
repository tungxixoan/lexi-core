import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part7_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part7_passage.dart';

class GeneratePart7SetUseCase {
  const GeneratePart7SetUseCase(this._source);
  final Part7Source _source;

  Future<Part7Set> execute({
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
