# Plan 10 — Task 04: Provider + DI + Router + Enable Hub Card

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Task 02 (`TtsService.speak(..., {pitch})`); Plan 10 Task 03 (`GenerateListeningPassageUseCase`)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
`ListeningComprehensionNotifier` — a Riverpod `AsyncNotifier`-style class managing the comprehension session lifecycle (generate → per-turn playback/navigation → answer selection → submit). DI wiring in `app_providers.dart`. New `/listening/comprehension` routes in `app_router.dart`, nested under the existing `/listening` route alongside `dictation`. The previously-disabled "Nghe hiểu" card on `ListeningHomeScreen` (built in Plan 9) becomes enabled and navigable. **Stub** screens for `ComprehensionHomeScreen`, `ComprehensionSessionScreen`, `ComprehensionResultScreen` so the router compiles — Tasks 05–07 replace them with real implementations.

## Files
- Create: `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
- Create: `lib/features/listening/presentation/providers/listening_comprehension_provider.g.dart` (generated)
- Create: `lib/features/listening/presentation/screens/comprehension_home_screen.dart` (stub)
- Create: `lib/features/listening/presentation/screens/comprehension_session_screen.dart` (stub)
- Create: `lib/features/listening/presentation/screens/comprehension_result_screen.dart` (stub)
- Create: `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
- Modify: `lib/features/listening/presentation/screens/listening_home_screen.dart`
- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/core/router/app_router.dart`

## Interfaces
- Consumes: `GenerateListeningPassageUseCase` from Task 03; `TtsService` (existing `ttsServiceProvider`, now with `pitch` from Task 02); `ListeningPassage`/`ListeningTurn` from Task 01
- Produces:
  - `ComprehensionSessionResult({required ListeningPassage passage, required List<int?> selectedAnswers})` — with `correctCount` getter
  - `ListeningSessionState({required ListeningPassage passage, required int currentTurnIndex, required bool isSpeaking, required int playToken, required List<int?> selectedAnswers, required bool isSubmitted})` — with `currentTurn`, `canSubmit` getters + `copyWith`
  - `listeningComprehensionNotifierProvider` — session state provider
  - `ListeningComprehensionNotifier.generate({required CEFRLevel level, required AppContext context, required Language targetLanguage})`
  - `ListeningComprehensionNotifier.playCurrentTurn()` — speaks the turn at `currentTurnIndex`; sets `isSpeaking` true while playing, false when it finishes (guarded by a `playToken` so a stale completion from a superseded play doesn't clobber newer state)
  - `ListeningComprehensionNotifier.stopPlayback()` — stops audio, sets `isSpeaking` false
  - `ListeningComprehensionNotifier.previousTurn()` / `.nextTurn()` — move `currentTurnIndex` by ±1 (clamped), stop any in-flight audio, do NOT auto-play the new turn
  - `ListeningComprehensionNotifier.replayFromStart()` — resets `currentTurnIndex` to 0, stops any in-flight audio, does NOT auto-play
  - `ListeningComprehensionNotifier.selectAnswer(int questionIndex, int optionIndex)`
  - `ListeningComprehensionNotifier.submit()` — only takes effect when `canSubmit` is true
  - `ListeningComprehensionNotifier.reset()`

## Steps

- [ ] **Step 1: Write the notifier unit tests**

Create `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_listening_passage_use_case.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockGenerateListeningPassageUseCase extends Mock
    implements GenerateListeningPassageUseCase {}

