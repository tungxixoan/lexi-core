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

  test('save() writes to users/u1/vocab_records/{id}', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    final doc =
        await firestore.collection('users/u1/vocab_records').doc('v1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['headword'], 'apple');
  });

  test('getAll() returns all records for this user, newest first', () async {
    await repo.save(_record(id: 'v1', createdAt: DateTime(2026, 1, 1)));
    await repo.save(_record(id: 'v2', createdAt: DateTime(2026, 1, 5)));
    final all = await repo.getAll();
    expect(all.map((r) => r.id).toList(), ['v2', 'v1']);
  });

  test('getAll() filters by language when given', () async {
    await repo.save(_record(id: 'v1', language: Language.english));
    await repo.save(_record(id: 'v2', language: Language.chinese));
    final all = await repo.getAll(language: Language.chinese);
    expect(all.map((r) => r.id).toList(), ['v2']);
  });

  test('getAll() filters by topicId when given', () async {
    await repo.save(_record(id: 'v1', topicIds: ['travel']));
    await repo.save(_record(id: 'v2', topicIds: ['business']));
    final all = await repo.getAll(topicId: 'travel');
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getAll() filters by maxCefrLevel when given', () async {
    await repo.save(_record(id: 'v1', cefr: CEFRLevel.a1));
    await repo.save(_record(id: 'v2', cefr: CEFRLevel.c2));
    final all = await repo.getAll(maxCefrLevel: CEFRLevel.b1);
    expect(all.map((r) => r.id).toList(), ['v1']);
  });

  test('getById() returns the matching record or null', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    expect((await repo.getById('v1'))?.headword, 'apple');
    expect(await repo.getById('missing'), isNull);
  });

  test('update() overwrites the stored record', () async {
    await repo.save(_record(id: 'v1', headword: 'apple'));
    final updated = _record(id: 'v1', headword: 'banana');
    await repo.update(updated);
    expect((await repo.getById('v1'))?.headword, 'banana');
  });

  test('delete() removes the record', () async {
    await repo.save(_record(id: 'v1'));
    await repo.delete('v1');
    expect(await repo.getById('v1'), isNull);
  });

  test('existsByHeadword() is case-insensitive and language-scoped', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect(await repo.existsByHeadword('apple', Language.english), isTrue);
    expect(await repo.existsByHeadword('apple', Language.chinese), isFalse);
  });

  test('getByHeadword() returns the matching record case-insensitively', () async {
    await repo.save(_record(id: 'v1', headword: 'Apple', language: Language.english));
    expect((await repo.getByHeadword('apple', Language.english))?.id, 'v1');
    expect(await repo.getByHeadword('nope', Language.english), isNull);
  });

  test('getTopics() seeds the 20 predefined topics into Firestore on first call when empty', () async {
    final topics = await repo.getTopics();
    expect(topics.length, 20);
    final stored = await firestore.collection('users/u1/topics').get();
    expect(stored.docs.length, 20);
  });

  test('getTopics() predefined-first then alphabetical, and does not reseed twice', () async {
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

  test('deleteTopic() reassigns affected words to "other" and removes the topic', () async {
    await repo.getTopics();
    await repo.addTopic(Topic(
      id: 'custom1',
      name: 'Custom',
      emoji: '🎯',
      isPredefined: false,
      createdAt: DateTime(2026, 2, 1),
    ));
    await repo.save(_record(id: 'v1', topicIds: ['custom1']));
    await repo.deleteTopic('custom1');
    final record = await repo.getById('v1');
    expect(record!.topicIds, ['other']);
    final topics = await repo.getTopics();
    expect(topics.any((t) => t.id == 'custom1'), isFalse);
  });
}
