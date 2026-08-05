import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'economy_volume.dart';

final class Part6Question {
  const Part6Question({
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  final List<String> options; // always 4 — words/phrases OR full sentences
  final int correctIndex; // 0-3
  final String explanation; // Vietnamese, why the correct option is right
}

final class Part6Passage {
  const Part6Passage({required this.passageText, required this.questions});

  final String passageText; // blanks inline, e.g. "... the office (1)___ Monday ..."
  final List<Part6Question> questions; // always 4, ordered to match blank numbering
}

final class Part6Set {
  const Part6Set({
    required this.id,
    required this.passages,
    required this.volumes,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<Part6Passage> passages; // always 3
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
