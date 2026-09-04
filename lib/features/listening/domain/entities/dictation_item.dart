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

  /// `target` / `vietnamese` / `vocabIds` match apps/web/src/lib/dictation.ts's
  /// `DictationItem`. The web persists the remaining fields on the wrapping
  /// saved-exercise document, not on the item sub-object — serialized here
  /// too so the Flutter entity round-trips on its own.
  Map<String, dynamic> toJson() => {
        'id': id,
        'target': target,
        'vietnamese': vietnamese,
        'vocabIds': vocabIds,
        'level': level.name,
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory DictationItem.fromJson(Map<String, dynamic> json) => DictationItem(
        id: json['id'] as String? ?? '',
        target: json['target'] as String? ?? '',
        vietnamese: json['vietnamese'] as String? ?? '',
        vocabIds: List<String>.from(json['vocabIds'] as List? ?? const []),
        level: json['level'] != null
            ? CEFRLevel.values.byName(json['level'] as String)
            : CEFRLevel.a1,
        context: json['context'] != null
            ? AppContext.values.byName(json['context'] as String)
            : AppContext.general,
        targetLanguage: json['targetLanguage'] != null
            ? Language.values.byName(json['targetLanguage'] as String)
            : Language.english,
        generatedAt: json['generatedAt'] != null
            ? DateTime.parse(json['generatedAt'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0),
      );
}
