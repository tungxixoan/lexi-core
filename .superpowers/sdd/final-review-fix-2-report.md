# Final Review Fix Round 2 — Report

Date: 2026-08-30
Scope: Findings 1-7 from the final whole-branch code review (TTS keepAlive bug, mimeType, rate reset, dead code, doc drift).

## Finding 1 (CRITICAL) — `ttsServiceProvider` auto-dispose bug

**File:** `lib/core/di/app_providers.dart`

Changed:
```dart
@riverpod
TtsService ttsService(TtsServiceRef ref) {
```
to:
```dart
@Riverpod(keepAlive: true)
TtsService ttsService(TtsServiceRef ref) {
```

Ran `dart run build_runner build --delete-conflicting-outputs` to regenerate `lib/core/di/app_providers.g.dart`. This also caused two unrelated `.g.dart` files' provider hashes to change as a side effect of the full rebuild (see "Concerns" below):
- `lib/features/listening/presentation/providers/dictation_practice_provider.g.dart`
- `lib/features/listening/presentation/providers/listening_comprehension_provider.g.dart`

Added the regression test group `ttsServiceProvider` to `test/core/di/app_providers_test.dart`, verbatim as specified, right after the existing `httpClientProvider` group (left unchanged).

### RED/GREEN evidence (real, both observed)

**RED** — test added, provider still `@riverpod` (auto-dispose), ran `flutter test test/core/di/app_providers_test.dart`:
```
00:00 +0: loading D:/Flutter/lexi-core/test/core/di/app_providers_test.dart
00:00 +0: httpClientProvider stays alive (same instance) across an async gap with no active watcher
00:00 +1: ttsServiceProvider stays alive (same instance) across an async gap with no active watcher
00:00 +1 -1: ttsServiceProvider stays alive (same instance) across an async gap with no active watcher [E]
  Expected: true
    Actual: <false>
  ttsServiceProvider was disposed (and its AudioPlayer torn down) across the async gap even though nothing watched it.

  package:matcher                                     expect
  package:flutter_test/src/widget_tester.dart 473:18  expect
  test\core\di\app_providers_test.dart 67:7           main.<fn>.<fn>

00:00 +1 -1: Some tests failed.
```

**GREEN** — after applying `@Riverpod(keepAlive: true)` and regenerating codegen, re-ran the same command:
```
00:00 +0: loading D:/Flutter/lexi-core/test/core/di/app_providers_test.dart
00:00 +0: httpClientProvider stays alive (same instance) across an async gap with no active watcher
00:00 +1: ttsServiceProvider stays alive (same instance) across an async gap with no active watcher
00:00 +2: All tests passed!
```

## Finding 2 (Important) — missing `mimeType` on `BytesSource`

**File:** `lib/services/tts_service.dart`, in `synthesize()`. Changed:
```dart
await _playAndAwaitCompletion(BytesSource(base64Decode(audioBase64)));
```
to:
```dart
await _playAndAwaitCompletion(
  BytesSource(base64Decode(audioBase64), mimeType: 'audio/wav'),
);
```

## Finding 3 (Important) — `stop()` no try/catch + forces new player construction

**File:** `lib/services/tts_service.dart`. Added the `_existingPlayer` getter directly below `_player`:
```dart
AudioPlayer? get _existingPlayer => _providedPlayer ?? _resolvedPlayer;
```
and replaced `stop()`:
```dart
@override
Future<void> stop() async {
  try {
    await _existingPlayer?.stop();
  } catch (_) {
    // Best-effort — see pronounce()'s comment.
  }
}
```

## Finding 4 (Minor) — `pronounce()` never resets playback rate

**File:** `lib/services/tts_service.dart`, in `pronounce()`. Added `await _player.setPlaybackRate(1.0);` right before `_playAndAwaitCompletion(UrlSource(url))`.

## Finding 5 (Minor) — dead `Language.ttsLocale` getter

**File:** `lib/features/dictionary/domain/entities/language.dart`. Ran `grep -rn "ttsLocale" lib/ test/ apps/web/` first (widened to whole repo) — confirmed only historical doc/plan files under `docs/superpowers/{specs,plans}/**` reference it besides the declaration itself; no `lib/`, `test/`, or `apps/web/` reference outside the getter's own file. Deleted the getter entirely (5-case switch + trailing blank line), leaving exactly one blank line between `code` and `label` getters.

## Finding 6 (Important) — missing test coverage for lazy construction / dispose

**File:** `test/services/tts_service_test.dart`. Appended the `CloudTtsService construction and disposal` group verbatim (4 tests) before the final closing `}`. The pre-existing `CloudTtsService.stop` group's `'delegates to AudioPlayer.stop()'` test was left untouched per instructions (duplicate-in-substance test, different group, both kept). No `MissingStubError` was hit for `mockPlayer.dispose()` under `verifyNever` — no additional stub was needed in `setUp()`.

## Finding 7 (Important, docs) — README TTS drift

**File:** `README.md`. Applied all four replacements verbatim:
1. Luyện nghe hub description (flutter_tts → Piper Cloud Function wording + VI/EN-only caveat).
2. Tech-stack table TTS row (flutter_tts → Piper + audioplayers).
3. "Ngôn ngữ được hỗ trợ" table — TTS column changed from ✅ to — for Chinese/Korean/Japanese.
4. Appended the new caveat line about TTS only working for English/Vietnamese, right after the existing Free Dictionary API caveat line.

## Verification

### `flutter analyze` — exact result
```
21 issues found. (ran in 56.4s)
```
All 21 are the pre-existing `RadioListTile` `groupValue`/`onChanged` deprecation infos (in `selection_sheets.dart`, `comprehension_session_screen.dart`, `part5/6/7_session_screen.dart`, `settings_screen.dart`, `part7_session_screen_test.dart`) — zero warnings, zero errors, matching the expected count.

### Targeted tests — exact result
`flutter test test/core/di/app_providers_test.dart test/services/tts_service_test.dart`:
```
00:00 +18: All tests passed!
```
(2 tests in `app_providers_test.dart`, 16 in `tts_service_test.dart` — 4 more than the pre-existing 12, matching the expected "4 more than before".)

### Full suite — exact final summary line
`flutter test`:
```
00:39 +560: All tests passed!
```

## Files changed
- `lib/core/di/app_providers.dart`
- `lib/core/di/app_providers.g.dart`
- `lib/services/tts_service.dart`
- `lib/features/dictionary/domain/entities/language.dart`
- `test/core/di/app_providers_test.dart`
- `test/services/tts_service_test.dart`
- `README.md`
- `.superpowers/sdd/final-review-fix-2-report.md` (this file)

## Concerns

- Regenerating codegen via `dart run build_runner build --delete-conflicting-outputs` also touched two files not in the explicit stage list — `lib/features/listening/presentation/providers/dictation_practice_provider.g.dart` and `lib/features/listening/presentation/providers/listening_comprehension_provider.g.dart` — each with a one-line provider-hash change only (no behavioral diff; these providers were already `@riverpod`-generated and their hash simply shifted from the rebuild). Per the task's explicit stage list, these two files are **left unstaged** in the working tree rather than committed. `flutter analyze`/`flutter test` both pass with them present, so this is inert, but flagging it since the commit will not include a codegen artifact that technically changed on disk.
- A `build_runner` warning noted `SDK language version 3.11.0 is newer than analyzer language version 3.9.0` — pre-existing environment mismatch, unrelated to this change, took no action.
