import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../data/sources/part6_source.dart';
import '../entities/economy_volume.dart';
import '../entities/part6_passage.dart';

class GeneratePart6SetUseCase {
  const GeneratePart6SetUseCase(this._source);
  final Part6Source _source;

  Future<Part6Set> execute({
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
