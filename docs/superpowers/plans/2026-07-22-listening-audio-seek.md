# Thanh tua âm thanh cho Nghe chép & Nghe hiểu — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "tua theo từ" (word-position seek) slider to both Nghe chép (Dictation) and Nghe hiểu (Comprehension) session screens, letting users jump TTS playback to a specific word instead of always replaying from the start.

**Architecture:** No audio file exists (TTS speaks live via `flutter_tts`), so there is no timestamp to seek to. Both features split their text into words and let the slider pick a **word index**; releasing the slider stops any current TTS utterance and re-speaks from that word to the end of the sentence/turn. Nghe chép additionally tracks a new anti-cheat scoring penalty per seek (1%–5%, scaled by how much of the sentence gets re-heard); Nghe hiểu's seek stays entirely free, matching its existing zero-penalty design.

**Tech Stack:** Flutter, Riverpod (`@riverpod` codegen), `flutter_tts` via the existing `TtsService` abstraction, `flutter_test` + `mocktail`.

**Spec:** `docs/superpowers/specs/2026-07-22-listening-audio-seek-design.md`

## Global Constraints

- No new dependency, no audio player, no audio file generation — reuse `TtsService.speak()`/`.stop()` exactly as it exists today (signature: `Future<void> speak(String text, Language language, {double pitch = 1.0})`, `Future<void> stop()`).
- No live progress tracking — the slider never moves on its own while TTS is speaking; it only reacts to user drag.
- Both sliders render **above** their screen's playback control buttons (Nghe chép: above the Phát/Nghe lại button; Nghe hiểu: above the ⏮/▶⏸/⏭/🔁 row).
- Nghe chép seek penalty formula (per released seek, added to a new cumulative `seekPenaltyTotal`): `wordsReheard = totalWords - wordIndex`; `reheardRatio = wordsReheard / totalWords`; if `reheardRatio <= 0.2` → `0.01`; else → `(0.01 + 0.04 * (reheardRatio - 0.2) / 0.8).clamp(0.01, 0.05)`.
- Nghe chép's existing "Nghe lại" button (full replay from start, `replayCount`, flat 5%/use) is **unchanged** — the new seek penalty is separate and additive: `finalScore = (rawAccuracy - 0.05 * replayCount - seekPenaltyTotal).clamp(0.0, 1.0)`.
- The very first listen of a Nghe chép session — via the Phát button **or** via the seek slider, whichever happens first — is always free (existing `hasPlayedOnce` gate); only listens after that are penalized.
- Nghe hiểu's seek is **entirely free**: no new score/penalty field, no change to `ComprehensionSessionResult`, no SM-2 interaction — matches the feature's existing zero-penalty design.
- Nghe hiểu's existing ⏮/▶⏸/⏭/🔁 controls stay exactly as they are; the slider is a purely additive way to seek.

---

### Task 1: Nghe chép — seek penalty formula + `DictationPracticeNotifier.seekTo()`

**Files:**
- Modify: `lib/features/listening/presentation/providers/dictation_practice_provider.dart`
- Test: `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`

**Interfaces:**
- Consumes: existing `DictationSessionResult`/`DictationSessionState`/`DictationPracticeNotifier` (this file), `TtsService.speak(String, Language, {double pitch})`/`.stop()`.
- Produces: top-level function `double seekPenaltyFraction({required int wordIndex, required int totalWords})`; new fields `DictationSessionResult.seekCount` (`int`, default `0`), `DictationSessionResult.seekPenaltyTotal` (`double`, default `0.0`), `DictationSessionState.seekCount`, `DictationSessionState.seekPenaltyTotal` (same defaults); new method `Future<void> DictationPracticeNotifier.seekTo(int wordIndex)`. Task 2 and Task 3 consume all of these.

- [ ] **Step 1: Write the failing tests for `seekPenaltyFraction`**

Open `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`. Add this new group right after the `void main() {` line (before the existing `group('DictationSessionResult scoring', ...)`):

