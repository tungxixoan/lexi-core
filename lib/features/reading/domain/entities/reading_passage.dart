import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';

final class BilingualSentence {
  const BilingualSentence({
    required this.target,
    required this.vietnamese,
    required this.vocabIds,
  });

  final String target;
  final String vietnamese;
  final List<String> vocabIds; // VocabRecord.id values used in this sentence

  factory BilingualSentence.fromJson(Map<String, dynamic> json) =>
      BilingualSentence(
        target: json['target'] as String,
        vietnamese: json['vietnamese'] as String,
        vocabIds: List<String>.from(json['vocabIds'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'target': target,
        'vietnamese': vietnamese,
        'vocabIds': vocabIds,
      };
}

final class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.sentences,
    required this.vocabIds,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<BilingualSentence> sentences;
  final List<String> vocabIds; // union of all sentence.vocabIds
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
