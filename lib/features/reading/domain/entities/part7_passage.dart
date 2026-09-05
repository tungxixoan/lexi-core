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

  /// Keys match apps/web/src/lib/part7.ts's `Part7Question`.
  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory Part7Question.fromJson(Map<String, dynamic> json) => Part7Question(
        question: json['question'] as String? ?? '',
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int? ?? 0,
        explanation: json['explanation'] as String? ?? '',
      );
}

final class Part7PassageGroup {
  const Part7PassageGroup({required this.documents, required this.questions});

  final List<String> documents; // 1 (single-passage) or 2 (double-passage)
  final List<Part7Question>
      questions; // 3-4 for single-passage, 5 for double-passage

  /// Keys match apps/web/src/lib/part7.ts's `Part7PassageGroup`.
  Map<String, dynamic> toJson() => {
        'documents': documents,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory Part7PassageGroup.fromJson(Map<String, dynamic> json) =>
      Part7PassageGroup(
        documents: List<String>.from(json['documents'] as List? ?? const []),
        questions: (json['questions'] as List? ?? const [])
            .map((q) => Part7Question.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
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
  final List<Part7PassageGroup>
      passageGroups; // always 3: [single, single, double]
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;

  /// `passageGroups` matches apps/web/src/lib/part7.ts's `Part7Set`. The web
  /// persists the remaining fields on the wrapping saved-exercise document,
  /// not on the passage sub-object — serialized here too so the Flutter
  /// entity round-trips on its own.
  Map<String, dynamic> toJson() => {
        'id': id,
        'passageGroups': passageGroups.map((g) => g.toJson()).toList(),
        'volumes': volumes.map((v) => v.name).toList(),
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory Part7Set.fromJson(Map<String, dynamic> json) => Part7Set(
        id: json['id'] as String? ?? '',
        passageGroups: (json['passageGroups'] as List? ?? const [])
            .map((g) => Part7PassageGroup.fromJson(g as Map<String, dynamic>))
            .toList(),
        volumes: (json['volumes'] as List? ?? const [])
            .map((v) => EconomyVolume.tryParse(v as String))
            .whereType<EconomyVolume>()
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
