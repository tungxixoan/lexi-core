import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/data/sources/reading_passage_source.dart';

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
    _makeRecord('id3', 'endeavor'),
    _makeRecord('id4', 'accomplish'),
    _makeRecord('id5', 'challenge'),
  ];

  final fakeJson = jsonEncode({
    'sentences': [
      {
        'target': 'She showed remarkable perseverance in her work.',
        'vietnamese': 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
        'vocabWords': ['remarkable', 'perseverance'],
      },
      {
        'target': 'Every endeavor requires dedication.',
        'vietnamese': 'Mỗi nỗ lực đều cần sự cống hiến.',
        'vocabWords': ['endeavor'],
      },
      {
        'target': 'You can accomplish any challenge.',
        'vietnamese': 'Bạn có thể hoàn thành bất kỳ thử thách nào.',
        'vocabWords': ['accomplish', 'challenge'],
      },
    ],
  });

  test('parses Gemini JSON into a ReadingPassage', () async {
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(fakeJson),
    );
    final passage = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.sentences.length, 3);
    expect(passage.sentences[0].target,
        'She showed remarkable perseverance in her work.');
    expect(passage.sentences[0].vocabIds, containsAll(['id1', 'id2']));
    expect(passage.sentences[1].vocabIds, ['id3']);
    expect(passage.sentences[2].vocabIds, containsAll(['id4', 'id5']));
    expect(passage.vocabIds, containsAll(['id1', 'id2', 'id3', 'id4', 'id5']));
    expect(passage.level, CEFRLevel.b1);
    expect(passage.targetLanguage, Language.english);
  });

  test('vocabIds are empty when Gemini returns no vocabWords', () async {
    final emptyJson = jsonEncode({
      'sentences': [
        {
          'target': 'Hello world.',
          'vietnamese': 'Xin chào.',
          'vocabWords': [],
        },
      ],
    });
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(emptyJson),
    );
    final passage = await source.generate(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(passage.sentences[0].vocabIds, isEmpty);
    expect(passage.vocabIds, isEmpty);
  });
}
