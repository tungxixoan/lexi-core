import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part7Question {
  const Part7Question({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part7PassageGroup {
  const Part7PassageGroup({required this.documents, required this.questions});

  final List<String> documents; // 1 (single-passage) or 2 (double-passage)
  final List<Part7Question> questions; // 3-4 for single-passage, 5 for double-passage
}

final class Part7Set {
  const Part7Set({
    required this.id,
    required this.passageGroups,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part7PassageGroup> passageGroups; // always 3: [single, single, double]
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
