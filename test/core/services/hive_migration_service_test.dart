import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lexi_core/core/services/hive_migration_service.dart';

void main() {
  late Directory tempDir;
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_migration_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>('vocab_migration_${DateTime.now().millisecondsSinceEpoch}');
    topicsBox = await Hive.openBox<String>('topics_migration_${DateTime.now().millisecondsSinceEpoch}');
    firestore = FakeFirebaseFirestore();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('pushes existing Hive vocab and topics into Firestore when Hive has data', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    await topicsBox.put('t1', jsonEncode({'id': 't1', 'name': 'Travel'}));

    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabDoc = await firestore.collection('users/u1/vocab_records').doc('v1').get();
    expect(vocabDoc.data()!['headword'], 'apple');
    final topicDoc = await firestore.collection('users/u1/topics').doc('t1').get();
    expect(topicDoc.data()!['name'], 'Travel');
  });

  test('does nothing and returns false when both Hive boxes are empty', () async {
    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);
    final vocabSnapshot = await firestore.collection('users/u1/vocab_records').get();
    expect(vocabSnapshot.docs, isEmpty);
  });

  test('migrates even if only one of the two boxes has data', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    final service = HiveMigrationService(
      vocabBox: vocabBox,
      topicsBox: topicsBox,
      firestore: firestore,
    );
    final migrated = await service.migrateIfNeeded('u1');
    expect(migrated, isTrue);
  });
}