```dart
  group('seekPenaltyFraction', () {
    test('returns the 1% floor when reheardRatio is at or below 20%', () {
      expect(seekPenaltyFraction(wordIndex: 8, totalWords: 10), closeTo(0.01, 0.0001)); // ratio 0.2 exactly
      expect(seekPenaltyFraction(wordIndex: 9, totalWords: 10), closeTo(0.01, 0.0001)); // ratio 0.1
    });

    test('scales linearly from 1% to 5% as reheardRatio grows from 20% to 100%', () {
      expect(seekPenaltyFraction(wordIndex: 5, totalWords: 10), closeTo(0.025, 0.0001)); // ratio 0.5
      expect(seekPenaltyFraction(wordIndex: 0, totalWords: 10), closeTo(0.05, 0.0001)); // ratio 1.0
    });

    test('returns 0 when totalWords is 0 (guards against division by zero)', () {
      expect(seekPenaltyFraction(wordIndex: 0, totalWords: 0), 0.0);
    });
  });

```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: FAIL — `seekPenaltyFraction` is not defined.

- [ ] **Step 3: Add `seekPenaltyFraction` to the provider file**

Open `lib/features/listening/presentation/providers/dictation_practice_provider.dart`. Find this exact block (the end of the `DictationSessionResult` class, right before `final class DictationSessionState {`):

```dart
  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
}

final class DictationSessionState {
```

Replace it with:

```dart
  int get sm2Quality {
    final score = finalScore;
    if (score >= 0.95) return 5;
    if (score >= 0.80) return 4;
    if (score >= 0.60) return 3;
    if (score >= 0.40) return 2;
    return 0;
  }
}

/// Fraction (0.01–0.05) deducted for a single seek to [wordIndex] out of
/// [totalWords] words in the sentence. TTS always speaks from the seek
/// point to the end of the sentence, so seeking near the start re-hears
/// almost the whole sentence (expensive) while seeking near the end
/// re-hears almost nothing (cheap) — this scales the penalty accordingly.
double seekPenaltyFraction({required int wordIndex, required int totalWords}) {
  if (totalWords <= 0) return 0.0;
  final wordsReheard = totalWords - wordIndex;
  final reheardRatio = wordsReheard / totalWords;
  if (reheardRatio <= 0.2) return 0.01;
  return (0.01 + 0.04 * (reheardRatio - 0.2) / 0.8).clamp(0.01, 0.05);
}

final class DictationSessionState {
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS for the 3 new `seekPenaltyFraction` tests (other tests in the file will still fail — later steps fix those).

- [ ] **Step 5: Add `seekCount`/`seekPenaltyTotal` fields to `DictationSessionResult`**

Find this exact block:

```dart
final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;
```

Replace it with:

```dart
final class DictationSessionResult {
  const DictationSessionResult({
    required this.item,
    required this.typed,
    required this.replayCount,
    required this.duration,
    this.difficulty = DictationDifficulty.hard,
    this.blanks = const [],
    this.blankAnswers = const [],
    this.seekCount = 0,
    this.seekPenaltyTotal = 0.0,
  });

  final DictationItem item;
  final String typed;
  final int replayCount;
  final Duration duration;
  final DictationDifficulty difficulty;
  final List<BlankSpan> blanks;
  final List<String> blankAnswers;
  final int seekCount;
  final double seekPenaltyTotal;
```

- [ ] **Step 6: Update `finalScore` to subtract `seekPenaltyTotal`**

Find this exact line:

```dart
  double get finalScore => (_rawAccuracy - 0.05 * replayCount).clamp(0.0, 1.0);
```

Replace it with:

```dart
  double get finalScore =>
      (_rawAccuracy - 0.05 * replayCount - seekPenaltyTotal).clamp(0.0, 1.0);
```

- [ ] **Step 7: Write the failing test for `finalScore` with `seekPenaltyTotal`**

In the `group('DictationSessionResult scoring', ...)` group, add this test right after `'finalScore subtracts 5% per replay beyond the first listen'`:

```dart

    test('finalScore also subtracts seekPenaltyTotal on top of the replay penalty', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 1,
        duration: const Duration(seconds: 5),
        seekPenaltyTotal: 0.03,
      );
      expect(result.finalScore, closeTo(0.92, 0.0001)); // 1.0 - 0.05 - 0.03
    });
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS for the new `finalScore` test.

- [ ] **Step 9: Add `seekCount`/`seekPenaltyTotal` fields to `DictationSessionState`**

Find this exact block:

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
```

Replace it with:

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
```

- [ ] **Step 10: Update `copyWith` to carry the new fields**

Find this exact block:

```dart
  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
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
      );
```

Replace it with:

