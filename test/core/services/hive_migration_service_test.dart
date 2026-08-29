import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexi_core/core/services/hive_migration_service.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVocabRepository extends Mock implements VocabRepository {}

/// A well-formed VocabRecord JSON map (matching VocabRecord.fromJson's
/// required fields) so migrated Hive entries actually parse — a raw map
/// missing required fields (targetLanguage, inputType, etc.) would be
/// silently skipped as malformed by the migration's per-record try/catch.
Map<String, dynamic> _vocabJson(
  String id, {
  String headword = 'apple',
  String targetLanguage = 'english',
}) =>
    {
      'id': id,
      'headword': headword,
      'inputType': 'word',
      'ipa': '',
      'meaning': 'meaning of $headword',
      'examples': <String>[],
      'personalNotes': '',
      'topicIds': <String>[],
      'targetLanguage': targetLanguage,
      'cefrLevel': 'b1',
      'activeContext': 'general',
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // mocktail's any() needs a registered fallback for non-primitive
    // argument types used in when()/verify() — a well-formed VocabRecord
    // built from the same helper the tests seed Hive with.
    registerFallbackValue(VocabRecord.fromJson(_vocabJson('fallback')));
  });

  late Directory tempDir;
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late FakeFirebaseFirestore firestore;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_migration_test');

    // HiveMigrationService calls Hive.initFlutter() itself, which resolves
    // the app documents directory via path_provider's platform channel —
    // stub it to point at tempDir so that lands in an isolated, cleaned-up
    // location instead of throwing MissingPluginException in the test host.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempDir.path,
    );

    Hive.init(tempDir.path);
    // Same box names HiveMigrationService itself opens, so it finds this
    // seeded data via Hive's already-open-box shortcut.
    vocabBox = await Hive.openBox<String>('vocab_records');
    topicsBox = await Hive.openBox<String>('topics');
    firestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('pushes existing Hive vocab and topics into Firestore when Hive has data', () async {
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));
    await topicsBox.put('t1', jsonEncode({'id': 't1', 'name': 'Travel'}));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabDoc =
        await firestore.collection('users/u1/vocab_records_english').doc('v1').get();
    expect(vocabDoc.data()!['headword'], 'apple');
    final topicDoc = await firestore.collection('users/u1/topics').doc('t1').get();
    expect(topicDoc.data()!['name'], 'Travel');
    expect(vocabBox.isEmpty, isTrue);
    expect(topicsBox.isEmpty, isTrue);
  });

  test('lands a migrated record in the per-language collection matching its targetLanguage,'
      ' not the flat vocab_records collection', () async {
    await vocabBox.put(
      'v1',
      jsonEncode(_vocabJson('v1', headword: 'apple', targetLanguage: 'english')),
    );
    // A second record in a DIFFERENT target language, in the same test, so
    // an implementation that hard-coded "vocab_records_english" (rather
    // than routing by each record's own targetLanguage) would fail this.
    await vocabBox.put(
      'v2',
      jsonEncode(_vocabJson('v2', headword: '苹果', targetLanguage: 'chinese')),
    );

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final perLanguageDoc =
        await firestore.collection('users/u1/vocab_records_english').doc('v1').get();
    expect(perLanguageDoc.exists, isTrue);
    expect(perLanguageDoc.data()!['headword'], 'apple');

    final chineseDoc =
        await firestore.collection('users/u1/vocab_records_chinese').doc('v2').get();
    expect(chineseDoc.exists, isTrue);
    expect(chineseDoc.data()!['headword'], '苹果');

    // Never lands in the old dead flat collection.
    final flatSnapshot = await firestore.collection('users/u1/vocab_records').get();
    expect(flatSnapshot.docs, isEmpty);
  });

  test('does nothing and returns false when both Hive boxes are empty', () async {
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);
    final vocabSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(vocabSnapshot.docs, isEmpty);
  });

  test('migrates even if only one of the two boxes has data', () async {
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1')));
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');
    expect(migrated, isTrue);
  });

  test('calling migrateIfNeeded twice for the same uid only pushes to Firestore once', () async {
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);

    final firstMigrated = await service.migrateIfNeeded('u1');
    expect(firstMigrated, isTrue);

    // Simulate Hive somehow still having data on the second call (e.g. a
    // stale box reopened) — the already-migrated flag should still gate it.
    await vocabBox.put('v2', jsonEncode(_vocabJson('v2', headword: 'banana')));

    final secondMigrated = await service.migrateIfNeeded('u1');
    expect(secondMigrated, isFalse);
    final vocabSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(vocabSnapshot.docs.map((d) => d.id), ['v1']);
  });

  test('skips migration without touching Hive when Firestore already has vocab data for this uid', () async {
    // Pre-existing Firestore data for u1 — as if they'd signed in before
    // under the old SyncService and this Hive box is now just a stale
    // local mirror, not their only copy.
    await firestore
        .collection('users/u1/vocab_records_english')
        .doc('existing')
        .set(_vocabJson('existing', headword: 'orange'));

    // Different data sitting in Hive that must NOT get pushed.
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);

    // The pre-existing Firestore doc is untouched, and the stale Hive doc
    // was never pushed.
    final vocabSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(vocabSnapshot.docs.map((d) => d.id), ['existing']);
    final existingDoc =
        await firestore.collection('users/u1/vocab_records_english').doc('existing').get();
    expect(existingDoc.data()!['headword'], 'orange');

    // Hive is left as-is (not cleared) in this path.
    expect(vocabBox.containsKey('v1'), isTrue);
    expect(vocabBox.get('v1'), jsonEncode(_vocabJson('v1', headword: 'apple')));
  });

  test('skips migration without touching Hive when Firestore already has vocab data'
      ' for this uid in a NON-English per-language collection', () async {
    // Existing data lives only in vocab_records_chinese (never touching
    // vocab_records_english at all) — proves the "does this uid already
    // have vocab data" guard genuinely loops over every per-language
    // collection rather than only ever checking English.
    await firestore
        .collection('users/u1/vocab_records_chinese')
        .doc('existing')
        .set(_vocabJson('existing', headword: '橙子', targetLanguage: 'chinese'));

    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);

    final chineseSnapshot =
        await firestore.collection('users/u1/vocab_records_chinese').get();
    expect(chineseSnapshot.docs.map((d) => d.id), ['existing']);

    // Never pushed the stale Hive record anywhere, and English stays empty.
    final englishSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(englishSnapshot.docs, isEmpty);
    expect(vocabBox.containsKey('v1'), isTrue);
  });

  test('skips one malformed Hive record but still migrates the valid ones', () async {
    await vocabBox.put('bad', 'not valid json{');
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabDoc =
        await firestore.collection('users/u1/vocab_records_english').doc('v1').get();
    expect(vocabDoc.data()!['headword'], 'apple');
    final vocabSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(vocabSnapshot.docs.length, 1);
  });

  test('skips a Hive record whose JSON is well-formed but fails to parse into a VocabRecord',
      () async {
    // Valid JSON, but missing required VocabRecord fields (e.g. targetLanguage,
    // inputType) — VocabRecord.fromJson throws on this, and it must be
    // skipped the same way a jsonDecode failure is.
    await vocabBox.put('bad', jsonEncode({'id': 'bad', 'headword': 'incomplete'}));
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabSnapshot =
        await firestore.collection('users/u1/vocab_records_english').get();
    expect(vocabSnapshot.docs.map((d) => d.id), ['v1']);
  });

  test('propagates a Firestore save() failure instead of silently skipping it,'
      ' and does NOT clear Hive or set the migrated flag', () async {
    await vocabBox.put('v1', jsonEncode(_vocabJson('v1', headword: 'apple')));
    await topicsBox.put('t1', jsonEncode({'id': 't1', 'name': 'Travel'}));

    final mockRepo = MockVocabRepository();
    when(() => mockRepo.save(any()))
        .thenThrow(Exception('permission-denied: simulated Firestore write failure'));

    final service = HiveMigrationService(
      firestore: firestore,
      prefs: prefs,
      vocabRepositoryBuilder: (_) => mockRepo,
    );

    // (a) migrateIfNeeded throws rather than returning true.
    await expectLater(service.migrateIfNeeded('u1'), throwsException);

    // (b) the Hive box is NOT cleared afterward.
    expect(vocabBox.containsKey('v1'), isTrue);
    expect(topicsBox.containsKey('t1'), isTrue);

    // (c) the migrated flag is NOT set afterward.
    expect(prefs.getBool('hive_migrated_u1'), isNot(true));
  });
}
