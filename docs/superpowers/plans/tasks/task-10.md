# Task 10: Riverpod Providers

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 4, 6, 7, 8, 9

## Global Constraints
- Riverpod 2.x with `@riverpod` annotation only — no StateNotifier, no ChangeNotifier
- Must run `dart run build_runner build --delete-conflicting-outputs` after writing providers

## Interfaces From Prior Tasks
- `LookupUseCase.execute({query, targetLanguage, context, aiEnabled}) → Future<LookupResult>`
- `GeminiDictionarySource.discoverWord({targetLanguage, context}) → Future<String>`
- `TtsService` abstract class with `speak(String, Language)` and `stop()`
- `FlutterTtsService implements TtsService`
- `FreeDictionarySource(http.Client)`
- `DictionaryRepositoryImpl({geminiSource, freeDictionarySource})`
- `UserSettingsState.defaults` — initial state constant
- `UserSettingsState.copyWith(...)` — returns new instance

## What This Task Delivers
Three provider files + one DI wiring file. After build_runner runs, generates `.g.dart` files.

## Files
- Create: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Create: `lib/features/dictionary/presentation/providers/lookup_provider.dart`
- Create: `lib/core/di/app_providers.dart`
- Create: `test/features/dictionary/presentation/providers/lookup_provider_test.dart`

## Produces (used by Tasks 11–15)

**Providers accessible via Riverpod:**
- `userSettingsNotifierProvider` → `UserSettingsState`
- `UserSettingsNotifier` methods: `setTargetLanguage(Language)`, `setActiveContext(AppContext)`, `setAiEnabled({required bool})`, `setGeminiApiKey(String)`
- `lookupNotifierProvider` → `AsyncValue<LookupResult?>`
- `LookupNotifier` methods: `lookup(String)`, `discover()`, `clear()`
- `ttsServiceProvider` → `TtsService`
- `lookupUseCaseProvider` → `LookupUseCase`
- `geminiDictionarySourceProvider` → `GeminiDictionarySource`

## Steps

- [ ] **Step 1: Create user_settings_provider.dart**

```dart
// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';

part 'user_settings_provider.g.dart';

@riverpod
class UserSettingsNotifier extends _$UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;

  void setTargetLanguage(Language lang) =>
      state = state.copyWith(targetLanguage: lang);

  void setActiveContext(AppContext context) =>
      state = state.copyWith(activeContext: context);

  void setAiEnabled({required bool enabled}) =>
      state = state.copyWith(aiEnabled: enabled);

  void setGeminiApiKey(String key) =>
      state = state.copyWith(geminiApiKey: key);
}
```

- [ ] **Step 2: Create app_providers.dart**

```dart
// lib/core/di/app_providers.dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../features/dictionary/data/repositories/dictionary_repository_impl.dart';
import '../../features/dictionary/data/sources/free_dictionary_source.dart';
import '../../features/dictionary/data/sources/gemini_dictionary_source.dart';
import '../../features/dictionary/domain/repositories/dictionary_repository.dart';
import '../../features/dictionary/domain/use_cases/lookup_use_case.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../services/tts_service.dart';

part 'app_providers.g.dart';

@riverpod
http.Client httpClient(HttpClientRef ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
}

@riverpod
FlutterTts flutterTts(FlutterTtsRef ref) => FlutterTts();

@riverpod
TtsService ttsService(TtsServiceRef ref) =>
    FlutterTtsService(ref.watch(flutterTtsProvider));

@riverpod
FreeDictionarySource freeDictionarySource(FreeDictionarySourceRef ref) =>
    FreeDictionarySource(ref.watch(httpClientProvider));

@riverpod
GeminiDictionarySource geminiDictionarySource(
    GeminiDictionarySourceRef ref) {
  final apiKey = ref.watch(
    userSettingsNotifierProvider.select((s) => s.geminiApiKey),
  );
  return GeminiDictionarySource(apiKey: apiKey);
}

@riverpod
DictionaryRepository dictionaryRepository(DictionaryRepositoryRef ref) =>
    DictionaryRepositoryImpl(
      geminiSource: ref.watch(geminiDictionarySourceProvider),
      freeDictionarySource: ref.watch(freeDictionarySourceProvider),
    );

@riverpod
LookupUseCase lookupUseCase(LookupUseCaseRef ref) =>
    LookupUseCase(ref.watch(dictionaryRepositoryProvider));
```