```dart
  DictationSessionState copyWith({
    String? typedText,
    int? replayCount,
    bool? hasPlayedOnce,
    bool? isComplete,
    List<String>? blankAnswers,
    int? seekCount,
    double? seekPenaltyTotal,
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
      );
```

- [ ] **Step 11: Run the full test file to confirm nothing else broke**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS — all existing tests still pass (the new fields default to `0`/`0.0`, matching prior behavior byte-for-byte).

- [ ] **Step 12: Write the failing tests for `seekTo()`**

Add this new group at the end of `main()`, after the `group('DictationPracticeNotifier difficulty/blanks', ...)` group's closing `});`:

```dart

  group('DictationPracticeNotifier seekTo', () {
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
      when(() => mockTts.speak(any(), any())).thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});
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

    test('first seekTo() sets hasPlayedOnce and seekCount without adding a penalty', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(1); // "world."

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, true);
      expect(state.seekCount, 1);
      expect(state.seekPenaltyTotal, 0.0);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.speak('world.', fixedItem.targetLanguage)).called(1);
    });

    test('seekTo() after the first listen adds the correct penalty fraction', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(1); // first listen via seek: free
      await notifier.seekTo(0); // "Hello world." — wordsReheard 2/2 = 100% ratio -> max 5%

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.seekCount, 2);
      expect(state.seekPenaltyTotal, closeTo(0.05, 0.0001));
      verify(() => mockTts.speak('Hello world.', fixedItem.targetLanguage)).called(1);
    });

    test('seekTo() with an out-of-range wordIndex is a no-op', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(-1);
      await notifier.seekTo(2); // only indices 0-1 are valid for a 2-word sentence

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, false);
      expect(state.seekCount, 0);
      expect(state.seekPenaltyTotal, 0.0);
      verifyNever(() => mockTts.speak(any(), any()));
    });
  });
```

- [ ] **Step 13: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: FAIL — `seekTo` is not defined on `DictationPracticeNotifier`.

- [ ] **Step 14: Add `seekTo()` to `DictationPracticeNotifier`**

Find this exact block (the `play()` method, immediately followed by `updateTypedText`):

```dart
  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.hasPlayedOnce
          ? current.copyWith(replayCount: current.replayCount + 1)
          : current.copyWith(hasPlayedOnce: true),
    );
    await ref
        .read(ttsServiceProvider)
        .speak(current.item.target, current.item.targetLanguage);
  }

  void updateTypedText(String text) {
```

Replace it with:

```dart
  Future<void> play() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.hasPlayedOnce
          ? current.copyWith(replayCount: current.replayCount + 1)
          : current.copyWith(hasPlayedOnce: true),
    );
    await ref
        .read(ttsServiceProvider)
        .speak(current.item.target, current.item.targetLanguage);
  }

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
          )
        : current.copyWith(hasPlayedOnce: true, seekCount: current.seekCount + 1);
    state = AsyncData(updated);

    await ref.read(ttsServiceProvider).stop();
    await ref.read(ttsServiceProvider).speak(
          words.skip(wordIndex).join(' '),
          current.item.targetLanguage,
        );
  }

  void updateTypedText(String text) {
```

- [ ] **Step 15: Run the test file to verify everything passes**

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: PASS — all tests in the file (existing + new).

- [ ] **Step 16: Run the full suite and analyze**

Run: `flutter test`
Expected: PASS, all tests green.

Run: `flutter analyze lib/features/listening/presentation/providers/dictation_practice_provider.dart`
Expected: no issues.

- [ ] **Step 17: Commit**

```bash
git add lib/features/listening/presentation/providers/dictation_practice_provider.dart \
        test/features/listening/presentation/providers/dictation_practice_provider_test.dart
git commit -m "feat(listening-seek): add seek penalty formula and seekTo() to DictationPracticeNotifier"
```

---

