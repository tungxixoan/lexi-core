import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';

class _FakeClient implements GenerativeModelClient {
  _FakeClient(this.response);
  final String response;
  String? capturedPrompt;
  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    capturedPrompt = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');
    return GenerateContentResponse(
      [Candidate(Content.text(response), null, null, null, null)], null);
  }
}

void main() {
  const good = '''
{"title":"Câu điều kiện loại 2","summary":"Giả định trái hiện tại.",
"explanation":"Dùng **were**.","patterns":["If + S + V-past, S + would + V"],
"examples":[{"text":"If I were you","translation":"Nếu tôi là bạn"}],
"pitfalls":["Đừng dùng was."],"suggestedGroupId":"en_conditionals",
"suggestedCefr":"b1","suggestedTags":["ngu-phap"],"relatedNoteId":null}
''';

  test('parses a well-formed draft', () async {
    final client = _FakeClient(good);
    final draft = await KnowledgeNoteSource.withModel(client).draft(
      request: 'giải thích loại 2',
      targetLanguage: Language.english,
      existingInScope: const [],
    );
    expect(draft.title, 'Câu điều kiện loại 2');
    expect(draft.suggestedGroupId, 'en_conditionals');
    expect(draft.suggestedCefr, CEFRLevel.b1);
    expect(draft.examples.single.translation, 'Nếu tôi là bạn');
    expect(draft.relatedNoteId, isNull);
  });

  test('prompt lists the language group ids and the existing notes', () async {
    final client = _FakeClient(good);
    await KnowledgeNoteSource.withModel(client).draft(
      request: 'x', targetLanguage: Language.english, existingInScope: const []);
    expect(client.capturedPrompt, contains('en_conditionals'));
  });

  test('garbage response throws (best-effort caller handles it)', () async {
    final client = _FakeClient('not json at all');
    expect(
      () => KnowledgeNoteSource.withModel(client).draft(
        request: 'x', targetLanguage: Language.english, existingInScope: const []),
      throwsA(anything),
    );
  });

  test('missing optional fields default safely', () async {
    final client = _FakeClient('{"title":"T","summary":"S","explanation":"E"}');
    final draft = await KnowledgeNoteSource.withModel(client).draft(
      request: 'x', targetLanguage: Language.english, existingInScope: const []);
    expect(draft.patterns, isEmpty);
    expect(draft.suggestedGroupId, isNull);
    expect(draft.suggestedCefr, isNull);
  });
}
