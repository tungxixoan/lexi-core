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

  /// Keys match apps/web/src/lib/part5.ts's `Part5Question`.
  Map<String, dynamic> toJson() => {
        'sentenceWithBlank': sentenceWithBlank,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory Part5Question.fromJson(Map<String, dynamic> json) => Part5Question(
        sentenceWithBlank: json['sentenceWithBlank'] as String? ?? '',
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int? ?? 0,
        explanation: json['explanation'] as String? ?? '',
      );
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

  /// `questions` matches apps/web/src/lib/part5.ts's `Part5Set`. The web
  /// persists the remaining fields on the wrapping saved-exercise document
  /// (`generationFilters` / `targetLanguage` / `createdAt` / `id`), not on
  /// the passage sub-object — they are serialized here too so the Flutter
  /// entity round-trips on its own.
  Map<String, dynamic> toJson() => {
        'id': id,
        'questions': questions.map((q) => q.toJson()).toList(),
        'volumes': volumes.map((v) => v.name).toList(),
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory Part5Set.fromJson(Map<String, dynamic> json) => Part5Set(
        id: json['id'] as String? ?? '',
        questions: (json['questions'] as List? ?? const [])
            .map((q) => Part5Question.fromJson(q as Map<String, dynamic>))
            .toList(),
        volumes: (json['volumes'] as List? ?? const [])
            .map((v) => EconomyVolume.values.byName(v as String))
            .toSet(),
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
