# LexiCore — Free Dictionary Abort Bug + Firebase Hosting Stale-Deploy Fix

**Date:** 2026-07-19
**Status:** Implemented
**Covers:** Two unrelated bugs found while testing the web app after the [definition/synonyms bulk-import work](2026-07-19-vocab-definition-synonyms-bulk-import-design.md): a Riverpod provider-lifecycle bug that aborted every Free Dictionary lookup, and a Firebase Hosting cache-control gap that made new deploys appear not to take effect.

---

## 1. Free Dictionary lookups aborting mid-request

### 1.1 Symptom
On web, with AI disabled, looking up any English word (e.g. "sentences") failed with:
```
ClientException: Request aborted by `abortTrigger`, uri=https://api.dictionaryapi.dev/api/v2/entries/en/sentences
```
even though the same URL returned a valid response when opened directly. AI-enabled lookups (Gemini) worked fine.

### 1.2 Root cause
`lib/core/di/app_providers.dart`'s `httpClientProvider` was plain `@riverpod` — Riverpod's `autoDispose` by default — with `ref.onDispose(client.close)`. The only consumer path (`LookupNotifier.lookup()` in `lookup_provider.dart`) reaches it through a chain of one-shot `ref.read()` calls (`ref.read(lookupUseCaseProvider)` → `dictionaryRepositoryProvider` → `freeDictionarySourceProvider` → `httpClientProvider`, all via `ref.watch` inside their own `build()`s, but never `ref.watch`-ed by a widget). With zero active listeners, Riverpod scheduled the whole chain for disposal almost immediately after construction — running `client.close()` while the `FreeDictionarySource` HTTP request was still in flight. `BrowserClient` (the web `http.Client` implementation) aborts in-flight fetches on `close()`, producing the exact error above.

This didn't affect the Gemini path because `GeminiDictionarySource`/`AiClientFactory` build their own internal `http.Client()` (`ai_client_factory.dart`), never routing through `httpClientProvider`.

### 1.3 Fix
`httpClientProvider` → `@Riverpod(keepAlive: true)`, matching the existing pattern already used for every other shared singleton in this file/codebase (`sharedPreferencesProvider`, `SyncNotifier`, `AuthNotifier`, `NotificationNotifier`, `UserSettingsNotifier`). A single `http.Client` living for the app's lifetime is the normal/expected pattern — there was never a reason for this one to be `autoDispose`.

### 1.4 Regression test
`test/core/di/app_providers_test.dart` — reads `httpClientProvider` with no listener, awaits two microtask gaps (simulating the real async gap during a network round-trip), reads it again, and asserts `identical()`. Confirmed failing (different instances → proves disposal) against the pre-fix code, passing after the `keepAlive` change.

---

## 2. Firebase Hosting serving stale builds after deploy

### 2.1 Symptom
After deploying a build containing new UI (Definition/Synonyms sections on `VocabDetailScreen`), the change was visible on `localhost:5000` (`flutter run -d chrome`) but not on `lexi-core.web.app` in a normal (non-debug) Chrome window — even after a hard refresh, and even after manually unregistering the service worker and clearing all site data via DevTools.

### 2.2 Root cause
Verified directly against the live server with `curl -D -` (not guessed from browser behavior, which was misleading — clearing site data should have ruled out a pure browser-cache explanation but didn't, which is what prompted checking the server response headers directly):

- `/index.html` correctly returned `Cache-Control: no-cache` after the first attempted fix.
- **`/` (the actual path every real navigation hits — the app uses hash-based routing, e.g. `lexi-core.web.app/#/vocab`, so the browser only ever requests the origin root at the HTTP level) still returned `Cache-Control: max-age=3600`.** Firebase Hosting header rules match the pre-rewrite request path, so a rule targeting `/index.html` never applies to a request for `/`, even though the rewrite serves `index.html`'s content for both.
- `main.dart.js` (not content-hashed by filename — it's the same name on every build) was also still on the default `max-age=3600`.

So any client that had fetched `/` or `main.dart.js` within the last hour before a new deploy would keep serving the old app for up to an hour, regardless of service worker state — this had been true since `firebase.json`'s hosting config was first written and wasn't specific to this session's deploys.

### 2.3 Fix
`firebase.json` → `hosting.headers`: `Cache-Control: no-cache` for `/`, `/index.html`, `/main.dart.js`, `/flutter_bootstrap.js`, `/flutter.js`, `/flutter_service_worker.js`, `/version.json` — i.e. every file that determines *which build* loads. `assets/**` and `canvaskit/**` are untouched and keep normal long-lived caching (their content doesn't change without the referencing files above changing too, so they're safe to cache aggressively).

Verified post-deploy with the same direct `curl -D -` check: `/` and `main.dart.js` both now return `no-cache`.

### 2.4 Note on the local-debug-session correlation
The user observed the live site loaded correctly once `flutter run -d chrome --web-port 5000` was stopped and the site reloaded. Likely explanation (not independently verified): Flutter Tools disables HTTP caching for the Chrome instance/tab it attaches its DevTools Protocol session to, which would have been masking the `max-age=3600` gap on `/`/`main.dart.js` in that window all along — the regular (non-debug) Chrome profile, with its own cache, was the one actually exposing the bug. Documented here as a plausible explanation for *why this wasn't noticed sooner*, not as something the fix depends on — the header fix in §2.3 is unconditional and doesn't rely on this being the right explanation.

---

## 3. Explicitly not done

- No change to `assets/**`/`canvaskit/**` caching — those are fine as-is.
- No investigation into whether Flutter Tools' cache-disabling behavior is real Chrome DevTools Protocol behavior vs. something else; treated as a plausible aside, not load-bearing for the fix.
