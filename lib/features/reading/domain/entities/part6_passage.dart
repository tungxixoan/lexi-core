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

  /// Keys match apps/web/src/lib/part6.ts's `Part6Question`.
  Map<String, dynamic> toJson() => {
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory Part6Question.fromJson(Map<String, dynamic> json) => Part6Question(
        options: List<String>.from(json['options'] as List? ?? const []),
        correctIndex: json['correctIndex'] as int? ?? 0,
        explanation: json['explanation'] as String? ?? '',
      );
}

final class Part6Passage {
  const Part6Passage({required this.passageText, required this.questions});

  final String
      passageText; // blanks inline, e.g. "... the office (1)___ Monday ..."
  final List<Part6Question>
      questions; // always 4, ordered to match blank numbering

  /// Keys match apps/web/src/lib/part6.ts's `Part6Passage`.
  Map<String, dynamic> toJson() => {
        'passageText': passageText,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory Part6Passage.fromJson(Map<String, dynamic> json) => Part6Passage(
        passageText: json['passageText'] as String? ?? '',
        questions: (json['questions'] as List? ?? const [])
            .map((q) => Part6Question.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
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

  /// `passages` matches apps/web/src/lib/part6.ts's `Part6Set`. The web
  /// persists the remaining fields on the wrapping saved-exercise document,
  /// not on the passage sub-object — serialized here too so the Flutter
  /// entity round-trips on its own.
  Map<String, dynamic> toJson() => {
        'id': id,
        'passages': passages.map((p) => p.toJson()).toList(),
        'volumes': volumes.map((v) => v.name).toList(),
        'context': context.name,
        'targetLanguage': targetLanguage.name,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory Part6Set.fromJson(Map<String, dynamic> json) => Part6Set(
        id: json['id'] as String? ?? '',
        passages: (json['passages'] as List? ?? const [])
            .map((p) => Part6Passage.fromJson(p as Map<String, dynamic>))
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
