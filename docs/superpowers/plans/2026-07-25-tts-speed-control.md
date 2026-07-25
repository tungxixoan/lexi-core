# TTS Playback-Speed Control (Nghe chép & Nghe hiểu) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 0.75x/1x/1.25x playback-speed selector to both Nghe chép (Dictation) and Nghe hiểu (Comprehension), session-scoped only, with Dictation counting a mid-play speed change as a replay (existing 5% penalty) and Comprehension staying completely free.

**Architecture:** Layer the change bottom-up: `TtsService` gains an optional `rate` param first, then each provider gains a `speedMultiplier`/`setSpeed()` (Dictation also gains `isSpeaking`, which it didn't track before), then each screen gets a small `_SpeedSelector` widget wired to `setSpeed()`. Four tasks, each independently testable.

**Tech Stack:** Flutter, Riverpod (`@riverpod` code-gen notifiers), `flutter_tts`, `flutter_test`, `mocktail`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-25-tts-speed-control-design.md`
- Rate mapping: `_rateFor(multiplier) = (0.5 * multiplier).clamp(0.0, 1.0)` → 0.75x=0.375, 1x=0.5, 1.25x=0.625. Private helper duplicated per-provider file (no shared module).
- `TtsService.speak()`'s new `rate` param is **nullable**, no default value — only calls `setSpeechRate` when explicitly passed, so all other existing callers (vocab/dictionary screens) are unaffected.
- Speed is session-only — resets to 1.0 on every `generate()`, never persisted.
- Dictation: changing speed while `isSpeaking` stops playback, replays the full sentence at the new rate, and counts as a replay (`replayCount += 1`) — same as the existing "Nghe lại" button, no new penalty formula. Changing speed while idle only stores the choice, plays nothing, free.
- Comprehension: changing speed while `isSpeaking` stops playback and replays the current turn via `playCurrentTurn()` (auto-continue included) — always free, no `ComprehensionSessionResult`/SM-2 impact. Changing speed while idle only stores the choice.
- UI control: `SegmentedButton<double>` with segments `0.75x`/`1x`/`1.25x` (app uses `useMaterial3: true`).
- Run tests with `flutter test <path>`.

---

### Task 1: `TtsService` — add a nullable `rate` param

**Files:**
- Modify: `lib/services/tts_service.dart`
- Modify: `test/services/tts_service_test.dart`
- Modify (compile-compatibility, hand-written fakes that `implements TtsService`): `test/features/listening/presentation/screens/dictation_session_screen_test.dart:16-26`, `test/features/listening/presentation/screens/comprehension_session_screen_test.dart:14-19`

**Interfaces:**
- Consumes: nothing new.
- Produces: `TtsService.speak(String text, Language language, {double pitch = 1.0, double? rate})` — the `rate` param that Tasks 2 and 3 pass through.

- [ ] **Step 1: Write the failing tests**

In `test/services/tts_service_test.dart`, add `when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);` to the `setUp()` block (alongside the existing `setPitch`/`speak`/`stop` stubs), then add two new tests after the existing `'speak() forwards a custom pitch'` test:

```dart
  test('speak() does not call setSpeechRate when rate is omitted', () async {
    await service.speak('Hello world.', Language.english);
    verifyNever(() => mockTts.setSpeechRate(any()));
  });

  test('speak() forwards a custom rate via setSpeechRate', () async {
    await service.speak('Hi there.', Language.english, rate: 0.375);
    verify(() => mockTts.setSpeechRate(0.375)).called(1);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/tts_service_test.dart`
Expected: FAIL with a compile error — `rate` is not a parameter of `speak()` yet.

- [ ] **Step 3: Add `rate` to `TtsService`/`FlutterTtsService`**

Replace the full content of `lib/services/tts_service.dart`:

```dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

abstract class TtsService {
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate});
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  FlutterTtsService(this._tts) {
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate}) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.setPitch(pitch);
    if (rate != null) await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
