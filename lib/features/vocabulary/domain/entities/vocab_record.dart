import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'cefr_level.dart';

final class VocabRecord {
  const VocabRecord({
    required this.id,
    required this.headword,
    required this.inputType,
    required this.ipa,
    required this.meaning,
    required this.examples,
    required this.personalNotes,
    required this.topicIds,
    required this.targetLanguage,
    required this.cefrLevel,
    required this.activeContext,
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.sm2Repetitions = 0,
    this.sm2EaseFactor = 2.5,
    this.sm2Interval = 1,
  });

  final String id;
  final String headword;
  final InputType inputType; // word or phrase only — sentences not saveable
  final String ipa;
  final String meaning;
  final List<String> examples;
  final String personalNotes;
  final List<String> topicIds; // max 2
  final Language targetLanguage;
  final CEFRLevel cefrLevel;
  final AppContext activeContext;
  final DateTime createdAt;
  final DateTime updatedAt;
  // SM-2 fields — used by Plan 3 (Spaced Repetition); stored from Plan 2 onwards
  final DateTime? nextReviewAt;
  final int sm2Repetitions;
  final double sm2EaseFactor;
  final int sm2Interval;

  VocabRecord copyWith({
    String? meaning,
    List<String>? examples,
    String? personalNotes,
    List<String>? topicIds,
    DateTime? updatedAt,
    DateTime? nextReviewAt,
    int? sm2Repetitions,
    double? sm2EaseFactor,
    int? sm2Interval,
  }) =>
      VocabRecord(
        id: id,
        headword: headword,
        inputType: inputType,
        ipa: ipa,
        meaning: meaning ?? this.meaning,
        examples: examples ?? this.examples,
        personalNotes: personalNotes ?? this.personalNotes,
        topicIds: topicIds ?? this.topicIds,
        targetLanguage: targetLanguage,
        cefrLevel: cefrLevel,
        activeContext: activeContext,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        sm2Repetitions: sm2Repetitions ?? this.sm2Repetitions,
        sm2EaseFactor: sm2EaseFactor ?? this.sm2EaseFactor,
        sm2Interval: sm2Interval ?? this.sm2Interval,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'headword': headword,
        'inputType': inputType.name,
        'ipa': ipa,
        'meaning': meaning,
        'examples': examples,
        'personalNotes': personalNotes,
        'topicIds': topicIds,
        'targetLanguage': targetLanguage.name,
        'cefrLevel': cefrLevel.name,
        'activeContext': activeContext.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nextReviewAt': nextReviewAt?.toIso8601String(),
        'sm2Repetitions': sm2Repetitions,
        'sm2EaseFactor': sm2EaseFactor,
        'sm2Interval': sm2Interval,
      };

  factory VocabRecord.fromJson(Map<String, dynamic> json) => VocabRecord(
        id: json['id'] as String,
        headword: json['headword'] as String,
        inputType: InputType.values.byName(json['inputType'] as String),
        ipa: json['ipa'] as String,
        meaning: json['meaning'] as String,
        examples: List<String>.from(json['examples'] as List),
        personalNotes: json['personalNotes'] as String? ?? '',
        topicIds: List<String>.from(json['topicIds'] as List),
        targetLanguage: Language.values.byName(json['targetLanguage'] as String),
        cefrLevel: CEFRLevel.values.byName(json['cefrLevel'] as String),
        activeContext: AppContext.values.byName(json['activeContext'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        nextReviewAt: json['nextReviewAt'] != null
            ? DateTime.parse(json['nextReviewAt'] as String)
            : null,
        sm2Repetitions: json['sm2Repetitions'] as int? ?? 0,
        sm2EaseFactor: (json['sm2EaseFactor'] as num?)?.toDouble() ?? 2.5,
        sm2Interval: json['sm2Interval'] as int? ?? 1,
      );
}
