# Final-review round — fix report

Date: 2026-08-29
Branch: master (AI settings Firestore sync work already merged in prior commits; this is one more fix commit on top)

## Summary

Fixed two classes of Firestore-sync bugs found in the final whole-branch review, plus restored test coverage silently dropped by an earlier task.

## Fix 1 — `bootstrapSync` unreachable for already-signed-in users

**File:** `lib/core/router/app_router.dart`

`authRedirectDecision` sends an already-authenticated user straight from `/splash` to `/` — `/sign-in` (the only place that called `bootstrapSync`) is never visited again once a user has signed in once. This meant the one-time legacy-plaintext-key migration and any pull-sync of settings changed on web never ran again after the very first sign-in.

Changes:
- Added `package:flutter_riverpod/flutter_riverpod.dart` and a relative import of `user_settings_provider.dart` (`dart:async` was already imported, so it was left as-is rather than duplicated).
- Replaced the plain `Scaffold`-with-spinner `/splash` route builder with a new `_SplashScreen` (a `ConsumerStatefulWidget`).
- `_SplashScreenState.initState()` reads `FirebaseAuth.instance.currentUser?.uid`; if non-null, fires `ref.read(aiSettingsSyncServiceProvider).bootstrapSync(uid, ref.read(userSettingsNotifierProvider.notifier))` unawaited (fire-and-forget — must not block the redirect, unlike `sign_in_screen.dart`'s blocking call which has its own documented reason to wait).

`test/core/router/auth_redirect_test.dart` only exercises the pure `authRedirectDecision` function (no widget tree), so it needed no changes and still passes unchanged (8/8).

## Fix 2 — `pushProviderSettings` could blank a real remote API key

**File:** `lib/core/services/ai_settings_sync_service.dart`

`pushProviderSettings` always wrote `'apiKeyCiphertext': entry.value.apiKeyCiphertext`, including when it was `null` (e.g. user only touched the Model picker on this device). Since Firestore's `merge: true` deep-merges nested maps, an explicit `null` overwrote a real ciphertext already saved from another device/platform — the write-side twin of the already-fixed read-side bug in `bootstrapSync`'s remote-wins branch.

Fix: omit the `apiKeyCiphertext` key entirely from the written map when the local value is `null` or empty, instead of writing an explicit `null`.

### TDD evidence

Added test `'a local null apiKeyCiphertext does not clobber a real remote ciphertext'` to the `pushProviderSettings` group in `test/core/services/ai_settings_sync_service_test.dart`.

**Deviation from the literal test snippet supplied in the task:** the snippet constructed `AiSettingsSyncService(firestore: firestore)` with no `encryptor:` argument. `AiSettingsSyncService`'s constructor eagerly builds `ApiKeyEncryptor()` in its initializer list when `encryptor` is omitted, which touches real `FirebaseFunctions`/`Firebase.app()` — uninitialized in a plain unit test — so the test errored with `[core/no-app] No Firebase App '[DEFAULT]' has been created` rather than failing on the actual assertion. Every other test in this file passes `encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {}))` explicitly for this reason, so the same argument was added here (pure test scaffolding — no change to the fix logic or the assertions).

**RED (old code, before the fix), with the `encryptor:` argument added:**
```
00:00 +7 -1: AiSettingsSyncService.pushProviderSettings a local null apiKeyCiphertext does not clobber a real remote ciphertext [E]
  Expected: 'remote-real-cipher'
    Actual: <null>
     Which: not an <Instance of 'String'>

  package:matcher                                              expect
  package:flutter_test/src/widget_tester.dart 473:18           expect
  test\core\services\ai_settings_sync_service_test.dart 248:7  main.<fn>.<fn>

00:00 +7 -1: Some tests failed.
```
Confirms the bug: the remote ciphertext was overwritten to `null` by the push.

**GREEN (after applying the fix):**
```
00:00 +8: All tests passed!
```
All 8 tests in the file (5 `bootstrapSync` + 3 `pushProviderSettings`, now including the new one) pass.

## Fix 3 — `currentUidProvider` cached the uid across sign-out/sign-in

**File:** `lib/features/dictionary/presentation/providers/user_settings_provider.dart`

`currentUidProvider` was `@Riverpod(keepAlive: true)`, so it cached the uid from its first read forever. After sign-out and sign-in as a different account in the same app session, pushes would keep going to the previous user's Firestore document.

Fix: changed the annotation to plain `@riverpod` (auto-dispose) with an updated doc comment explaining why. Ran `dart run build_runner build --delete-conflicting-outputs` to regenerate `user_settings_provider.g.dart`; confirmed the regenerated provider is now `AutoDisposeProvider<String?>` (was `Provider<String?>`).

No new test added, per the task's own reasoning: this codebase has no fake/mock seam for real `FirebaseAuth`'s sign-out/sign-in-as-different-account behavior, so it's verified by Riverpod's documented auto-dispose semantics rather than a runtime test. Confirmed the existing tests using `currentUidProvider.overrideWithValue(...)` in `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` and `test/core/services/ai_settings_sync_service_test.dart` still pass unchanged (`overrideWithValue` behavior is unaffected by the `keepAlive` annotation).

## Fix 4 — Restored dropped `ai_provider_test.dart` coverage

**File:** `test/features/dictionary/domain/entities/ai_provider_test.dart`

A prior task's brief incorrectly claimed this file was new and supplied a 5-test replacement, silently dropping 12 pre-existing tests (labels, baseUrls, defaultModels, modelPresets, an invariant check). Replaced the file's contents verbatim with the full 17-test version supplied in this task's brief (5 groups: labels, baseUrl, defaultModel, modelPresets, cloudId, aiProviderFromCloudId).

## Verification

### `flutter analyze`
21 issues found — all are the pre-existing `RadioListTile`/`groupValue`/`onChanged` deprecation infos (unrelated to this change, already present before this branch). No new errors or warnings.

### Targeted test run
```
flutter test test/core/router/auth_redirect_test.dart test/core/services/ai_settings_sync_service_test.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart test/features/dictionary/domain/entities/ai_provider_test.dart
```
Result: `+55: All tests passed!` (8 auth_redirect + 8 ai_settings_sync_service + 22 user_settings_notifier + 17 ai_provider = 55 total, matching the expected counts: 8 sync-service tests, 17 ai_provider tests).

### Full suite
```
flutter test
```
Result: `+533: All tests passed!` — no regressions elsewhere.

## Files changed
- `lib/core/router/app_router.dart`
- `lib/core/services/ai_settings_sync_service.dart`
- `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- `lib/features/dictionary/presentation/providers/user_settings_provider.g.dart` (regenerated via build_runner)
- `test/core/services/ai_settings_sync_service_test.dart`
- `test/features/dictionary/domain/entities/ai_provider_test.dart`

## Concerns

- The one deviation noted above (adding the `encryptor:` argument to the new Fix-2 test) was necessary for the test to exercise the actual bug rather than erroring on an unrelated Firebase-init issue; the assertions and fix logic are otherwise exactly as specified.
- No other drift from the task's exact code blocks was found — all files matched the pre-fix state described in the task before edits were applied.

## Fix Round 2 — Flutter Web auth-resolution race (Firebase auth currentUser sync issue)

**File:** `lib/core/router/app_router.dart`

**Problem:** On Flutter Web, `FirebaseAuth.instance.currentUser` stays `null` until the JS Firebase SDK finishes restoring the session from IndexedDB — which happens AFTER the splash screen's `initState()` runs. The original Fix 1 read `currentUser` synchronously in `_SplashScreenState.initState()`, which meant returning Flutter Web users saw `null` and never got `bootstrapSync` called. Mobile platforms seed `currentUser` synchronously before `runApp`, so they were unaffected, but Flutter Web remains a live deployed surface (`build/web`, per CLAUDE.md) until an explicit domain-cutover step — the bug needed fixing now.

**Changes:**
- Modified `_SplashScreenState.initState()` to capture the Riverpod provider refs synchronously (before any `await`, so `ref` stays valid), then call an async closure that:
  - Falls back to `FirebaseAuth.instance.authStateChanges().first` when `currentUser` is still `null` — waiting for the JS SDK to finish restoring the session.
  - Calls `bootstrapSync` with the resolved user's uid once available.
- Updated the `_SplashScreen` class doc comment to explain the new behavior: waits for FirebaseAuth resolution rather than assuming a synchronous `null` means signed-out.

**Tests:**
- `test/core/router/auth_redirect_test.dart` (8/8 pass): Tests only the pure `authRedirectDecision` function, unaffected by this widget timing change — still passes unchanged.
- Full suite: `flutter test` (533 tests pass) — no regressions.

**Analysis output:**
```
flutter analyze: 21 issues — all pre-existing RadioListTile deprecation infos, no new errors/warnings.

flutter test test/core/router/auth_redirect_test.dart
00:00 +0: loading D:/Flutter/lexi-core/test/core/router/auth_redirect_test.dart
[8 tests listed]
00:00 +8: All tests passed!

flutter test (full suite)
[533 tests run]
01:15 +533: All tests passed!
```

No new widget-level tests added — the async timing of `currentUser` vs `authStateChanges()` resolution is not practically testable without a fake FirebaseAuth seam, which this codebase lacks.