```

- [ ] **Step 4: Fix the two hand-written fakes so the suite still compiles**

In `test/features/listening/presentation/screens/dictation_session_screen_test.dart`, replace:

```dart
class _FakeTtsService implements TtsService {
  int speakCount = 0;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {
    speakCount++;
  }

  @override
  Future<void> stop() async {}
}
```

with:

```dart
class _FakeTtsService implements TtsService {
  int speakCount = 0;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate}) async {
    speakCount++;
  }

  @override
  Future<void> stop() async {}
}
```

In `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`, replace:

```dart
class _FakeTtsService implements TtsService {
  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {}
  @override
  Future<void> stop() async {}
}
```

with:

```dart
class _FakeTtsService implements TtsService {
  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate}) async {}
  @override
  Future<void> stop() async {}
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/services/tts_service_test.dart`
Expected: PASS — all 5 tests green.

- [ ] **Step 6: Run the full suite to confirm nothing else broke**

Run: `flutter test`
Expected: PASS — same total count as before this task (adding an optional nullable param is backward-compatible for every other `speak()` call site in `lib/`, which don't pass `rate` and are unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/services/tts_service.dart test/services/tts_service_test.dart test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(tts): add optional playback rate param to TtsService.speak()"
```

---

### Task 2: Dictation provider — `isSpeaking`, `speedMultiplier`, `setSpeed()`

**Files:**
- Modify: `lib/features/listening/presentation/providers/dictation_practice_provider.dart`
- Modify: `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`

**Interfaces:**
- Consumes: `TtsService.speak(text, language, {pitch, rate})` from Task 1.
- Produces: `DictationSessionState.speedMultiplier` (double, default `1.0`), `DictationSessionState.isSpeaking` (bool, default `false`) — **new field, this provider didn't track playback state before**. `DictationPracticeNotifier.setSpeed(double multiplier)` (`Future<void>`) — Task 4's dictation screen calls this.

- [ ] **Step 1: Update existing `speak()` stubs/verifies in the test file to account for the new `rate` argument**

`play()`/`seekTo()` will start passing `rate:` on every call once Step 3 lands, which changes their mocktail invocation shape — every existing `when()`/`verify()` on `mockTts.speak(...)` in this file must be updated first, or the whole file breaks. In `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`, apply these exact replacements:

Replace (appears twice, in the `'DictationPracticeNotifier lifecycle'` and `'DictationPracticeNotifier difficulty/blanks'` `setUp()` blocks):

```dart
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
          .thenAnswer((_) async {});
```

with:

```dart
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```

Replace (in `'first play() sets hasPlayedOnce...'`):

```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
          .called(1);
```

with:

```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1);
```

Replace (in `'second play() increments replayCount...'`):

```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
          .called(2);
```

with:

```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(2);
```

Replace (in the `'DictationPracticeNotifier seekTo'` `setUp()`):

```dart
      when(() => mockTts.speak(any(), any())).thenAnswer((_) async {});
```

with:

```dart
      when(() => mockTts.speak(any(), any(), rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```

Replace (in `'first seekTo() sets hasPlayedOnce...'`):

```dart
      verify(() => mockTts.speak('world.', fixedItem.targetLanguage)).called(1);
```

with:

```dart
      verify(() => mockTts.speak('world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
```

Replace (in `'seekTo() after the first listen adds the correct penalty fraction'`):

```dart
      verify(() => mockTts.speak('Hello world.', fixedItem.targetLanguage)).called(1);
```

with:

```dart
      verify(() => mockTts.speak('Hello world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
```

Replace (in `'seekTo() with an out-of-range wordIndex is a no-op'`):

```dart
      verifyNever(() => mockTts.speak(any(), any()));
```

with:

```dart
      verifyNever(() => mockTts.speak(any(), any(), rate: any(named: 'rate')));
```

