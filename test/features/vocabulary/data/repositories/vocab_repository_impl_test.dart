// test/features/vocabulary/data/repositories/vocab_repository_impl_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/data/repositories/vocab_repository_impl.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

VocabRecord _record({
  required String id,
  String headword = 'test',
  Language language = Language.english,
  CEFRLevel cefr = CEFRLevel.b1,
  List<String> topicIds = const [],
  DateTime? createdAt,
}) =>
    VocabRecord(
      id: id,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: topicIds,
      targetLanguage: language,
      cefrLevel: cefr,
      activeContext: AppContext.general,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: createdAt ?? DateTime(2026, 1, 1),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late VocabRepositoryImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = VocabRepositoryImpl(uid: 'u1', firestore: firestore);
  });

  test(
      'save() writes to users/u1/vocab_records_english/{id} for an English record',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'apple', language: Language.english));
    final doc = await firestore
        .collection('users/u1/vocab_records_english')
        .doc('v1')
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['headword'], 'apple');
  });

  test(
      'save() writes a Chinese record to a different collection than an English one',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'apple', language: Language.english));
    await repo
        .save(_record(id: 'v2', headword: '苹果', language: Language.chinese));
    final englishDocs =
        await firestore.collection('users/u1/vocab_records_english').get();
    final chineseDocs =
        await firestore.collection('users/u1/vocab_records_chinese').get();
    expect(englishDocs.docs.map((d) => d.id), ['v1']);
    expect(chineseDocs.docs.map((d) => d.id), ['v2']);
  });

  test(
      'getAll(language:) returns only that language\'s collection, newest first',
      () async {
    await repo.save(_record(
        id: 'v1', language: Language.english, createdAt: DateTime(2026, 1, 1)));
    await repo.save(_record(
        id: 'v2', language: Language.english, createdAt: DateTime(2026, 1, 5)));
    await repo.save(_record(
        id: 'v3',
        language: Language.chinese,
        createdAt: DateTime(2026, 1, 10)));
    final all = await repo.getAll(language: Language.english);
    expect(all.map((r) => r.id).toList(), ['v2', 'v1']);
  });

  test('getAll(language:) filters by topicId within that language', () async {
    await repo.save(
        _record(id: 'v1', language: Language.english, topicIds: ['travel']));
    await repo.save(
        _record(id: 'v2', language: Language.english, topicIds: ['business']));
    final all =
        await repo.getAll(language: Language.english, topicId: 'travel');
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getAll(language:) filters by maxCefrLevel within that language',
      () async {
    await repo.save(
        _record(id: 'v1', language: Language.english, cefr: CEFRLevel.a1));
    await repo.save(
        _record(id: 'v2', language: Language.english, cefr: CEFRLevel.c2));
    final all = await repo.getAll(
        language: Language.english, maxCefrLevel: CEFRLevel.b1);
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test(
      'getById() with language: finds the record in that language\'s collection',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'apple', language: Language.english));
    expect((await repo.getById('v1', language: Language.english))?.headword,
        'apple');
    expect(await repo.getById('missing', language: Language.english), isNull);
  });

  test(
      'getById() with the wrong language does not find a record that exists in a different one',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'apple', language: Language.english));
    expect(await repo.getById('v1', language: Language.chinese), isNull);
  });

  test(
      'update() overwrites the stored record using the record\'s own targetLanguage',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'apple', language: Language.english));
    final updated =
        _record(id: 'v1', headword: 'banana', language: Language.english);
    await repo.update(updated);
    expect((await repo.getById('v1', language: Language.english))?.headword,
        'banana');
  });

  test(
      'delete() with language: removes the record from that language\'s collection',
      () async {
    await repo.save(_record(id: 'v1', language: Language.english));
    await repo.delete('v1', language: Language.english);
    expect(await repo.getById('v1', language: Language.english), isNull);
  });

  test('existsByHeadword() is case-insensitive and language-scoped', () async {
    await repo
        .save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect(await repo.existsByHeadword('apple', Language.english), isTrue);
    expect(await repo.existsByHeadword('apple', Language.chinese), isFalse);
  });

  test('getByHeadword() returns the matching record case-insensitively',
      () async {
    await repo
        .save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect((await repo.getByHeadword('apple', Language.english))?.id, 'v1');
    expect(await repo.getByHeadword('nope', Language.english), isNull);
  });

  test(
      'getTopics() seeds the 20 predefined topics into Firestore on first call when empty',
      () async {
    final topics = await repo.getTopics();
    expect(topics.length, 20);
    final stored = await firestore.collection('users/u1/topics').get();
    expect(stored.docs.length, 20);
  });

  test(
      'getTopics() predefined-first then alphabetical, and does not reseed twice',
      () async {
    final first = await repo.getTopics();
    expect(first.length, 20);
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Aardvarks',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    final second = await repo.getTopics();
    expect(second.length, 21);
    expect(second.first.isPredefined, isTrue);
    expect(second.last.name, 'Aardvarks');
  });

  test(
      'deleteTopic() reassigns affected words to "other" across EVERY language collection, not just one',
      () async {
    await repo.getTopics();
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Custom',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    await repo.save(
        _record(id: 'v1', language: Language.english, topicIds: ['custom1']));
    await repo.save(
        _record(id: 'v2', language: Language.chinese, topicIds: ['custom1']));
    await repo.deleteTopic('custom1');
    final englishRecord = await repo.getById('v1', language: Language.english);
    final chineseRecord = await repo.getById('v2', language: Language.chinese);
    expect(englishRecord!.topicIds, ['other']);
    expect(chineseRecord!.topicIds, ['other']);
    final topics = await repo.getTopics();
    expect(topics.any((t) => t.id == 'custom1'), isFalse);
  });
}
