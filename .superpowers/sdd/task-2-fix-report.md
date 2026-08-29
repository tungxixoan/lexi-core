# Task 2 review-fix report — CloudTtsService lazy init, dispose, unused imports

Date: 2026-08-30
Work dir: d:\Flutter\lexi-core

## Summary

All three review findings fixed, verified RED before / GREEN after on the two
affected test files, `flutter analyze` returns exactly 21 pre-existing infos
(zero warnings/errors), and the full test suite passes (555/555). One
additional consequence of Fix 1 (adding `dispose()` to the `TtsService`
interface) was that two pre-existing test-only fake implementations of
`TtsService` (`_FakeTtsService` in `dictation_session_screen_test.dart` and
`comprehension_session_screen_test.dart`) stopped compiling because they
didn't implement the new abstract member. This was not called out in the
task brief but is a direct, mechanical consequence of Fix 1's interface
change, so I fixed it (added a trivial `dispose()` override to each) rather
than leave `flutter analyze` broken.

## Fix 1 — Lazy-construct CloudTtsService's dependencies + add disposal

File: `lib/services/tts_service.dart`

The file on disk matched the task brief's description almost exactly, with
one difference: the constructor already existed with parameters `caller`
and `player`, but eagerly assigned `_caller = caller ?? FirebaseCloudFunctionCaller()`
and `_player = player ?? AudioPlayer()` directly in the initializer list —
this is exactly the eager-construction bug described in Finding 1.

Applied the prescribed transformation:
- Added `Future<void> dispose();` to the abstract `TtsService` class.
- Replaced the eager `_caller`/`_player` fields with `_providedCaller` /
  `_providedPlayer` (nullable, set once from constructor args) and
  `_resolvedCaller` / `_resolvedPlayer` (nullable, lazily populated), plus
  `_caller` / `_player` getters that construct `FirebaseCloudFunctionCaller()`
  / `AudioPlayer()` only on first real access.
- Added `Future<void> dispose() async { await _resolvedPlayer?.dispose(); }`
  override — disposes the player only if one was ever actually created
  (never touches Firebase/platform channels if `_resolvedPlayer` is still
  null, e.g. a test that never calls pronounce/synthesize/stop).
- Kept the existing `_playAndAwaitCompletion` doc comment wording as-is
  (already present, matching the brief's note that existing wording should
  be preserved).
- No other imports or the `PronunciationTier` enum were touched.

## Fix 2 — Wire disposal into app_providers.dart

File: `lib/core/di/app_providers.dart`

Matched the brief exactly. Replaced:
```dart
@riverpod
TtsService ttsService(TtsServiceRef ref) => CloudTtsService();
```
with:
```dart
@riverpod
TtsService ttsService(TtsServiceRef ref) {
  final service = CloudTtsService();
  ref.onDispose(() => service.dispose());
  return service;
}
```

## Fix 3 — Remove 3 unused language.dart imports

Confirmed via grep that all 3 files imported `language.dart` (or its
relative-path equivalent) and used `Language` only as a type / via
`.ttsCloudCode`, which is a plain enum member (no extension import needed).
Removed the import line from all three, leaving every other import
(including `tts_service.dart` for `PronunciationTier`) untouched:
- `lib/features/dictionary/presentation/widgets/word_result_widget.dart`
  (removed `import '../../domain/entities/language.dart';`)
- `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`
  (removed `import '../../domain/entities/language.dart';`)
- `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`
  (removed `import '../../../dictionary/domain/entities/language.dart';`)

## Fix 1 side effect — two test fakes needed a dispose() override

`flutter analyze` after Fixes 1–3 surfaced 2 new errors (not present in the
21-issue baseline):

```
error - Missing concrete implementation of 'TtsService.dispose' - test\features\listening\presentation\screens\comprehension_session_screen_test.dart:14:7 - non_abstract_class_inherits_abstract_member
error - Missing concrete implementation of 'TtsService.dispose' - test\features\listening\presentation\screens\dictation_session_screen_test.dart:16:7 - non_abstract_class_inherits_abstract_member
```

