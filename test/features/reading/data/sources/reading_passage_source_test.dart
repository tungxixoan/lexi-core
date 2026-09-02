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
  String? lastPrompt;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    lastPrompt = (prompt.first.parts.first as TextPart).text;
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

  test('normalizes smart quotes and ellipsis in target and vietnamese', () async {
    // Curly punctuation as \u escapes so the fixture survives tool pipelines:
    // \u2019 apostrophe, \u201C / \u201D double quotes, \u2026 ellipsis.
    final smartJson = jsonEncode({
      'sentences': [
        {
          'target': 'It\u2019s \u201Cok\u201D.',
          'vietnamese': '\u201CTot\u201D\u2026',
          'vocabWords': <String>[],
        },
      ],
    });
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(smartJson),
    );
    final passage = await source.generate(
      words: const [],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(passage.sentences.single.target, 'It\'s "ok".');
    expect(passage.sentences.single.vietnamese, '"Tot"...');
  });

  test('resolves a vocabId when the AI returns a differently-cased word', () async {
    final record = _makeRecord('rid1', 'Report');
    final casedJson = jsonEncode({
      'sentences': [
        {
          'target': 'He sent the report.',
          'vietnamese': 'Anh ay da gui bao cao.',
          'vocabWords': ['report'],
        },
      ],
    });
    final source = ReadingPassageSource.withModel(
      FakeGenerativeModelClient(casedJson),
    );
    final passage = await source.generate(
      words: [record],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(passage.sentences.single.vocabIds, [record.id]);
  });

  test('keeps the original headword casing in the prompt word list', () async {
    final fake = FakeGenerativeModelClient(fakeJson);
    final source = ReadingPassageSource.withModel(fake);
    await source.generate(
      words: [_makeRecord('rid1', 'Report')],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(fake.lastPrompt, contains('Report'));
  });

  test('prompt instructs natural sentence-position capitalization', () async {
    final fake = FakeGenerativeModelClient(fakeJson);
    final source = ReadingPassageSource.withModel(fake);
    await source.generate(
      words: [_makeRecord('rid1', 'Report'), _makeRecord('rid2', 'Follow up')],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(fake.lastPrompt!.toLowerCase(), contains('natural'));
    expect(fake.lastPrompt!.toLowerCase(), contains('capitaliz'));
    expect(fake.lastPrompt, isNot(contains('exactly as given')));
    expect(fake.lastPrompt, contains('matched case-insensitively'));
  });

  group('prompt scales with the number of vocabulary words', () {
    test('asks for about 6 sentences for a 5-word selection', () async {
      final fake = FakeGenerativeModelClient(fakeJson);
      final source = ReadingPassageSource.withModel(fake);
      await source.generate(
        words: words, // 5 words
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );
      expect(fake.lastPrompt, contains('about 6 sentences'));
    });

    test('asks for more sentences (capped at 12) for a 20-word selection', () async {
      final manyWords = List.generate(
        20,
        (i) => _makeRecord('id$i', 'word$i'),
      );
      final fake = FakeGenerativeModelClient(fakeJson);
      final source = ReadingPassageSource.withModel(fake);
      await source.generate(
        words: manyWords,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );
      expect(fake.lastPrompt, contains('about 12 sentences'));
    });

    test('asks the model to weave in extra level-appropriate vocabulary beyond the given list',
        () async {
      final fake = FakeGenerativeModelClient(fakeJson);
      final source = ReadingPassageSource.withModel(fake);
      await source.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );
      expect(fake.lastPrompt, contains('beyond this list'));
    });
  });
}
