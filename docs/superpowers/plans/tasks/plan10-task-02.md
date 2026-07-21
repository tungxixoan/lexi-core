# Plan 10 — Task 02: TtsService Pitch Support

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** none (can run in parallel with Task 01)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Adds an optional `pitch` parameter to `TtsService.speak()` (default `1.0`) so the comprehension feature (Tasks 04–06) can make conversation speakers "A" and "B" sound distinguishable. Also configures `FlutterTts.awaitSpeakCompletion(true)` so `speak()`'s returned `Future` resolves only once the utterance actually finishes playing (needed so the session screen can flip its play/stop button back to "play" automatically when a turn ends) — a real, previously-nonexistent guarantee, not just a signature change.

**Zero behavior change for existing callers.** `lib/features/dictionary/presentation/widgets/word_result_widget.dart` (two call sites), `sentence_result_widget.dart` (one call site), and `DictationPracticeNotifier.play()` (Plan 9) all call `speak(text, language)` with exactly two positional arguments — the new `pitch` parameter is optional and named, so none of them need to change. The `awaitSpeakCompletion` change means those callers' `speak()` calls will now resolve slightly later (when audio finishes, not when it starts) — every existing call site already treats the returned `Future` as fire-and-forget from the UI's perspective (an `onPressed` callback, never blocking a widget build), so this is safe.

## Files
- Modify: `lib/services/tts_service.dart`
- Create: `test/services/tts_service_test.dart`

## Interfaces
- Consumes: `package:flutter_tts`'s `FlutterTts` class (`setLanguage`, `setPitch`, `speak`, `stop`, `awaitSpeakCompletion` — all existing plugin methods, none added)
- Produces:
  - `TtsService.speak(String text, Language language, {double pitch = 1.0}) → Future<void>`
  - `TtsService.stop() → Future<void>` (unchanged)

## Steps

- [ ] **Step 1: Write the failing test**

Create `test/services/tts_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  late MockFlutterTts mockTts;
  late FlutterTtsService service;

  setUp(() {
    mockTts = MockFlutterTts();
    when(() => mockTts.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => mockTts.speak(any())).thenAnswer((_) async => 1);
    when(() => mockTts.stop()).thenAnswer((_) async => 1);
    service = FlutterTtsService(mockTts);
  });

  test('constructor configures awaitSpeakCompletion(true)', () {
    verify(() => mockTts.awaitSpeakCompletion(true)).called(1);
  });

  test('speak() defaults pitch to 1.0 when not provided', () async {
    await service.speak('Hello world.', Language.english);
    verify(() => mockTts.setPitch(1.0)).called(1);
    verify(() => mockTts.setLanguage(Language.english.ttsLocale)).called(1);
    verify(() => mockTts.speak('Hello world.')).called(1);
  });

  test('speak() forwards a custom pitch', () async {
    await service.speak('Hi there.', Language.english, pitch: 1.3);
    verify(() => mockTts.setPitch(1.3)).called(1);
    verify(() => mockTts.speak('Hi there.')).called(1);
  });

  test('stop() delegates to FlutterTts.stop()', () async {
    await service.stop();
    verify(() => mockTts.stop()).called(1);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/services/tts_service_test.dart
```

Expected: FAIL — `awaitSpeakCompletion` never called, `setPitch` never called, `pitch` parameter doesn't exist.

- [ ] **Step 3: Update tts_service.dart**

Replace `lib/services/tts_service.dart` with:

```dart
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

abstract class TtsService {
  Future<void> speak(String text, Language language, {double pitch = 1.0});
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  FlutterTtsService(this._tts) {
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.setPitch(pitch);
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/services/tts_service_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Run the full suite to confirm no regressions in existing callers**

```bash
flutter test
```

Expected: all tests pass — in particular, `test/features/dictionary/presentation/widgets/` (word/sentence result widgets) and `test/features/listening/presentation/providers/dictation_practice_provider_test.dart` (Plan 9's `play()` tests, which assert on `speak()` being called with two positional args) must still pass unmodified.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/services/tts_service.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/tts_service.dart test/services/tts_service_test.dart
git commit -m "feat(plan10): add pitch support to TtsService"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