class MockTtsService extends Mock implements TtsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  final fixedPassage = ListeningPassage(
    id: 'p1',
    kind: ListeningKind.conversation,
    turns: const [
      ListeningTurn(speaker: 'A', text: 'Hello, can I help you?'),
      ListeningTurn(speaker: 'B', text: 'Yes, I need a room for tonight.'),
      ListeningTurn(speaker: 'A', text: 'Sure, for how many guests?'),
    ],
    questions: const [
      ListeningQuestion(question: 'Q1', options: ['a', 'b', 'c', 'd'], correctIndex: 0),
      ListeningQuestion(question: 'Q2', options: ['a', 'b', 'c', 'd'], correctIndex: 1),
      ListeningQuestion(question: 'Q3', options: ['a', 'b', 'c', 'd'], correctIndex: 2),
    ],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGenerateListeningPassageUseCase mockUseCase;
  late MockTtsService mockTts;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGenerateListeningPassageUseCase();
    mockTts = MockTtsService();
    when(
      () => mockUseCase.execute(
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fixedPassage);
    when(
      () => mockTts.speak(any(), any(), pitch: any(named: 'pitch')),
    ).thenAnswer((_) async {});
    when(() => mockTts.stop()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        generateListeningPassageUseCaseProvider.overrideWithValue(mockUseCase),
        ttsServiceProvider.overrideWithValue(mockTts),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container
      .read(listeningComprehensionNotifierProvider.notifier)
      .generate(level: CEFRLevel.b1, context: AppContext.general, targetLanguage: Language.english);

  test('generate() populates state at turn 0 with all answers unselected', () async {
    await generateFixed();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.passage, same(fixedPassage));
    expect(state.currentTurnIndex, 0);
    expect(state.selectedAnswers, [null, null, null]);
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('playCurrentTurn() speaks the current turn with the correct pitch and resets isSpeaking on completion', () async {
    await generateFixed();
    await container.read(listeningComprehensionNotifierProvider.notifier).playCurrentTurn();
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0)).called(1);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.isSpeaking, false); // reset after the awaited speak() completes
  });

  test('nextTurn() advances currentTurnIndex and stops any playing audio', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.stop()).called(greaterThanOrEqualTo(1));
  });

  test('nextTurn() at the last turn does not go out of bounds', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.nextTurn(); // one extra call past the last index (2)
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 2);
  });

  test('previousTurn() at turn 0 does not go negative', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.previousTurn();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('replayFromStart() resets currentTurnIndex to 0', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.replayFromStart();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('selectAnswer() records an answer without marking submitted', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 2);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers, [2, null, null]);
    expect(state.isSubmitted, false);
  });

  test('canSubmit is true only once all 3 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 1);
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 2);
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.isSubmitted, false);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 0);
    notifier.selectAnswer(2, 0);
    notifier.submit();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(listeningComprehensionNotifierProvider.notifier).reset();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull, isNull);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
```

Expected: FAIL — `listening_comprehension_provider.dart` doesn't exist.

- [ ] **Step 3: Create listening_comprehension_provider.dart**

Create `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/listening_passage.dart';

part 'listening_comprehension_provider.g.dart';

final class ComprehensionSessionResult {
  const ComprehensionSessionResult({
    required this.passage,
    required this.selectedAnswers,
  });

  final ListeningPassage passage;
  final List<int?> selectedAnswers; // length == passage.questions.length

  int get correctCount {
    int count = 0;
    for (int i = 0; i < passage.questions.length; i++) {
      if (selectedAnswers[i] == passage.questions[i].correctIndex) count++;
    }
    return count;
  }
}

final class ListeningSessionState {
  const ListeningSessionState({
    required this.passage,
    required this.currentTurnIndex,
    required this.isSpeaking,
    required this.playToken,
    required this.selectedAnswers,
    required this.isSubmitted,
  });

  final ListeningPassage passage;
  final int currentTurnIndex;
  final bool isSpeaking;
  final int playToken;
  final List<int?> selectedAnswers;
  final bool isSubmitted;

  ListeningTurn get currentTurn => passage.turns[currentTurnIndex];
  bool get canSubmit => selectedAnswers.every((a) => a != null);

