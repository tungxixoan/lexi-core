import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/listening/data/sources/dictation_source.dart';

class FakeGenerativeModelClient implements GenerativeModelClient {
  FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

VocabRecord _makeRecord(String id, String headword) => VocabRecord(
      id: id,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'test meaning',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  final words = [
    _makeRecord('id1', 'perseverance'),
    _makeRecord('id2', 'remarkable'),
  ];

  final fakeJson = jsonEncode({
    'target': 'She showed remarkable perseverance in her work.',
    'vietnamese': 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
    'vocabWords': ['remarkable', 'perseverance'],
  });

  test('parses AI JSON into a DictationItem', () async {
    final source = DictationSource.withModel(
      FakeGenerativeModelClient(fakeJson),
    );
    final item = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(item.target, 'She showed remarkable perseverance in her work.');
    expect(item.vietnamese, 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.');
    expect(item.vocabIds, containsAll(['id1', 'id2']));
    expect(item.level, CEFRLevel.b1);
    expect(item.context, AppContext.general);
    expect(item.targetLanguage, Language.english);
    expect(item.id, isNotEmpty);
  });

  test('vocabIds is empty when AI returns no vocabWords', () async {
    final emptyJson = jsonEncode({
      'target': 'Hello world.',
      'vietnamese': 'Xin chào thế giới.',
      'vocabWords': [],
    });
    final source = DictationSource.withModel(
      FakeGenerativeModelClient(emptyJson),
    );
    final item = await source.generate(
      words: words,
      level: CEFRLevel.a1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(item.vocabIds, isEmpty);
  });
}