- [ ] **Step 3: Create lookup_provider.dart**

```dart
// lib/features/dictionary/presentation/providers/lookup_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/lookup_result.dart';
import 'user_settings_provider.dart';

part 'lookup_provider.g.dart';

@riverpod
class LookupNotifier extends _$LookupNotifier {
  @override
  AsyncValue<LookupResult?> build() => const AsyncValue.data(null);

  Future<void> lookup(String query) async {
    state = const AsyncValue.loading();
    final settings = ref.read(userSettingsNotifierProvider);
    final useCase = ref.read(lookupUseCaseProvider);

    state = await AsyncValue.guard(() => useCase.execute(
          query: query,
          targetLanguage: settings.targetLanguage,
          context: settings.activeContext,
          aiEnabled: settings.aiEnabled,
        ));
  }

  Future<void> discover() async {
    final settings = ref.read(userSettingsNotifierProvider);
    if (!settings.aiEnabled) return;

    state = const AsyncValue.loading();
    final gemini = ref.read(geminiDictionarySourceProvider);

    state = await AsyncValue.guard(() async {
      final word = await gemini.discoverWord(
        targetLanguage: settings.targetLanguage,
        context: settings.activeContext,
      );
      final useCase = ref.read(lookupUseCaseProvider);
      return useCase.execute(
        query: word,
        targetLanguage: settings.targetLanguage,
        context: settings.activeContext,
        aiEnabled: true,
      );
    });
  }

  void clear() => state = const AsyncValue.data(null);
}
```

- [ ] **Step 4: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `user_settings_provider.g.dart`, `app_providers.g.dart`, `lookup_provider.g.dart` — no errors.

- [ ] **Step 5: Write and run provider tests**

```dart
// test/features/dictionary/presentation/providers/lookup_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/use_cases/lookup_use_case.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/lookup_provider.dart';

import 'lookup_provider_test.mocks.dart';

@GenerateMocks([LookupUseCase])
void main() {
  late MockLookupUseCase mockUseCase;

  const fakeResult = WordPhraseResult(
    headword: 'follow',
    inputType: InputType.word,
    ipa: '/ˈfɒl.oʊ/',
    meaning: 'Đi theo.',
    examples: ['She followed him.'],
    suggestedTopics: ['Daily Life'],
  );

  setUp(() {
    mockUseCase = MockLookupUseCase();
    when(mockUseCase.execute(
      query: anyNamed('query'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
      aiEnabled: anyNamed('aiEnabled'),
    )).thenAnswer((_) async => fakeResult);
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [lookupUseCaseProvider.overrideWithValue(mockUseCase)],
      );

  test('initial state is AsyncData(null)', () {
    final c = makeContainer();
    addTearDown(c.dispose);
    expect(
      c.read(lookupNotifierProvider),
      const AsyncValue<LookupResult?>.data(null),
    );
  });

  test('lookup → loading → data', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(lookupNotifierProvider.notifier);
    final future = notifier.lookup('follow');

    expect(c.read(lookupNotifierProvider), const AsyncValue<LookupResult?>.loading());
    await future;

    final state = c.read(lookupNotifierProvider);
    expect(state, isA<AsyncData<LookupResult?>>());
    expect((state.value as WordPhraseResult).headword, 'follow');
  });

  test('clear → AsyncData(null)', () async {
    final c = makeContainer();
    addTearDown(c.dispose);
    final notifier = c.read(lookupNotifierProvider.notifier);
    await notifier.lookup('follow');
    notifier.clear();
    expect(
      c.read(lookupNotifierProvider),
      const AsyncValue<LookupResult?>.data(null),
    );
  });
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/dictionary/presentation/providers/lookup_provider_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/di/ \
        lib/features/dictionary/presentation/providers/ \
        test/features/dictionary/presentation/providers/
git commit -m "feat: add Riverpod providers — UserSettingsNotifier, LookupNotifier, DI wiring"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/features/dictionary/presentation/providers/lookup_provider_test.dart`
Concerns: (if any)
