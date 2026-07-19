import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

final class DictationItem {
  const DictationItem({
    required this.id,
    required this.target,
    required this.vietnamese,
    required this.vocabIds,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final String target;
  final String vietnamese;
  final List<String> vocabIds; // VocabRecord.id values used in this sentence
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
