import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';

final class BilingualSentence {
  const BilingualSentence({
    required this.target,
    required this.vietnamese,
    required this.vocabIds,
    this.vocabWords = const [],
  });

  final String target;
  final String vietnamese;
  final List<String> vocabIds; // VocabRecord.id values used in this sentence
  final List<String>
      vocabWords; // raw headwords — web reads this key, not vocabIds

  factory BilingualSentence.fromJson(Map<String, dynamic> json) =>
      BilingualSentence(
        target: json['target'] as String? ?? '',
        vietnamese: json['vietnamese'] as String? ?? '',
        vocabIds: List<String>.from(json['vocabIds'] as List? ?? const []),
        vocabWords: List<String>.from(json['vocabWords'] as List? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'target': target,
        'vietnamese': vietnamese,
        'vocabIds': vocabIds, // Flutter's own reuse path reads this
        'vocabWords':
            vocabWords, // web's PassageReview reads this (highlightVocabWords)
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

  /// The full generated passage as plain text, e.g. for copying elsewhere
  /// (Word Radar and the like).
  String get fullText => sentences.map((s) => s.target).join(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'sentences': sentences.map((s) => s.toJson()).toList(),
        'vocabIds': vocabIds,
        'level': level.name,
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  /// Defensive against a web-saved `bilingual` passage sub-object, which carries
  /// only `{sentences, vocabIds}` — no id/level/context/targetLanguage/
  /// generatedAt (web persists those on the wrapping saved-exercise doc). Mirrors
  /// the guarded-default idiom the sibling entities use (`Part5Set.fromJson`
  /// etc.).
  factory ReadingPassage.fromJson(Map<String, dynamic> json) => ReadingPassage(
        id: json['id'] as String? ?? '',
        sentences: (json['sentences'] as List? ?? const [])
            .map((s) => BilingualSentence.fromJson(s as Map<String, dynamic>))
            .toList(),
        vocabIds: List<String>.from(json['vocabIds'] as List? ?? const []),
        level: json['level'] != null
            ? CEFRLevel.values.byName(json['level'] as String)
            : CEFRLevel.b1,
        context: json['context'] != null
            ? AppContext.values.byName(json['context'] as String)
            : AppContext.general,
        targetLanguage: json['targetLanguage'] != null
            ? Language.values.byName(json['targetLanguage'] as String)
            : Language.english,
        generatedAt: json['generatedAt'] != null
            ? DateTime.parse(json['generatedAt'] as String)
            : DateTime.now(),
      );
}