### Task 2: Nghe chép — seek slider UI on `DictationSessionScreen`

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`

**Interfaces:**
- Consumes: `DictationPracticeNotifier.seekTo(int wordIndex)`, `DictationSessionState.item.target`, `DictationSessionState.seekCount`/`.seekPenaltyTotal` (Task 1).
- Produces: new private widget `_SeekSlider` in this file (not consumed elsewhere); `DictationSessionResult` now constructed with `seekCount`/`seekPenaltyTotal` populated from session state — Task 3 (result screen) consumes those two fields off the `DictationSessionResult` it receives.

- [ ] **Step 1: Write the failing tests**

Open `test/features/listening/presentation/screens/dictation_session_screen_test.dart`. Add these tests at the end of `main()`, after the `group('cloze mode (Dễ/Trung bình)', ...)` group's closing `});`:

```dart

  group('seek slider', () {
    testWidgets('shows a seek slider once the item has more than 1 word', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('shows a word-position label while dragging, before releasing', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged?.call(1.0); // word index 1 of 2: "world."
      await tester.pumpAndSettle();

      expect(find.text('Từ 2/2'), findsOneWidget);
    });

    testWidgets(
        'releasing the slider on the first-ever interaction sets hasPlayedOnce for free',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChangeEnd?.call(1.0); // word index 1: "world."
      await tester.pumpAndSettle();

      expect(find.text('Nghe lại (0)'), findsOneWidget);
    });

    testWidgets('submitting after seeking includes seekCount and seekPenaltyTotal in the result',
        (tester) async {
      Object? capturedExtra;
      await tester.pumpWidget(
        _buildSession(_session(), onResult: (extra) => capturedExtra = extra),
      );
      await tester.pumpAndSettle();

      final slider1 = tester.widget<Slider>(find.byType(Slider));
      slider1.onChangeEnd?.call(1.0); // first-ever listen via seek: free
      await tester.pumpAndSettle();

      final slider2 = tester.widget<Slider>(find.byType(Slider));
      slider2.onChangeEnd?.call(0.0); // back to word 0: full reheard -> 5%
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello world.');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();

      final result = capturedExtra! as DictationSessionResult;
      expect(result.seekCount, 2);
      expect(result.seekPenaltyTotal, closeTo(0.05, 0.0001));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart`
Expected: FAIL — no `Slider` widget exists yet.

- [ ] **Step 3: Add `seekCount`/`seekPenaltyTotal` to the result construction**

Open `lib/features/listening/presentation/screens/dictation_session_screen.dart`. Find this exact block:

```dart
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
            difficulty: session.difficulty,
            blanks: session.blanks,
            blankAnswers: session.blankAnswers,
          );
```

Replace it with:

```dart
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
            difficulty: session.difficulty,
            blanks: session.blanks,
            blankAnswers: session.blankAnswers,
            seekCount: session.seekCount,
            seekPenaltyTotal: session.seekPenaltyTotal,
          );
```

- [ ] **Step 4: Add the `_SeekSlider` widget and wire it into `_SessionScaffold`**

Find this exact block (in `_SessionScaffold.build()`):

```dart
    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chép'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
```

Replace it with:

```dart
    final wordCount = session.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chép'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            _SeekSlider(totalWords: wordCount, onSeek: notifier.seekTo),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
```

Now add the new widget class at the end of the file, after the closing brace of `_ClozeInput`:

```dart

class _SeekSlider extends StatefulWidget {
  const _SeekSlider({required this.totalWords, required this.onSeek});
  final int totalWords;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  int? _restWordIndex;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.totalWords <= 1) return const SizedBox.shrink();
    final value = (_restWordIndex ?? 0).toDouble();
    return Column(
      children: [
        if (_isDragging && _restWordIndex != null)
          Text('Từ ${_restWordIndex! + 1}/${widget.totalWords}'),
        Slider(
          value: value,
          min: 0,
          max: (widget.totalWords - 1).toDouble(),
          divisions: widget.totalWords - 1,
          onChanged: (v) => setState(() {
            _isDragging = true;
            _restWordIndex = v.round();
          }),
          onChangeEnd: (v) {
            setState(() {
              _isDragging = false;
              _restWordIndex = v.round();
            });
            widget.onSeek(v.round());
          },
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the widget test**

Run: `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart`
Expected: PASS — all tests (existing + new `seek slider` group).

- [ ] **Step 6: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Analyze**

Run: `flutter analyze lib/features/listening/presentation/screens/dictation_session_screen.dart`
Expected: no issues.

- [ ] **Step 8: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart \
        test/features/listening/presentation/screens/dictation_session_screen_test.dart
git commit -m "feat(listening-seek): add seek slider to DictationSessionScreen"
```

---

### Task 3: Nghe chép — "Số lần tua" stat on `DictationResultScreen`

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_result_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_result_screen_test.dart`

**Interfaces:**
- Consumes: `DictationSessionResult.seekCount`/`.seekPenaltyTotal` (Task 1).
- Produces: nothing consumed by later tasks — this is the last Nghe chép task.

- [ ] **Step 1: Write the failing test**

Open `test/features/listening/presentation/screens/dictation_result_screen_test.dart`. Add this test at the end of `main()`, right after the `'does not crash and performs zero updates when the vocab bank fetch throws'` test and before `group('cloze mode (Dễ/Trung bình)', ...)`:

```dart

  testWidgets('shows the Số lần tua stat with count and penalty percentage', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    final result = DictationSessionResult(
      item: _testItem,
      typed: 'Hello world.',
      replayCount: 0,
      duration: const Duration(seconds: 5),
      seekCount: 2,
      seekPenaltyTotal: 0.03,
    );
    await tester.pumpWidget(_buildResult(result, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Số lần tua'), findsOneWidget);
    expect(find.textContaining('2 (−3%)'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart`
Expected: FAIL — no "Số lần tua" text exists yet.

- [ ] **Step 3: Add the stat card**

Open `lib/features/listening/presentation/screens/dictation_result_screen.dart`. Find this exact block:

```dart
    final theme = Theme.of(context);
    final result = widget.result;
    final scorePct = (result.finalScore * 100).toStringAsFixed(0);
    final elapsed = _formatDuration(result.duration);
```

Replace it with:

```dart
    final theme = Theme.of(context);
    final result = widget.result;
    final scorePct = (result.finalScore * 100).toStringAsFixed(0);
    final seekPenaltyPct = (result.seekPenaltyTotal * 100).toStringAsFixed(0);
    final elapsed = _formatDuration(result.duration);
```

Find this exact block:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Điểm', value: '$scorePct%'),
                _StatCard(label: 'Nghe lại', value: '${result.replayCount}'),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
```

Replace it with:

```dart
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Điểm', value: '$scorePct%'),
                _StatCard(label: 'Nghe lại', value: '${result.replayCount}'),
                _StatCard(
                  label: 'Số lần tua',
                  value: '${result.seekCount} (−$seekPenaltyPct%)',
                ),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart`
Expected: PASS — all tests (existing + new).

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/listening/presentation/screens/dictation_result_screen.dart`
Expected: no issues.

- [ ] **Step 7: Verify web build**

Run: `flutter build web --release`
Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_result_screen.dart \
        test/features/listening/presentation/screens/dictation_result_screen_test.dart
git commit -m "feat(listening-seek): show Số lần tua stat on DictationResultScreen"
```

---

### Task 4: Nghe hiểu — global word-index mapping + `ListeningComprehensionNotifier.seekToWord()`

**Files:**
- Modify: `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
- Test: `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`

**Interfaces:**
- Consumes: existing `ListeningSessionState`/`ListeningComprehensionNotifier` (this file), `ListeningPassage`/`ListeningTurn` (`lib/features/listening/domain/entities/listening_passage.dart`), `TtsService.speak(String, Language, {double pitch})`/`.stop()`.
- Produces: top-level function `int totalWordsOf(ListeningPassage passage)` (public — Task 5's screen also calls this to size its slider); new method `Future<void> ListeningComprehensionNotifier.seekToWord(int globalWordIndex)`.

- [ ] **Step 1: Write the failing tests**

Open `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`. Add these tests at the end of `main()`, right before the final closing `}`:

```dart

  test('totalWordsOf sums word counts across all turns', () async {
    await generateFixed();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    // Turn 0 "Hello, can I help you?" = 5 words; turn 1 "Yes, I need a room for
    // tonight." = 7 words; turn 2 "Sure, for how many guests?" = 5 words.
    expect(totalWordsOf(state.passage), 17);
  });

  test('seekToWord within the first turn speaks from that word to the end of the turn', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(2); // turn 0, word index 2: "I"

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
    verify(() => mockTts.speak('I help you?', Language.english, pitch: 1.0)).called(1);
  });

  test(
      "seekToWord crossing into a later turn switches currentTurnIndex and uses that turn's pitch",
      () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(5); // turn 0 has 5 words (indices 0-4), so this is turn 1 word 0

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3))
        .called(1);
  });

  test('seekToWord with an out-of-range index is a no-op', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(-1);
    await notifier.seekToWord(17); // total is 17, valid indices are 0-16

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch')));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: FAIL — `totalWordsOf`/`seekToWord` are not defined.

- [ ] **Step 3: Add the word-index helpers and `seekToWord`**

Open `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`. Find this exact block:

```dart
@riverpod
class ListeningComprehensionNotifier extends _$ListeningComprehensionNotifier {
```

Replace it with:

```dart
List<String> _splitWords(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// Total word count across every turn of [passage], in order — the range
/// the Nghe hiểu seek slider spans (word positions are counted across all
/// turns, not per turn).
int totalWordsOf(ListeningPassage passage) =>
    passage.turns.fold(0, (sum, t) => sum + _splitWords(t.text).length);

/// Maps a 0-based [globalWordIndex] (counting words across all turns of
/// [passage] in order) to the turn it falls in and its word index within
/// that turn's own text.
({int turnIndex, int wordIndex}) _resolveGlobalWordIndex(
  ListeningPassage passage,
  int globalWordIndex,
) {
  var remaining = globalWordIndex;
  for (var t = 0; t < passage.turns.length; t++) {
    final wordCount = _splitWords(passage.turns[t].text).length;
    if (remaining < wordCount) {
      return (turnIndex: t, wordIndex: remaining);
    }
    remaining -= wordCount;
  }
  final lastTurn = passage.turns.length - 1;
  return (
    turnIndex: lastTurn,
    wordIndex: _splitWords(passage.turns[lastTurn].text).length - 1,
  );
}

@riverpod
class ListeningComprehensionNotifier extends _$ListeningComprehensionNotifier {
```

Find this exact block:

```dart
  Future<void> stopPlayback() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(ttsServiceProvider).stop();
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false, playToken: latest.playToken + 1));
  }
```

Replace it with:

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
```

- [ ] **Step 4: Run the test file to verify everything passes**

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: PASS — all tests (existing + new).

- [ ] **Step 5: Run full test suite and analyze**

Run: `flutter test`
Expected: PASS.

Run: `flutter analyze lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/listening/presentation/providers/listening_comprehension_provider.dart \
        test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
git commit -m "feat(listening-seek): add totalWordsOf() and seekToWord() to ListeningComprehensionNotifier"
```

---

### Task 5: Nghe hiểu — seek slider UI on `ComprehensionSessionScreen`

**Files:**
- Modify: `lib/features/listening/presentation/screens/comprehension_session_screen.dart`
- Test: `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`

**Interfaces:**
- Consumes: `ListeningComprehensionNotifier.seekToWord(int globalWordIndex)`, `totalWordsOf(ListeningPassage)` (Task 4).
- Produces: new private widget `_SeekSlider` in this file (not consumed elsewhere) — last task touching Nghe hiểu code.

- [ ] **Step 1: Write the failing tests**

Open `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`. Add these tests at the end of `main()`, right before the final closing `}`:

```dart

  group('seek slider', () {
    testWidgets('shows a seek slider spanning the whole passage', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('dragging shows a turn+word preview label', (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // _testPassage turn 0 "Can I help you?" = 4 words; global word 1 = word
      // index 1 of turn 0 ("I").
      slider.onChanged?.call(1.0);
      await tester.pumpAndSettle();

      expect(find.text('Lượt 1/3 · Từ 2/4'), findsOneWidget);
    });

    testWidgets('releasing the slider past the first turn switches to the resolved turn',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session()));
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider));
      // turn 0 has 4 words (indices 0-3), so global word 5 is turn 1 word 1.
      slider.onChangeEnd?.call(5.0);
      await tester.pumpAndSettle();

      expect(find.textContaining('Lượt 2/3'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
Expected: FAIL — no `Slider` widget exists yet.

- [ ] **Step 3: Add the `_SeekSlider` widget and wire it into `_SessionScaffold`**

Open `lib/features/listening/presentation/screens/comprehension_session_screen.dart`. Find this exact block:

```dart
                    Text(
                      'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}'
                      '${turn.speaker != null ? ' — Người nói ${turn.speaker}' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
```

Replace it with:

```dart
                    Text(
                      'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}'
                      '${turn.speaker != null ? ' — Người nói ${turn.speaker}' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _SeekSlider(passage: session.passage, onSeek: notifier.seekToWord),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
```

Now add the new widget class at the end of the file, after the closing brace of `_QuestionCard`:

```dart

class _SeekSlider extends StatefulWidget {
  const _SeekSlider({required this.passage, required this.onSeek});
  final ListeningPassage passage;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  int? _restWordIndex;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final total = totalWordsOf(widget.passage);
    if (total <= 1) return const SizedBox.shrink();
    final value = (_restWordIndex ?? 0).toDouble();
    return Column(
      children: [
        if (_isDragging && _restWordIndex != null) Text(_previewLabel(_restWordIndex!)),
        Slider(
          value: value,
          min: 0,
          max: (total - 1).toDouble(),
          divisions: total - 1,
          onChanged: (v) => setState(() {
            _isDragging = true;
            _restWordIndex = v.round();
          }),
          onChangeEnd: (v) {
            setState(() {
              _isDragging = false;
              _restWordIndex = v.round();
            });
            widget.onSeek(v.round());
          },
        ),
      ],
    );
  }

  String _previewLabel(int globalWordIndex) {
    var remaining = globalWordIndex;
    for (var t = 0; t < widget.passage.turns.length; t++) {
      final wordCount = widget.passage.turns[t].text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (remaining < wordCount) {
        return 'Lượt ${t + 1}/${widget.passage.turns.length} · Từ ${remaining + 1}/$wordCount';
      }
      remaining -= wordCount;
    }
    return '';
  }
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
Expected: PASS — all tests (existing + new `seek slider` group).

- [ ] **Step 5: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Analyze**

Run: `flutter analyze lib/features/listening/presentation/screens/comprehension_session_screen.dart`
Expected: no issues.

- [ ] **Step 7: Verify web build**

Run: `flutter build web --release`
Expected: builds successfully.

- [ ] **Step 8: Commit**

```bash
git add lib/features/listening/presentation/screens/comprehension_session_screen.dart \
        test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(listening-seek): add seek slider to ComprehensionSessionScreen"
```

---

### Task 6: Update README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: nothing (docs-only task, depends on Tasks 1-5 being complete so the final test count is accurate).
- Produces: nothing — last task in the plan.

- [ ] **Step 1: Confirm the final test count**

Run: `flutter test 2>&1 | tail -5`

This repo's actual test count is **257** before this feature (after the Plan 10 final-review fix) — but README's "Hiện tại" line still says **256** (it was never bumped after that fix landed, a pre-existing 1-test staleness unrelated to this plan). Expect roughly **+16 to +20** new tests from Tasks 1-5 (seekPenaltyFraction: 3, finalScore: 1, seekTo notifier: 3, Nghe chép slider widget: 4, Nghe chép result stat: 1, totalWordsOf/seekToWord: 4, Nghe hiểu slider widget: 3) on top of the true 257 baseline — use the **actual** printed number from this step, not this estimate, and not the stale 256 in README.

- [ ] **Step 2: Update the Nghe chép bullet**

Find this exact block:

```markdown
- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - **3 mức độ** (chọn mỗi phiên luyện tập, mặc định Khó):
    - **Dễ** — điền 2 ô trống 1-từ rời rạc, phần còn lại của câu hiện sẵn (dạng điền khuyết)
    - **Trung bình** — điền 1 cụm từ liên tục (~35% số từ của câu), phần còn lại hiện sẵn
    - **Khó** — chép lại toàn bộ câu từ trí nhớ, không hiện gì (mù hoàn toàn)
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm — áp dụng cho cả 3 mức độ
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2). Dễ/Trung bình chấm theo số ô điền đúng (không phân biệt hoa/thường); Khó chấm theo từng ký tự — cùng công thức trừ điểm và cùng ngưỡng quy đổi SM-2
  - Màn hình kết quả: điểm số, số lần nghe lại, thời gian; Khó hiện phần gõ tô màu đối chiếu ký tự, Dễ/Trung bình hiện lại đúng đoạn điền khuyết với từng ô tô xanh (đúng)/đỏ kèm đáp án đúng (sai)
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
```

Replace it with:

```markdown
- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - **3 mức độ** (chọn mỗi phiên luyện tập, mặc định Khó):
    - **Dễ** — điền 2 ô trống 1-từ rời rạc, phần còn lại của câu hiện sẵn (dạng điền khuyết)
    - **Trung bình** — điền 1 cụm từ liên tục (~35% số từ của câu), phần còn lại hiện sẵn
    - **Khó** — chép lại toàn bộ câu từ trí nhớ, không hiện gì (mù hoàn toàn)
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm — áp dụng cho cả 3 mức độ
  - **Thanh trượt tua theo từ** (không có audio file để tua theo thời gian — TTS luôn đọc từ điểm tua tới hết câu): kéo thả trừ 1-5% tùy tỷ lệ câu sẽ được nghe lại (kéo về gần đầu câu bị trừ nhiều hơn kéo về gần cuối câu, chống việc dùng tua thay thế Nghe lại với giá rẻ); lần nghe đầu tiên của phiên luôn miễn phí dù qua nút Phát hay slider
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2). Dễ/Trung bình chấm theo số ô điền đúng (không phân biệt hoa/thường); Khó chấm theo từng ký tự — cùng công thức trừ điểm và cùng ngưỡng quy đổi SM-2
  - Màn hình kết quả: điểm số, số lần nghe lại, **số lần tua** (kèm % bị trừ), thời gian; Khó hiện phần gõ tô màu đối chiếu ký tự, Dễ/Trung bình hiện lại đúng đoạn điền khuyết với từng ô tô xanh (đúng)/đỏ kèm đáp án đúng (sai)
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
```

- [ ] **Step 3: Update the Nghe hiểu bullet**

Find this exact block:

```markdown
- **Nghe hiểu (TOEIC-style comprehension)** — AI tạo ngẫu nhiên một hội thoại 2 người (nhãn "A"/"B", đổi cao độ giọng để phân biệt) hoặc một bài nói 1 người, cộng đúng 3 câu hỏi trắc nghiệm 4 đáp án (ý chính/chi tiết/ý ngụ ý — không điền từ), bằng ngôn ngữ mục tiêu giống TOEIC thật
  - Điều khiển nghe theo từng lượt: ⏮ lượt trước / ▶️⏸ phát-dừng / ⏭ lượt sau / 🔁 phát lại từ đầu — không có thanh tua liên tục
  - Nghe lại/tua thoải mái, **không trừ điểm** (khác Nghe chép) — mục tiêu là luyện hiểu, không phải áp lực thi 1 lần
```

Replace it with:

```markdown
- **Nghe hiểu (TOEIC-style comprehension)** — AI tạo ngẫu nhiên một hội thoại 2 người (nhãn "A"/"B", đổi cao độ giọng để phân biệt) hoặc một bài nói 1 người, cộng đúng 3 câu hỏi trắc nghiệm 4 đáp án (ý chính/chi tiết/ý ngụ ý — không điền từ), bằng ngôn ngữ mục tiêu giống TOEIC thật
  - Điều khiển nghe theo từng lượt: ⏮ lượt trước / ▶️⏸ phát-dừng / ⏭ lượt sau / 🔁 phát lại từ đầu
  - **Thanh trượt tua theo từ, xuyên suốt toàn bộ bài** (nhiều lượt thoại nối lại) — kéo qua ranh giới lượt tự chuyển lượt + đổi cao độ giọng tương ứng; bổ sung cho các nút điều khiển trên, không thay thế
  - Nghe lại/tua thoải mái, **không trừ điểm** (khác Nghe chép) — mục tiêu là luyện hiểu, không phải áp lực thi 1 lần
```

- [ ] **Step 4: Update the test count**

Find this exact line:

```markdown
Hiện tại: **256 tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

Replace `256` with the actual number from Step 1's `flutter test` output:

```markdown
Hiện tại: **<ACTUAL_COUNT> tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

- [ ] **Step 5: Verify the edits landed correctly**

Run: `grep -n "Thanh trượt tua\|Hiện tại: \*\*" README.md`
Expected: matches for both new "Thanh trượt tua" bullets and the updated test count.

- [ ] **Step 6: Read the diff once, end to end**

Run: `git diff README.md`
Expected: reads coherently — no broken list nesting, no duplicated bullets.

- [ ] **Step 7: Sanity-check the repo still analyzes/tests cleanly**

Run: `flutter analyze`
Run: `flutter test`
Expected: both succeed.

- [ ] **Step 8: Commit**

```bash
git add README.md
git commit -m "docs: document audio seek slider for Nghe chép & Nghe hiểu"
```
