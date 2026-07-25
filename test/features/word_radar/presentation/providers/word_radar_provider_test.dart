import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/word_radar/presentation/providers/word_radar_provider.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

VocabRecord _record(String headword) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: headword,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning of $headword',
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
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
      records;

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

Future<ProviderContainer> _makeContainer({
  required bool aiEnabled,
  required List<VocabRecord> vocabItems,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled),
        ),
      ),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
    ],
  );
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('populates knownHeadwords and leaves suggestions null when AI is disabled', () async {
    final container = await _makeContainer(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, ['serendipity']);
    expect(state.suggestions, isNull);
  });

  test('leaves knownHeadwords empty when nothing in the Vocab Bank matches', () async {
    final container = await _makeContainer(aiEnabled: false, vocabItems: const []);
    addTearDown(container.dispose);

    await container.read(wordRadarNotifierProvider.notifier).scan('Some text.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, isEmpty);
  });

  test('reset() clears back to the initial state', () async {
    final container = await _makeContainer(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');
    container.read(wordRadarNotifierProvider.notifier).reset();

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, isNull);
    expect(state.suggestions, isNull);
  });
}
