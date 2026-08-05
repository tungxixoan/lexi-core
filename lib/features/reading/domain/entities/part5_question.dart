import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part5Question {
  const Part5Question({
    required this.sentenceWithBlank,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String sentenceWithBlank; // contains exactly one '___'
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part5Set {
  const Part5Set({
    required this.id,
    required this.questions,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part5Question> questions; // always 15 items
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
