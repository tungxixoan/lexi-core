import 'dart:convert';
import 'dart:io';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lexi_core/core/services/hive_migration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    await topicsBox.put('t1', jsonEncode({'id': 't1', 'name': 'Travel'}));

    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isTrue);
    final vocabDoc = await firestore.collection('users/u1/vocab_records').doc('v1').get();
    expect(vocabDoc.data()!['headword'], 'apple');
    final topicDoc = await firestore.collection('users/u1/topics').doc('t1').get();
    expect(topicDoc.data()!['name'], 'Travel');
    expect(vocabBox.isEmpty, isTrue);
    expect(topicsBox.isEmpty, isTrue);
  });

  test('does nothing and returns false when both Hive boxes are empty', () async {
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');

    expect(migrated, isFalse);
    final vocabSnapshot = await firestore.collection('users/u1/vocab_records').get();
    expect(vocabSnapshot.docs, isEmpty);
  });

  test('migrates even if only one of the two boxes has data', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);
    final migrated = await service.migrateIfNeeded('u1');
    expect(migrated, isTrue);
  });

  test('calling migrateIfNeeded twice for the same uid only pushes to Firestore once', () async {
    await vocabBox.put('v1', jsonEncode({'id': 'v1', 'headword': 'apple'}));
    final service = HiveMigrationService(firestore: firestore, prefs: prefs);

    final firstMigrated = await service.migrateIfNeeded('u1');
    expect(firstMigrated, isTrue);

    // Simulate Hive somehow still having data on the second call (e.g. a
    // stale box reopened) — the already-migrated flag should still gate it.
    await vocabBox.put('v2', jsonEncode({'id': 'v2', 'headword': 'banana'}));

    final secondMigrated = await service.migrateIfNeeded('u1');
    expect(secondMigrated, isFalse);
    final vocabSnapshot = await firestore.collection('users/u1/vocab_records').get();
    expect(vocabSnapshot.docs.map((d) => d.id), ['v1']);
  });
}
