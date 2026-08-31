import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/presentation/widgets/vocab_suggestions_section.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async => null;

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id, {required Language language}) async {}

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

const _suggestion = WordPhraseResult(
  headword: 'ubiquitous',
  inputType: InputType.word,
  ipa: '/juːˈbɪkwɪtəs/',
  meaning: 'có mặt khắp nơi',
  examples: [],
  suggestedTopics: [],
);

Future<Widget> _buildSection(List<WordPhraseResult> suggestions) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(const [])),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: VocabSuggestionsSection(suggestions: suggestions),
      ),
    ),
  );
}

void main() {
  testWidgets('shows "Không có gợi ý mới." when there are no suggestions', (tester) async {
    await tester.pumpWidget(await _buildSection(const []));
    await tester.pumpAndSettle();
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('tapping a suggestion card opens the save sheet', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    await tester.tap(find.text('ubiquitous'));
    await tester.pumpAndSettle();

    expect(find.text('Lưu "ubiquitous"'), findsOneWidget);
  });

  testWidgets('tapping the dismiss icon removes a suggestion from the list', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsNothing);
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });

  testWidgets('Lưu tất cả saves every suggestion and shows a checkmark', (tester) async {
    await tester.pumpWidget(await _buildSection(const [_suggestion]));
    await tester.pumpAndSettle();

    expect(find.text('Lưu tất cả'), findsOneWidget);
    await tester.tap(find.text('Lưu tất cả'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Lưu tất cả'), findsNothing);
  });
}
