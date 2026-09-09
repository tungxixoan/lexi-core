// lib/features/knowledge/data/sources/knowledge_note_source.dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';

export '../../../../core/services/ai_client_factory.dart'
    show GenerativeModelClient;

class KnowledgeNoteDraft {
  const KnowledgeNoteDraft({
    required this.title,
    required this.summary,
    required this.explanation,
    this.patterns = const [],
    this.examples = const [],
    this.pitfalls = const [],
    this.suggestedGroupId,
    this.suggestedCefr,
    this.suggestedTags = const [],
    this.relatedNoteId,
  });

  final String title;
  final String summary;
  final String explanation;
  final List<String> patterns;
  final List<KnowledgeExample> examples;
  final List<String> pitfalls;
  final String? suggestedGroupId;
  final CEFRLevel? suggestedCefr;
  final List<String> suggestedTags;
  final String? relatedNoteId;
}

class KnowledgeNoteSource {
  KnowledgeNoteSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);
  KnowledgeNoteSource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  static List<String> _stringList(Object? v) => v is List
      ? v.whereType<String>().toList()
      : (v is String && v.isNotEmpty ? [v] : const []);

  Future<KnowledgeNoteDraft> draft({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) async {
    final prompt = _buildPrompt(
      request: request,
      targetLanguage: targetLanguage,
      hintGroupId: hintGroupId,
      hintCefr: hintCefr,
      existingInScope: existingInScope,
      extendingNote: extendingNote,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final json = parseAiJsonObject(response.text ?? '');
    final rawGroupId =
        (json['suggestedGroupId'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['suggestedGroupId'] as String).trim();
    final validGroupIds =
        knowledgeGroupsFor(targetLanguage).map((g) => g.id).toSet();
    // A hallucinated / wrong-language id would land the note in no group card
    // (the grid only iterates this language's taxonomy) — funnel it to "Khác".
    final suggestedGroupId = rawGroupId == null
        ? null
        : (validGroupIds.contains(rawGroupId)
            ? rawGroupId
            : knowledgeOtherGroupId(targetLanguage));
    return KnowledgeNoteDraft(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      patterns: _stringList(json['patterns']),
      examples: (json['examples'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(KnowledgeExample.fromJson)
          .toList(),
      pitfalls: _stringList(json['pitfalls']),
      suggestedGroupId: suggestedGroupId,
      suggestedCefr: CEFRLevel.values
          .asNameMap()[(json['suggestedCefr'] as String?)?.trim().toLowerCase()],
      suggestedTags: _stringList(json['suggestedTags']),
      relatedNoteId: (json['relatedNoteId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['relatedNoteId'] as String).trim(),
    );
  }

  String _buildPrompt({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) {
    final groups = knowledgeGroupsFor(targetLanguage)
        .map((g) => '${g.id} (${g.label})')
        .join('; ');
    final existing = existingInScope.isEmpty
        ? 'None.'
        : existingInScope
            .map((n) => '- id=${n.id} | ${n.title} | ${n.summary}')
            .join('\n');
    final hintClause = [
      if (hintGroupId != null) 'Prefer groupId "$hintGroupId".',
      if (hintCefr != null) 'Target CEFR ${hintCefr.label}.',
    ].join(' ');
    final extendClause = extendingNote == null
        ? ''
        : 'You are REVISING this existing note — merge the new request into it '
            'and return the full updated note:\n'
            '${extendingNote.toJson()}\n';
    return 'You are a grammar reference assistant for a Vietnamese speaker '
        'learning ${targetLanguage.label}. Write a single reference note '
        'answering this request: "$request". $hintClause\n'
        '$extendClause'
        'Available groupId values: $groups\n'
        'Existing notes in the same area (for de-duplication):\n$existing\n'
        'All prose and translations must be in Vietnamese (Vietnamese script '
        'only). In "explanation" and each "pitfalls" item you may wrap key '
        'terms in **double asterisks** for bold; use \\n\\n between paragraphs; '
        'no other markup. '
        'Respond with JSON only (no code fences): '
        '{"title":"short Vietnamese title","summary":"1-2 Vietnamese sentences",'
        '"explanation":"...","patterns":["form strings, may be empty"],'
        '"examples":[{"text":"target-language sentence","translation":"Vietnamese"}],'
        '"pitfalls":["common mistakes, may be empty"],'
        '"suggestedGroupId":"one id from the list above",'
        '"suggestedCefr":"a1|a2|b1|b2|c1|c2 or null",'
        '"suggestedTags":["0-3 short kebab-case Vietnamese-friendly tags"],'
        '"relatedNoteId":"the id of an existing note this substantially '
        'duplicates, or null"}';
  }
}
