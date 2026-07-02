import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lexi_core/core/services/sync_service.dart';

void main() {
  late Box<String> vocabBox;
  late Box<String> topicsBox;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_test');
    Hive.init(tempDir.path);
    vocabBox = await Hive.openBox<String>('vocab_test_${DateTime.now().millisecondsSinceEpoch}');
    topicsBox = await Hive.openBox<String>('topics_test_${DateTime.now().millisecondsSinceEpoch}');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('SyncService can be created without error', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(service, isNotNull);
  });

  test('stopSync() is safe to call before startSync()', () {
    final service = SyncService(vocabBox: vocabBox, topicsBox: topicsBox);
    expect(() => service.stopSync(), returnsNormally);
  });
}