- [ ] **Step 2: Run the file to verify these still fail (rate isn't implemented yet, so the real calls don't include it — matches will fail on the new `rate:` expectations)**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: FAIL — the `when()`/`verify()` calls above now expect a `rate` argument the current implementation never passes, so matching invocations aren't found (e.g. `Expected: exactly 1 matching invocations... Actual: no matching invocations`).

- [ ] **Step 3: Add `isSpeaking`/`speedMultiplier` to `DictationSessionState` and thread `rate` through `play()`/`seekTo()`**

In `lib/features/listening/presentation/providers/dictation_practice_provider.dart`, replace the `DictationSessionState` class:

```dart
final class DictationSessionState {
  const DictationSessionState({
    required this.item,
    required this.typedText,
    required this.replayCount,
    required this.hasPlayedOnce,
    required this.startedAt,
    required this.isComplete,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
    this.seekCount = 0,
    this.seekPenaltyTotal = 0.0,
    this.speedMultiplier = 1.0,
    this.isSpeaking = false,
  });

  final DictationItem item;
  final String typedText;
  final int replayCount;
  final bool hasPlayedOnce;
  final DateTime startedAt;
  final bool isComplete;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;
  final int seekCount;
  final double seekPenaltyTotal;
  final double speedMultiplier;
  final bool isSpeaking;

  bool get isClozeMode => difficulty != DictationDifficulty.hard;

  bool get allBlanksFilled =>
      blankAnswers.isNotEmpty && blankAnswers.every((a) => a.trim().isNotEmpty);

  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
    int? seekCount,
    double? seekPenaltyTotal,
    double? speedMultiplier,
    bool? isSpeaking,
  }) =>
      DictationSessionState(
        item: item,
        typedText: typedText ?? this.typedText,
        replayCount: replayCount ?? this.replayCount,
        hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
        startedAt: startedAt,
        isComplete: isComplete ?? this.isComplete,
        difficulty: difficulty,
        blanks: blanks,
        blankAnswers: blankAnswers ?? this.blankAnswers,
        seekCount: seekCount ?? this.seekCount,
        seekPenaltyTotal: seekPenaltyTotal ?? this.seekPenaltyTotal,
        speedMultiplier: speedMultiplier ?? this.speedMultiplier,
        isSpeaking: isSpeaking ?? this.isSpeaking,
      );
}
```

Add this private helper right after the `DictationSessionState` class (before `@riverpod class DictationPracticeNotifier`):

```dart
double _rateFor(double speedMultiplier) => (0.5 * speedMultiplier).clamp(0.0, 1.0);
```

Replace `play()`:

```dart
  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.hasPlayedOnce
        ? current.copyWith(replayCount: current.replayCount + 1, isSpeaking: true)
        : current.copyWith(hasPlayedOnce: true, isSpeaking: true);
    state = AsyncData(updated);
    await ref.read(ttsServiceProvider).speak(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

Replace `seekTo()`:

```dart
  Future<void> seekTo(int wordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    final words = current.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (wordIndex < 0 || wordIndex >= words.length) return;

    final updated = current.hasPlayedOnce
        ? current.copyWith(
            seekCount: current.seekCount + 1,
            seekPenaltyTotal: current.seekPenaltyTotal +
                seekPenaltyFraction(wordIndex: wordIndex, totalWords: words.length),
            isSpeaking: true,
          )
        : current.copyWith(
            hasPlayedOnce: true, seekCount: current.seekCount + 1, isSpeaking: true);
    state = AsyncData(updated);

    await ref.read(ttsServiceProvider).stop();
    await ref.read(ttsServiceProvider).speak(
          words.skip(wordIndex).join(' '),
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

- [ ] **Step 4: Run tests to verify the Step-1 changes now pass (setSpeed tests not added yet)**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS — all existing tests green again.

- [ ] **Step 5: Write the failing `setSpeed()` tests**

Add this new group at the end of `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`, right before the file's final closing `}`:

```dart
  group('DictationPracticeNotifier setSpeed', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('Hello world.');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    Future<void> generateSession(DictationPracticeNotifier notifier) =>
        notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('setSpeed() while idle only updates speedMultiplier, plays nothing, '
        'and does not touch hasPlayedOnce/replayCount', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.setSpeed(0.75);

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.hasPlayedOnce, false);
      expect(state.replayCount, 0);
      verifyNever(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
          rate: any(named: 'rate')));
      verifyNever(() => mockTts.stop());
    });

    test('setSpeed() while speaking stops, replays the sentence at the new rate, '
        'and counts as a replay', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      final completer = Completer<void>();
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) => completer.future);
      when(() => mockTts.stop()).thenAnswer((_) async {});

      final playFuture = notifier.play(); // starts speaking, hangs on completer
      final speedFuture = notifier.setSpeed(0.75);
      completer.complete(); // let both hung speak() calls resolve
      await playFuture;
      await speedFuture;

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.replayCount, 1);
      expect(state.isSpeaking, false);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1); // the original play(), at the default 1x rate
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.375))
          .called(1); // the setSpeed()-triggered replay, at the new 0.75x rate
    });

    test('setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next play()', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});

      await notifier.setSpeed(1.25); // idle: just stores the choice
      await notifier.play();

      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.625))
          .called(1);
    });
  });
```

Add `import 'dart:async';` to the top of the file (needed for `Completer`) — it must appear before the `package:` imports, matching Dart's import-ordering convention already used in `listening_comprehension_provider_test.dart`.

- [ ] **Step 6: Run tests to verify the new group fails**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: FAIL — `setSpeed` is not a method on `DictationPracticeNotifier` yet (compile error).

- [ ] **Step 7: Implement `setSpeed()`**

Add this method to `DictationPracticeNotifier` in `lib/features/listening/presentation/providers/dictation_practice_provider.dart`, right after `seekTo()`:

```dart
  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      speedMultiplier: multiplier,
      replayCount: current.replayCount + 1,
      isSpeaking: true,
    ));
    await ref.read(ttsServiceProvider).speak(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(multiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS — all tests green (existing + new `setSpeed` group).

- [ ] **Step 9: Commit**

```bash
git add lib/features/listening/presentation/providers/dictation_practice_provider.dart test/features/listening/presentation/providers/dictation_practice_provider_test.dart
git commit -m "feat(dictation): add speed control (0.75x/1x/1.25x), counted as a replay mid-play"
```

---

### Task 3: Listening provider — `speedMultiplier`, `setSpeed()` (always free)

**Files:**
- Modify: `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
- Modify: `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`

**Interfaces:**
- Consumes: `TtsService.speak(text, language, {pitch, rate})` from Task 1; `ListeningComprehensionNotifier.playCurrentTurn()` (existing, unchanged signature) — `setSpeed()` calls it to restart the current turn.
- Produces: `ListeningSessionState.speedMultiplier` (double, default `1.0`). `ListeningComprehensionNotifier.setSpeed(double multiplier)` (`Future<void>`) — Task 4's comprehension screen calls this.

- [ ] **Step 1: Update existing `speak()` stubs/verifies in the test file to account for the new `rate` argument**

In `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`, apply these exact replacements:

Replace (in `setUp()`):

```dart
    when(
      () => mockTts.speak(any(), any(), pitch: any(named: 'pitch')),
    ).thenAnswer((_) async {});
```

with:

```dart
    when(
      () => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')),
    ).thenAnswer((_) async {});
```

Replace (in `'playCurrentTurn() speaks the current turn...'`):

```dart
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0)).called(1);
```

with:

```dart
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.5))
        .called(1);
```

Replace (in `'playCurrentTurn() auto-continues through every turn until the last one'`):

```dart
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0)).called(1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3))
        .called(1);
    verify(() => mockTts.speak('Sure, for how many guests?', Language.english, pitch: 1.0))
        .called(1);
```

with:

```dart
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.5))
        .called(1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3,
            rate: 0.5))
        .called(1);
    verify(() => mockTts.speak('Sure, for how many guests?', Language.english, pitch: 1.0,
            rate: 0.5))
        .called(1);
```

Replace (in `'interrupting playback via stopPlayback() cancels the auto-continue chain'`):

```dart
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch')))
        .thenAnswer((_) => completer.future);
```

with:

```dart
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);
```

and, later in the same test:

```dart
    verify(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'))).called(1); // no auto-continue
```

with:

```dart
    verify(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .called(1); // no auto-continue
```

Replace (in `'seekToWord within the first turn...'`):

```dart
    verify(() => mockTts.speak('I help you?', Language.english, pitch: 1.0)).called(1);
```

with:

```dart
    verify(() => mockTts.speak('I help you?', Language.english, pitch: 1.0, rate: 0.5)).called(1);
```

Replace (in `"seekToWord crossing into a later turn..."`):

```dart
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3))
        .called(1);
```

with:

```dart
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3,
            rate: 0.5))
        .called(1);
```

Replace (in `'seekToWord with an out-of-range index is a no-op'`):

```dart
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch')));
```

with:

```dart
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')));
```

- [ ] **Step 2: Run tests to verify these now fail (rate isn't implemented yet)**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: FAIL — the updated `when()`/`verify()` calls expect a `rate` argument the current implementation never passes.

- [ ] **Step 3: Add `speedMultiplier` to `ListeningSessionState` and thread `rate` through `playCurrentTurn()`/`seekToWord()`**

In `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`, replace the `ListeningSessionState` class:

```dart
final class ListeningSessionState {
  const ListeningSessionState({
    required this.passage,
    required this.currentTurnIndex,
    required this.isSpeaking,
    required this.playToken,
    required this.selectedAnswers,
    required this.isSubmitted,
    this.speedMultiplier = 1.0,
  });

  final ListeningPassage passage;
  final int currentTurnIndex;
  final bool isSpeaking;
  final int playToken;
  final List<int?> selectedAnswers;
  final bool isSubmitted;
  final double speedMultiplier;

  ListeningTurn get currentTurn => passage.turns[currentTurnIndex];
  bool get canSubmit => selectedAnswers.every((a) => a != null);

  ListeningSessionState copyWith({
    int? currentTurnIndex,
    bool? isSpeaking,
    int? playToken,
    List<int?>? selectedAnswers,
    bool? isSubmitted,
    double? speedMultiplier,
  }) =>
      ListeningSessionState(
        passage: passage,
        currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
        isSpeaking: isSpeaking ?? this.isSpeaking,
        playToken: playToken ?? this.playToken,
        selectedAnswers: selectedAnswers ?? this.selectedAnswers,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      );
}
```

Add this private helper right after the class (before `_splitWords`):

```dart
double _rateFor(double speedMultiplier) => (0.5 * speedMultiplier).clamp(0.0, 1.0);
```

Replace `playCurrentTurn()`:

```dart
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
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    if (latest.currentTurnIndex < latest.passage.turns.length - 1) {
      // Turn finished naturally (not interrupted) and it's not the last one
      // — keep going without a gap, staying "isSpeaking" the whole time.
      state = AsyncData(latest.copyWith(currentTurnIndex: latest.currentTurnIndex + 1));
      await playCurrentTurn();
      return;
    }
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

Replace `seekToWord()`:

```dart
  Future<void> seekToWord(int globalWordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final total = totalWordsOf(current.passage);
    if (globalWordIndex < 0 || globalWordIndex >= total) return;

    final resolved = _resolveGlobalWordIndex(current.passage, globalWordIndex);
    final turn = current.passage.turns[resolved.turnIndex];
    final words = _splitWords(turn.text);
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(
      currentTurnIndex: resolved.turnIndex,
      isSpeaking: true,
      playToken: token,
    ));
    await ref.read(ttsServiceProvider).stop();
    await ref.read(ttsServiceProvider).speak(
          words.skip(resolved.wordIndex).join(' '),
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

- [ ] **Step 4: Run tests to verify the Step-1 changes now pass (setSpeed tests not added yet)**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: PASS — all existing tests green again.

- [ ] **Step 5: Write the failing `setSpeed()` tests**

Add these tests at the end of `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`, right before the file's final closing `}`:

```dart
  test('setSpeed() while idle only updates speedMultiplier and plays nothing', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(0.75);

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
    expect(state.isSpeaking, false);
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')));
    verifyNever(() => mockTts.stop());
  });

  test('setSpeed() while speaking stops the current turn and replays it at the new rate', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    final completer = Completer<void>();
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn(); // hangs on completer for turn 0
    final speedFuture = notifier.setSpeed(0.75);
    completer.complete(); // let every hung/future speak() call resolve
    await playFuture;
    await speedFuture;

    verify(() => mockTts.stop()).called(1);
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.375))
        .called(1); // the setSpeed()-triggered restart, at the new 0.75x rate
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
  });

  test('setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next playCurrentTurn()', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(1.25); // idle: just stores the choice
    await notifier.playCurrentTurn();

    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.625))
        .called(1);
  });
```

- [ ] **Step 6: Run tests to verify the new tests fail**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: FAIL — `setSpeed` is not a method on `ListeningComprehensionNotifier` yet (compile error).

- [ ] **Step 7: Implement `setSpeed()`**

Add this method to `ListeningComprehensionNotifier` in `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`, right after `seekToWord()`:

```dart
  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(speedMultiplier: multiplier));
    await playCurrentTurn();
  }
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: PASS — all tests green (existing + 3 new `setSpeed` tests).

- [ ] **Step 9: Commit**

```bash
git add lib/features/listening/presentation/providers/listening_comprehension_provider.dart test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
git commit -m "feat(listening): add speed control (0.75x/1x/1.25x), always free"
```

---

### Task 4: UI — `_SpeedSelector` in both session screens

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`
- Modify: `lib/features/listening/presentation/screens/comprehension_session_screen.dart`
- Modify: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`
- Modify: `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`

**Interfaces:**
- Consumes: `DictationSessionState.speedMultiplier`/`DictationPracticeNotifier.setSpeed(double)` from Task 2; `ListeningSessionState.speedMultiplier`/`ListeningComprehensionNotifier.setSpeed(double)` from Task 3.
- Produces: no new public API — pure UI addition (one private `_SpeedSelector` widget per screen file, matching this file pair's existing precedent of separately-duplicated `_SeekSlider` widgets rather than a shared file).

- [ ] **Step 1: Write the failing widget tests for the Dictation screen**

Add this new group at the end of `test/features/listening/presentation/screens/dictation_session_screen_test.dart`, right before the file's final closing `}`:

```dart
  group('speed selector', () {
    testWidgets('defaults to the 1x segment selected', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();
      final segmented =
          tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));
      expect(segmented.selected, {1.0});
    });

    testWidgets('tapping 0.75x calls setSpeed(0.75) and updates the selected segment',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('0.75x'));
      await tester.pumpAndSettle();

      final segmented =
          tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));
      expect(segmented.selected, {0.75});
    });
  });
