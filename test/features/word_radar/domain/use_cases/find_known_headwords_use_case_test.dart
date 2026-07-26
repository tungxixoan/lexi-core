import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';

VocabRecord _record(
  String headword, {
  Language language = Language.english,
  String? meaning,
}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: meaning ?? 'meaning of $headword',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: language,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      language == null
          ? records
          : records.where((r) => r.targetLanguage == language).toList();

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async => false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async => null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

void main() {
  test('finds the VocabRecord for a headword that appears as a substring in the text',
      () async {
    final repo = _FakeVocabRepository([_record('serendipity')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'It was pure serendipity that we met.',
      language: Language.english,
    );

    expect(result, hasLength(1));
    expect(result[0].headword, 'serendipity');
  });

  test('matches case-insensitively', () async {
    final repo = _FakeVocabRepository([_record('Hello')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'hello there, how are you?',
      language: Language.english,
    );

    expect(result, hasLength(1));
    expect(result[0].headword, 'Hello');
  });

  test('returns no duplicates when a headword appears multiple times', () async {
    final repo = _FakeVocabRepository([_record('cat')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'The cat sat near another cat.',
      language: Language.english,
    );

    expect(result, hasLength(1));
    expect(result[0].headword, 'cat');
  });

  test('matches Chinese headwords with no spaces around them', () async {
    final repo = _FakeVocabRepository([
      _record('你好', language: Language.chinese),
    ]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: '今天你好吗',
      language: Language.chinese,
    );

    expect(result, hasLength(1));
    expect(result[0].headword, '你好');
  });

  test('excludes headwords that do not appear in the text', () async {
    final repo = _FakeVocabRepository([_record('elephant')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'This text has nothing to do with animals.',
      language: Language.english,
    );

    expect(result, isEmpty);
  });

  test('returns an empty list when the Vocab Bank has no records', () async {
    final repo = _FakeVocabRepository(const []);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'Any text at all.',
      language: Language.english,
    );

    expect(result, isEmpty);
  });

  test('returns full records including meaning, needed for translation highlighting',
      () async {
    final repo = _FakeVocabRepository([_record('cat', meaning: 'con mèo')]);
    final useCase = FindKnownHeadwordsUseCase(repo);

    final result = await useCase.execute(
      text: 'The cat is asleep.',
      language: Language.english,
    );

    expect(result, hasLength(1));
    expect(result[0].meaning, 'con mèo');
  });
}
