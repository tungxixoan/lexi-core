import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum KnowledgeNoteOrigin { ai, manual, starter }

KnowledgeNoteOrigin _originFrom(Object? raw) =>
    KnowledgeNoteOrigin.values.asNameMap()[raw] ?? KnowledgeNoteOrigin.manual;

class KnowledgeExample {
  const KnowledgeExample({required this.text, required this.translation});
  final String text;
  final String translation;

  factory KnowledgeExample.fromJson(Map<String, dynamic> j) => KnowledgeExample(
        text: j['text'] as String? ?? '',
        translation: j['translation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'text': text, 'translation': translation};

  @override
  bool operator ==(Object other) =>
      other is KnowledgeExample &&
      other.text == text &&
      other.translation == translation;
  @override
  int get hashCode => Object.hash(text, translation);
}

class KnowledgeNote {
  const KnowledgeNote({
    required this.id,
    required this.title,
    required this.summary,
    required this.explanation,
    this.patterns = const [],
    this.examples = const [],
    this.pitfalls = const [],
    required this.groupId,
    this.tags = const [],
    this.cefrLevel,
    required this.targetLanguage,
    required this.origin,
    this.sourcePrompt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String summary;
  final String explanation;
  final List<String> patterns;
  final List<KnowledgeExample> examples;
  final List<String> pitfalls;
  final String groupId;
  final List<String> tags;
  final CEFRLevel? cefrLevel;
  final Language targetLanguage;
  final KnowledgeNoteOrigin origin;
  final String? sourcePrompt;
  final DateTime createdAt;
  final DateTime updatedAt;

  static List<String> _stringList(Object? raw) =>
      raw is List ? raw.whereType<String>().toList() : const [];

  /// Parses a stored date defensively. Accepts an ISO-8601 [String] (what this
  /// app writes), a Firestore [Timestamp] or an `int` of epoch millis (either
  /// of which a future web client might write). Anything else — including
  /// `null` — falls back to the Unix epoch (UTC) so a single malformed doc
  /// sorts to the bottom rather than throwing.
  static DateTime _parseDate(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  factory KnowledgeNote.fromJson(Map<String, dynamic> j) => KnowledgeNote(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        explanation: j['explanation'] as String? ?? '',
        patterns: _stringList(j['patterns']),
        examples: (j['examples'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(KnowledgeExample.fromJson)
            .toList(),
        pitfalls: _stringList(j['pitfalls']),
        groupId: j['groupId'] as String? ?? '',
        tags: _stringList(j['tags']),
        cefrLevel:
            CEFRLevel.values.asNameMap()[(j['cefrLevel'] as String?) ?? ''],
        targetLanguage: Language.values.asNameMap()[j['targetLanguage']] ??
            Language.english,
        origin: _originFrom(j['source']),
        sourcePrompt: j['sourcePrompt'] as String?,
        createdAt: _parseDate(j['createdAt']),
        updatedAt: _parseDate(j['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'explanation': explanation,
        'patterns': patterns,
        'examples': examples.map((e) => e.toJson()).toList(),
        'pitfalls': pitfalls,
        'groupId': groupId,
        'tags': tags,
        'cefrLevel': cefrLevel?.name,
        'targetLanguage': targetLanguage.name,
        'source': origin.name,
        'sourcePrompt': sourcePrompt,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  KnowledgeNote copyWith({
    String? title,
    String? summary,
    String? explanation,
    List<String>? patterns,
    List<KnowledgeExample>? examples,
    List<String>? pitfalls,
    String? groupId,
    List<String>? tags,
    CEFRLevel? cefrLevel,
    bool clearCefr = false,
    KnowledgeNoteOrigin? origin,
    String? sourcePrompt,
    DateTime? updatedAt,
  }) =>
      KnowledgeNote(
        id: id,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        explanation: explanation ?? this.explanation,
        patterns: patterns ?? this.patterns,
        examples: examples ?? this.examples,
        pitfalls: pitfalls ?? this.pitfalls,
        groupId: groupId ?? this.groupId,
        tags: tags ?? this.tags,
        cefrLevel: clearCefr ? null : (cefrLevel ?? this.cefrLevel),
        targetLanguage: targetLanguage,
        origin: origin ?? this.origin,
        sourcePrompt: sourcePrompt ?? this.sourcePrompt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