```

- [ ] **Step 2: Write the failing widget tests for the Comprehension screen**

Add this new group at the end of `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`, right before the file's final closing `}`:

```dart
  group('speed selector', () {
    testWidgets('defaults to the 1x segment selected', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();
      final segmented =
          tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));
      expect(segmented.selected, {1.0});
    });

    testWidgets('tapping 1.25x calls setSpeed(1.25) and updates the selected segment',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1.25x'));
      await tester.pumpAndSettle();

      final segmented =
          tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>));
      expect(segmented.selected, {1.25});
    });
  });
```

- [ ] **Step 3: Run both test files to verify the new tests fail**

Run: `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
Expected: FAIL — no `SegmentedButton<double>` exists in either screen yet (`findsNothing`/element-not-found errors).

- [ ] **Step 4: Add `_SpeedSelector` to the Dictation screen**

In `lib/features/listening/presentation/screens/dictation_session_screen.dart`, change the controls block inside `_SessionScaffold.build()` — replace:

```dart
            const Spacer(),
            _SeekSlider(totalWords: wordCount, onSeek: notifier.seekTo),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
                icon: Icon(session.hasPlayedOnce ? Icons.replay : Icons.play_arrow),
                label: Text(
                  session.hasPlayedOnce
                      ? 'Nghe lại (${session.replayCount})'
                      : 'Phát',
                ),
              ),
            ),
            const SizedBox(height: 32),
```

