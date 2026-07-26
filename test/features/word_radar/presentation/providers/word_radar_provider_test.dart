import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
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
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';
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
  int getAllCallCount = 0;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async {
    getAllCallCount++;
    return records;
  }

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

class _ThrowingGenerativeModelClient implements GenerativeModelClient {
  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    throw Exception('network error');
  }
}

/// A [GenerativeModelClient] whose response is controlled by an external
/// [Completer], so a test can observe notifier state while the AI call is
/// still in flight.
class _DelayedGenerativeModelClient implements GenerativeModelClient {
  _DelayedGenerativeModelClient(this._completer);
  final Completer<String> _completer;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    final text = await _completer.future;
    return GenerateContentResponse(
      [Candidate(Content.text(text), null, null, null, null)],
      null,
    );
  }
}

Future<ProviderContainer> _makeContainer({
  required bool aiEnabled,
  required List<VocabRecord> vocabItems,
  _FakeVocabRepository? vocabRepository,
  WordRadarSource? wordRadarSource,
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
      vocabRepositoryProvider.overrideWithValue(
        vocabRepository ?? _FakeVocabRepository(vocabItems),
      ),
      if (wordRadarSource != null)
        wordRadarSourceProvider.overrideWithValue(wordRadarSource),
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

  test('knownHeadwords is observable while suggestions is still loading', () async {
    final completer = Completer<String>();
    final container = await _makeContainer(
      aiEnabled: true,
      vocabItems: [_record('serendipity')],
      wordRadarSource: WordRadarSource.withModel(_DelayedGenerativeModelClient(completer)),
    );
    addTearDown(container.dispose);
    // wordRadarNotifierProvider is AutoDispose; without an active listener it
    // would be torn down (resetting state) once the real Duration.zero delay
    // below yields to the event loop. Keep it alive for the duration of the
    // test, matching how a widget's ref.watch would keep it alive in the app.
    container.listen(wordRadarNotifierProvider, (_, __) {});

    final scanFuture = container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');

    // Let the local (non-AI) pass finish its microtasks without resolving
    // the still-pending AI call.
    await Future<void>.delayed(Duration.zero);
    final midState = container.read(wordRadarNotifierProvider);
    expect(midState.knownHeadwords, ['serendipity']);
    expect(midState.suggestions, isNotNull);
    expect(midState.suggestions!.isLoading, isTrue);

    completer.complete('{"suggestions":[]}');
    await scanFuture;

    final finalState = container.read(wordRadarNotifierProvider);
    expect(finalState.suggestions!.hasValue, isTrue);
    expect(finalState.suggestions!.value, isEmpty);
  });

  test('AI-enabled success path resolves suggestions to AsyncData', () async {
    final json = '{"suggestions":[{"headword":"ubiquitous","ipa":"/juːˈbɪkwɪtəs/",'
        '"meaning":"có mặt khắp nơi","definition":"present everywhere",'
        '"synonyms":["omnipresent"],"examples":["Smartphones are ubiquitous."],'
        '"suggestedTopics":["Technology"],"cefrLevel":"c1"}]}';
    final container = await _makeContainer(
      aiEnabled: true,
      vocabItems: [_record('serendipity')],
      wordRadarSource: WordRadarSource.withModel(_DelayedGenerativeModelClient(Completer<String>()..complete(json))),
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.suggestions!.hasValue, isTrue);
    expect(state.suggestions!.value, hasLength(1));
    expect(state.suggestions!.value!.first.headword, 'ubiquitous');
  });

  test('wraps a thrown AI exception into AsyncError instead of throwing', () async {
    final container = await _makeContainer(
      aiEnabled: true,
      vocabItems: [_record('serendipity')],
      wordRadarSource: WordRadarSource.withModel(_ThrowingGenerativeModelClient()),
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, ['serendipity']);
    expect(state.suggestions!.hasError, isTrue);
  });

  test('retrySuggestions is a no-op before any scan has run', () async {
    final container = await _makeContainer(
      aiEnabled: true,
      vocabItems: const [],
      wordRadarSource: WordRadarSource.withModel(_ThrowingGenerativeModelClient()),
    );
    addTearDown(container.dispose);

    await container.read(wordRadarNotifierProvider.notifier).retrySuggestions('text');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.knownHeadwords, isNull);
    expect(state.suggestions, isNull);
  });

  test('retrySuggestions is a no-op when AI is disabled', () async {
    final container = await _makeContainer(
      aiEnabled: false,
      vocabItems: [_record('serendipity')],
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');
    await container
        .read(wordRadarNotifierProvider.notifier)
        .retrySuggestions('It was pure serendipity.');

    final state = container.read(wordRadarNotifierProvider);
    expect(state.suggestions, isNull);
  });

  test('retrySuggestions re-fetches suggestions without re-running the local pass', () async {
    final repo = _FakeVocabRepository([_record('serendipity')]);
    final container = await _makeContainer(
      aiEnabled: true,
      vocabItems: const [],
      vocabRepository: repo,
      wordRadarSource: WordRadarSource.withModel(_ThrowingGenerativeModelClient()),
    );
    addTearDown(container.dispose);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .scan('It was pure serendipity.');
    expect(repo.getAllCallCount, 1);
    expect(container.read(wordRadarNotifierProvider).suggestions!.hasError, isTrue);

    await container
        .read(wordRadarNotifierProvider.notifier)
        .retrySuggestions('It was pure serendipity.');

    expect(repo.getAllCallCount, 1); // local pass not re-run
    expect(container.read(wordRadarNotifierProvider).suggestions!.hasError, isTrue);
  });
}