Both files define a `class _FakeTtsService implements TtsService { ... }`
with hand-written overrides for `pronounce`/`synthesize`/`stop` but no
`dispose`. Added:
```dart
@override
Future<void> dispose() async {}
```
to each fake, immediately after its existing `stop()` override. (The other
two `TtsService` test doubles, `MockTtsService extends Mock implements
TtsService` in `dictation_practice_provider_test.dart` and
`listening_comprehension_provider_test.dart`, use mocktail's `Mock` base
class, which supplies `noSuchMethod`-based stubs for any unimplemented
member automatically — those needed no change.)

## Verification — RED (before the fix, on the as-committed code)

Command:
```
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart test/features/listening/presentation/screens/comprehension_home_screen_test.dart
```

Result: **`00:02 +3 -10: Some tests failed.`** (3 passed, 10 failed) —
matches the review's claim exactly. Sample failure trace confirming the
`[core/no-app]` root cause (16 occurrences of `[core/no-app]` across the
run):

```
The following FirebaseException was thrown building DictationHomeScreen(dirty, dependencies:
[UncontrolledProviderScope], state: _DictationHomeScreenState#6772d):
[core/no-app] No Firebase App '[DEFAULT]' has been created - call Firebase.initializeApp()
```

The final assertion failure (one of the 10):
```
00:02 +3 -10: D:/Flutter/lexi-core/test/features/listening/presentation/screens/dictation_home_screen_test.dart: shows unsupported-language message when target language has no Piper voice [E]
  Test failed. See exception logs above.
  The test description was: shows unsupported-language message when target language has no Piper voice
```

## Verification — GREEN (after Fixes 1–3 + the test-fake dispose() fix)

Same command, same two files:

```
00:01 +13: All tests passed!
```

All 13 tests (3 that passed before + the 10 that were failing) now pass,
including both of the new "shows unsupported-language message" tests.

## Verification — flutter analyze

First run (Fixes 1–3 applied, before fixing the test fakes) surfaced the 2
new errors documented above (23 issues total: 21 pre-existing infos + 2 new
errors). After adding `dispose()` to both `_FakeTtsService` classes,
re-running:

```
Analyzing lexi-core...
...
21 issues found. (ran in 13.3s)
```

All 21 remaining issues are `info - ... deprecated_member_use` for
`RadioListTile`'s `groupValue`/`onChanged` (the pre-existing, expected
baseline) across:
`lib/core/widgets/selection_sheets.dart`,
`lib/features/listening/presentation/screens/comprehension_session_screen.dart`,
`lib/features/reading/presentation/screens/part5_session_screen.dart`,
`lib/features/reading/presentation/screens/part6_session_screen.dart`,
`lib/features/reading/presentation/screens/part7_session_screen.dart`,
`lib/features/settings/presentation/screens/settings_screen.dart`,
`test/features/reading/presentation/screens/part7_session_screen_test.dart`.
Zero warnings, zero errors.

## Verification — full test suite

Command: `flutter test`

Final line:
```
00:40 +555: All tests passed!
```

555/555 tests passed, 0 failures.

## Files changed

- `lib/services/tts_service.dart` — lazy caller/player construction +
  `dispose()`
- `lib/core/di/app_providers.dart` — `ttsServiceProvider` now calls
  `ref.onDispose(() => service.dispose())`
- `lib/features/dictionary/presentation/widgets/word_result_widget.dart` —
  removed unused `language.dart` import
- `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`
  — removed unused `language.dart` import
- `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart` —
  removed unused `language.dart` import
- `test/features/listening/presentation/screens/dictation_session_screen_test.dart`
  — added `dispose()` override to `_FakeTtsService` (needed to keep
  `flutter analyze`/compilation green after Fix 1 added the abstract member;
  not part of the original 3 findings but a direct consequence of fixing
  Finding 1)
- `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
  — same, added `dispose()` override to `_FakeTtsService`
- `.superpowers/sdd/task-2-fix-report.md` — this report

## Remaining concerns

- None outstanding against the 3 findings — all reproduced as RED, fixed,
  and verified GREEN, with the full suite green and analyze at the expected
  exact baseline.
- The two test-fake `dispose()` additions were not in the original task
  brief's file list; flagging this explicitly per the instructions ("if
  anything doesn't apply cleanly... note what you found different") even
  though the change itself is a 2-line, no-behavior-risk addition needed
  to keep the build/analyze compiling after Fix 1's interface change.
