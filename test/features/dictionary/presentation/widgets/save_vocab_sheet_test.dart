import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/save_vocab_sheet.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';

class _RecordingVocabRepository implements VocabRepository {
  VocabRecord? saved;

  @override
  Future<void> save(VocabRecord record) async {
    saved = record;
  }

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      [];

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async =>
      null;

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id, {required Language language}) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(
          String headword, Language language) async =>
      null;

  @override
  Future<List<Topic>> getTopics() async => [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

Future<Widget> _buildSheet(
    WordPhraseResult result, _RecordingVocabRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      vocabRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (_) => SaveVocabSheet(result: result),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('saves the AI-returned cefrLevel when present', (tester) async {
    final repo = _RecordingVocabRepository();
    const result = WordPhraseResult(
      headword: 'ubiquitous',
      inputType: InputType.word,
      ipa: '/juːˈbɪkwɪtəs/',
      meaning: 'có mặt khắp nơi',
      examples: [],
      suggestedTopics: [],
      cefrLevel: CEFRLevel.c1,
    );
    await tester.pumpWidget(await _buildSheet(result, repo));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(BloomPillButton, 'Lưu vào Ngân hàng từ'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.cefrLevel, CEFRLevel.c1);
  });

  testWidgets('defaults to B1 when the result has no cefrLevel',
      (tester) async {
    final repo = _RecordingVocabRepository();
    const result = WordPhraseResult(
      headword: 'cat',
      inputType: InputType.word,
      ipa: '/kæt/',
      meaning: 'con mèo',
      examples: [],
      suggestedTopics: [],
    );
    await tester.pumpWidget(await _buildSheet(result, repo));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.widgetWithText(BloomPillButton, 'Lưu vào Ngân hàng từ'));
    await tester.pumpAndSettle();

    expect(repo.saved, isNotNull);
    expect(repo.saved!.cefrLevel, CEFRLevel.b1);
  });
}