with:

```dart
            const Spacer(),
            _SeekSlider(totalWords: wordCount, onSeek: notifier.seekTo),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
                icon: Icon(session.hasPlayedOnce ? Icons.replay : Icons.play_arrow),
                label: Text(
                  session.hasPlayedOnce
                      ? 'Nghe lại (${session.replayCount})'
                      : 'Phát',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: _SpeedSelector(
                speed: session.speedMultiplier,
                onChanged: notifier.setSpeed,
              ),
            ),
            const SizedBox(height: 32),
```

Then add this new widget class at the end of the file (after `_SeekSliderState`):

```dart
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 0.75, label: Text('0.75x')),
        ButtonSegment(value: 1.0, label: Text('1x')),
        ButtonSegment(value: 1.25, label: Text('1.25x')),
      ],
      selected: {speed},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}
```

- [ ] **Step 5: Add `_SpeedSelector` to the Comprehension screen**

In `lib/features/listening/presentation/screens/comprehension_session_screen.dart`, change the transport controls block inside `_SessionScaffold.build()` — replace:

```dart
                    _SeekSlider(passage: session.passage, onSeek: notifier.seekToWord),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: isFirstTurn ? null : notifier.previousTurn,
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            session.isSpeaking ? Icons.stop_circle : Icons.play_circle,
                          ),
                          onPressed: session.isSpeaking
                              ? notifier.stopPlayback
                              : notifier.playCurrentTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: isLastTurn ? null : notifier.nextTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: notifier.replayFromStart,
                        ),
                      ],
                    ),
```