  ListeningSessionState copyWith({
    int? currentTurnIndex,
    bool? isSpeaking,
    int? playToken,
    List<int?>? selectedAnswers,
    bool? isSubmitted,
  }) =>
      ListeningSessionState(
        passage: passage,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        playToken: playToken ?? this.playToken,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

@riverpod
class ListeningComprehensionNotifier extends _$ListeningComprehensionNotifier {
  @override
  AsyncValue<ListeningSessionState?> build() => const AsyncData(null);

  Future<void> generate({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final passage = await ref
          .read(generateListeningPassageUseCaseProvider)
          .execute(level: level, context: context, targetLanguage: targetLanguage);
      return ListeningSessionState(
        passage: passage,
        currentTurnIndex: 0,
        isSpeaking: false,
        playToken: 0,
        selectedAnswers: List<int?>.filled(passage.questions.length, null),
        isSubmitted: false,
      );
    });
  }

  double _pitchFor(String? speaker) => speaker == 'B' ? 1.3 : 1.0;

  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    await ref.read(ttsServiceProvider).speak(
          turn.text,
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }

  Future<void> stopPlayback() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false, playToken: latest.playToken + 1));
  }

  Future<void> previousTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.currentTurnIndex == 0) return;
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(
      currentTurnIndex: latest.currentTurnIndex - 1,
      isSpeaking: false,
      playToken: latest.playToken + 1,
    ));
  }

  Future<void> nextTurn() async {
    final current = state.valueOrNull;
    if (current == null ||
        current.currentTurnIndex >= current.passage.turns.length - 1) {
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(
      currentTurnIndex: latest.currentTurnIndex + 1,
      isSpeaking: false,
      playToken: latest.playToken + 1,
    ));
  }

  Future<void> replayFromStart() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(
      currentTurnIndex: 0,
      isSpeaking: false,
      playToken: latest.playToken + 1,
    ));
  }

  void selectAnswer(int questionIndex, int optionIndex) {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final updated = List<int?>.from(current.selectedAnswers);
    updated[questionIndex] = optionIndex;
    state = AsyncData(current.copyWith(selectedAnswers: updated));
  }

  void submit() {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted || !current.canSubmit) return;
    state = AsyncData(current.copyWith(isSubmitted: true));
  }

  void reset() => state = const AsyncData(null);
}
```

- [ ] **Step 4: Generate Riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `listening_comprehension_provider.g.dart` created.

- [ ] **Step 5: Run the notifier tests — should pass now**

```bash
flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
```

Expected: all 10 tests pass.

- [ ] **Step 6: Add DI providers to app_providers.dart**

In `lib/core/di/app_providers.dart`, add these imports after the existing `// --- Listening DI (Plan 9) ---` block:

```dart
import '../../features/listening/data/sources/listening_passage_source.dart';
import '../../features/listening/domain/use_cases/generate_listening_passage_use_case.dart';
```

Then add these providers at the end of the file:

```dart
@riverpod
ListeningPassageSource listeningPassageSource(ListeningPassageSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return ListeningPassageSource(settings);
}

@riverpod
GenerateListeningPassageUseCase generateListeningPassageUseCase(
        GenerateListeningPassageUseCaseRef ref) =>
    GenerateListeningPassageUseCase(ref.watch(listeningPassageSourceProvider));
```

After editing, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 7: Create stub screens so the router compiles**

Create `lib/features/listening/presentation/screens/comprehension_home_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ComprehensionHomeScreen extends StatelessWidget {
  const ComprehensionHomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Nghe hiểu — coming soon')));
}
```

Create `lib/features/listening/presentation/screens/comprehension_session_screen.dart`:

```dart
import 'package:flutter/material.dart';

class ComprehensionSessionScreen extends StatelessWidget {
  const ComprehensionSessionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Session — coming soon')));
}
```

Create `lib/features/listening/presentation/screens/comprehension_result_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionResultScreen extends StatelessWidget {
  const ComprehensionResultScreen({super.key, required this.result});
  final ComprehensionSessionResult result;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Result — coming soon')));
}
```

- [ ] **Step 8: Add /listening/comprehension routes to app_router.dart**

In `lib/core/router/app_router.dart`, add these imports after the existing listening imports:

```dart
import '../../features/listening/presentation/screens/comprehension_home_screen.dart';
import '../../features/listening/presentation/screens/comprehension_session_screen.dart';
import '../../features/listening/presentation/screens/comprehension_result_screen.dart';
import '../../features/listening/presentation/providers/listening_comprehension_provider.dart';
```

Then, inside the existing `/listening` route's nested `routes: [...]` list (which currently contains only the `dictation` route from Plan 9), add a sibling `comprehension` route:

```dart
            GoRoute(
              path: 'comprehension',
              builder: (context, state) => const ComprehensionHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const ComprehensionSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! ComprehensionSessionResult) {
                          return '/listening/comprehension';
                        }
                        return null;
                      },
                      builder: (context, state) => ComprehensionResultScreen(
                        result: state.extra as ComprehensionSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
```

The full nested route list under `/listening` should now contain both `dictation` and `comprehension` as siblings.

- [ ] **Step 9: Enable the "Nghe hiểu" card on ListeningHomeScreen**

In `lib/features/listening/presentation/screens/listening_home_screen.dart`, replace the current disabled second `Card`:

```dart
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              enabled: false,
              leading: Icon(
                Icons.quiz_outlined,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
              ),
              title: const Text('Nghe hiểu'),
              subtitle: const Text(
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
              ),
              trailing: Chip(label: const Text('Sắp ra mắt')),
            ),
          ),
```

with:

```dart
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.quiz_outlined),
              title: const Text('Nghe hiểu'),
              subtitle: const Text(
                'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm kiểu TOEIC.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/listening/comprehension'),
            ),
          ),
```

(`theme` may now be unused in this file if nothing else in `build()` references it — check, and if so remove the now-dead `final theme = Theme.of(context);` line and the `theme` import usage; if `theme` is still used elsewhere in the file, leave it.)

- [ ] **Step 10: Update the hub screen test**

`test/features/listening/presentation/screens/listening_home_screen_test.dart` currently reads exactly:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/listening/presentation/screens/listening_home_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ListeningHomeScreen(),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows both Nghe chép and Nghe hiểu cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Nghe chép'), findsOneWidget);
    expect(find.text('Nghe hiểu'), findsOneWidget);
    expect(find.text('Sắp ra mắt'), findsOneWidget);
  });

  testWidgets('tapping Nghe chép navigates to dictation home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();
    expect(find.text('Dictation home'), findsOneWidget);
  });
}
```

Replace the whole file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/listening/presentation/screens/listening_home_screen.dart';

Widget _buildHub() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ListeningHomeScreen(),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
      GoRoute(
        path: '/listening/comprehension',
        builder: (ctx, state) => const Scaffold(body: Text('Comprehension home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('shows both Nghe chép and Nghe hiểu cards', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    expect(find.text('Nghe chép'), findsOneWidget);
    expect(find.text('Nghe hiểu'), findsOneWidget);
  });

  testWidgets('tapping Nghe chép navigates to dictation home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();
    expect(find.text('Dictation home'), findsOneWidget);
  });

  testWidgets('tapping Nghe hiểu navigates to comprehension home', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();
    expect(find.text('Comprehension home'), findsOneWidget);
  });
}
```

Note the removed assertion `expect(find.text('Sắp ra mắt'), findsOneWidget)` — that chip no longer exists once Step 9 enables the card, so this line is deleted, not just left to fail.

- [ ] **Step 11: Analyze and build**

```bash
flutter analyze lib/
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/
```

Expected: no issues after code generation.

- [ ] **Step 12: Run full test suite**

```bash
flutter test
```

Expected: all tests pass (no regressions), including the updated hub test.

- [ ] **Step 13: Verify web build**

```bash
flutter build web --release
```

Expected: builds successfully.

- [ ] **Step 14: Commit**

```bash
git add lib/features/listening/presentation/providers/listening_comprehension_provider.dart \
        lib/features/listening/presentation/providers/listening_comprehension_provider.g.dart \
        lib/features/listening/presentation/screens/comprehension_home_screen.dart \
        lib/features/listening/presentation/screens/comprehension_session_screen.dart \
        lib/features/listening/presentation/screens/comprehension_result_screen.dart \
        lib/features/listening/presentation/screens/listening_home_screen.dart \
        lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart \
        lib/core/router/app_router.dart \
        test/features/listening/presentation/providers/listening_comprehension_provider_test.dart \
        test/features/listening/presentation/screens/listening_home_screen_test.dart
git commit -m "feat(plan10): wire ListeningComprehensionNotifier, DI, routes, and enable Nghe hiểu card"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: flutter analyze + flutter build web results
Concerns: (if any)