with:

```dart
                    _SeekSlider(passage: session.passage, onSeek: notifier.seekToWord),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: isFirstTurn ? null : notifier.previousTurn,
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            session.isSpeaking ? Icons.stop_circle : Icons.play_circle,
                          ),
                          onPressed: session.isSpeaking
                              ? notifier.stopPlayback
                              : notifier.playCurrentTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: isLastTurn ? null : notifier.nextTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: notifier.replayFromStart,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SpeedSelector(
                      speed: session.speedMultiplier,
                      onChanged: notifier.setSpeed,
                    ),
```

Then add this new widget class at the end of the file (after `_SeekSliderState`):

```dart
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 0.75, label: Text('0.75x')),
        ButtonSegment(value: 1.0, label: Text('1x')),
        ButtonSegment(value: 1.25, label: Text('1.25x')),
      ],
      selected: {speed},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
Expected: PASS — all tests green (existing + 4 new `speed selector` tests).

- [ ] **Step 7: Run the full test suite to check for regressions**

Run: `flutter test`
Expected: PASS — no regressions anywhere in the repo.

- [ ] **Step 8: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart lib/features/listening/presentation/screens/comprehension_session_screen.dart test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(listening): add 0.75x/1x/1.25x speed selector to Nghe chép and Nghe hiểu"
```

---

## Final check

- [ ] Run the whole suite once: `flutter test`
- [ ] Expected: PASS, no regressions across `services`, `listening` (dictation + comprehension).
