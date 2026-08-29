# Đồng bộ Settings AI của Flutter sang Firestore — Design

## Context

Item #2 of the approved cleanup list (item #1, per-language `vocab_records` split, shipped and confirmed working in production). Web already persists AI settings in Firestore at `users/{uid}/settings/config` (`apps/web/src/lib/settings.ts`) — the API key is stored encrypted (`apiKeyCiphertext`, produced by the `encryptApiKey` Cloud Function, backed by Cloud KMS). Flutter currently stores its equivalent (`ai_config_{provider}` JSON, `ai_active_provider`) purely in local SharedPreferences, in **plaintext**, and calls AI providers **directly from the client** via `google_generative_ai` (Gemini) or raw HTTP (Groq/OpenRouter) — confirmed by reading `lib/core/services/ai_client_factory.dart` and grepping for its 9 real call sites, none of which currently touch a Cloud Function. Flutter's mandatory-sign-in change (shipped in the `2026-08-27-flutter-drop-hive` plan) means every Flutter user now has a guaranteed real Firebase uid at all times, which was the blocker that made this hard before.

**Decision made during brainstorming: full architectural unification, not just a storage-location change.** Since a KMS ciphertext is only decryptable server-side, syncing the key to Firestore as `apiKeyCiphertext` means Flutter can no longer use it to call an LLM directly — Flutter must switch to calling the `generateContent` Cloud Function (`functions/src/generateContent.ts`), exactly like web already does, rather than keeping a partial/write-only sync alongside its current direct-SDK calls.

**Key discovery that simplifies this significantly**: `AiClientFactory.buildClient()` is the **single integration point** for all AI calls in Flutter — all 9 real call sites (`gemini_dictionary_source.dart`, `dictation_source.dart`, `listening_passage_source.dart`, `exercise_generator_source.dart`, `part5_source.dart`, `part6_source.dart`, `part7_source.dart`, `reading_passage_source.dart`, `word_radar_source.dart`) consume the same `GenerativeModelClient` interface (`Future<GenerateContentResponse> generateContent(Iterable<Content> prompt)`) and never touch the underlying SDK/HTTP client directly. Replacing what `buildClient()` returns internally requires **zero changes to any of the 9 call sites**.

**`generateContent`'s Cloud Function contract already supports both plaintext and ciphertext keys** (`apiKey?` XOR `apiKeyCiphertext?`, `functions/src/generateContent.ts`) — this was already platform-agnostic before this plan; no backend changes are needed. `encryptApiKey` (`functions/src/encryptApiKey.ts`) is likewise a plain authenticated `onCall` function, already callable from any signed-in client, web or Flutter.

## Decisions made during brainstorming

- **Sync scope is exactly the AI settings, matching web's `UserSettings` fields with a real Flutter counterpart**: `activeProvider`, and per-provider `model` + `apiKeyCiphertext` (Flutter's `providerConfigs`, web's `providers`). `targetLanguage` also syncs, since both platforms already have and use it with matching semantics.
- **Everything else Flutter-only stays local, unchanged**: `activeContext`, `aiEnabled` (a toggle web has no equivalent for — web infers "AI enabled" from whether a ciphertext is present, Flutter keeps its explicit boolean), `targetCefrLevel`, and reminder/notification settings (`reminderEnabled`/`reminderHour`/`reminderMinute`) — explicitly deferred by the user ("phần thông báo làm sau"), not part of this pass. `theme`/`fontSize` exist on web's schema but have no Flutter counterpart at all — Flutter neither reads nor writes them; the shared document simply carries fields Flutter's own state doesn't use.
- **No live bidirectional sync engine** (matching the reasoning that made dropping Hive's `SyncService` worthwhile) — instead: fetch once on app launch/sign-in, merge into local state; push best-effort on every local change to a synced field.
- **`UserSettingsNotifier` stays synchronous**, still backed by SharedPreferences for instant reads everywhere it's already consumed across the app — the Firestore fetch/merge is a separate, one-shot async bootstrap step that updates the SAME local storage `UserSettingsNotifier` already reads from, not a new async data path threaded through the app.
- **One-time local-plaintext-to-ciphertext migration**, run as part of the same bootstrap step: for each provider, if Firestore already has data, Firestore wins (overwrites local, no data loss risk since it's presumably the more current copy); if Firestore has nothing for that provider but local has a plaintext key from before this update, encrypt it once via `encryptApiKey` and push the ciphertext to both local storage and Firestore; if both are empty, do nothing.
- **Error handling is asymmetric by user-visibility**: bootstrap fetch and push-on-change failures are best-effort (log, don't block); a failure in `encryptApiKey` triggered by the user actively entering a new key in Settings is surfaced as a visible error with retry, matching web's existing `AiProviderSection.tsx` pattern exactly (try/catch around `encryptApiKey`, `setError` on failure, key never saved on failure).

## Architecture

### `ProviderConfig` (`lib/features/dictionary/domain/entities/provider_config.dart`) — field rename

`apiKey` → `apiKeyCiphertext` (nullable — `null` means "not configured yet", matching web's `ProviderSettings.apiKeyCiphertext: string | null`). `model` unchanged. `toJson`/`fromJson` updated to match; `isConfigured` becomes `apiKeyCiphertext != null && apiKeyCiphertext!.isNotEmpty && model.isNotEmpty`.

### `AiClientFactory` (`lib/core/services/ai_client_factory.dart`) — new Cloud-Function-backed client

`_GeminiClient` and `_OpenAiClient` are deleted. A new `_CloudFunctionClient implements GenerativeModelClient` calls the `generateContent` onCall function (`cloud_functions` package, region `asia-southeast1` — new Flutter dependency, first-ever Cloud Functions client usage in this codebase) with `{ provider, apiKeyCiphertext, model, prompt }`, where `prompt` is the flattened text from `Iterable<Content>` (same flattening `_OpenAiClient` already does: `prompt.expand((c) => c.parts).whereType<TextPart>().map((p) => p.text).join('\n')`), and wraps the returned text into a `GenerateContentResponse`/`Candidate` matching the existing interface shape exactly (so all 9 call sites' response-parsing code needs no changes).

`provider` is sent as the lowercase string the Cloud Function expects (`"gemini"`, `"groq"`, `"openrouter"`) — NOT Dart's `AiProvider.openRouter.name` (`"openRouter"`, camelCase, a mismatch): a small explicit mapping function handles this.

`buildClient(settings)` keeps its existing synchronous signature and always returns a `_CloudFunctionClient` now, built from `settings.activeConfig.apiKeyCiphertext` and `settings.activeProvider`.

### `AiSettingsSyncService` (new) — bootstrap fetch/merge + push-on-change

A new service (mirroring `HiveMigrationService`'s established shape from the drop-Hive plan: a plain class, not a Riverpod provider itself, invoked from a provider) with two responsibilities:

```dart
class AiSettingsSyncService {
  Future<void> bootstrapSync(String uid) async { ... } // fetch, migrate, merge — see below
  Future<void> pushProviderSettings(String uid, AiProvider activeProvider, Map<AiProvider, ProviderConfig> providerConfigs, Language targetLanguage) async { ... } // best-effort push
}
```

`bootstrapSync(uid)`: reads `users/{uid}/settings/config` (same document web already uses, same field names — `activeProvider`, `providers` keyed by the lowercase provider string, `targetLanguage`; Flutter writes only these 3 top-level keys via `setDoc(..., {merge: true})`-equivalent, never touching `theme`/`fontSize`). For each provider present in the remote doc, remote wins and overwrites local `UserSettingsNotifier` state (via its existing `setProviderConfig`/`setActiveProvider`/`setTargetLanguage` methods, reused as-is). For each provider with NO remote entry but a local plaintext-shaped legacy value (see migration below), encrypt once and push. Called once from `main.dart`'s post-sign-in flow (mirroring where `HiveMigrationService.migrateIfNeeded` is already invoked from `sign_in_screen.dart` — this new call sits alongside it, same trigger point: right after a successful sign-in, before navigating to the main app).

**Legacy plaintext migration**: before this plan ships, `ProviderConfig.apiKey` was plaintext. A one-time check (only meaningful on a Flutter Web build that already had a user-entered key before this update, given the mobile app has never been distributed) reads any local `ai_config_{provider}` SharedPreferences entry still in the OLD JSON shape (`{"apiKey": "...", "model": "..."}` — a real plaintext string, not yet a ciphertext) and, only if Firestore has nothing for that provider, calls `encryptApiKey` once and rewrites local storage to the new shape before proceeding.

`pushProviderSettings(...)`: called from `UserSettingsNotifier.setActiveProvider`/`setProviderConfig`/`setTargetLanguage` after the existing local (SharedPreferences) write succeeds — fire-and-forget with `.catch`-equivalent (`unawaited(...).catchError(...)` or an internal try/catch that logs and swallows), never blocking the synchronous state update those methods already perform.

### `UserSettingsNotifier` (`lib/features/dictionary/presentation/providers/user_settings_provider.dart`) — unchanged shape, new side effects

`build()` stays exactly as synchronous as it is today, reading only SharedPreferences — `AiSettingsSyncService.bootstrapSync` runs separately and asynchronously, then calls back into this same notifier's existing setters to apply what it found, so the provider itself needs no new async code path. `setActiveProvider`, `setProviderConfig`, `setTargetLanguage` each gain one line: after the existing local write, fire off `AiSettingsSyncService.pushProviderSettings(...)` best-effort.

### Settings screen (Cài đặt) — key entry flow

The screen's "enter a new API key" flow changes from `setApiKeyForActiveProvider(rawKey)` (storing plaintext) to: call `encryptApiKey({apiKey: rawKey})` first (via the same `cloud_functions` client the new `_CloudFunctionClient` uses), then call `setProviderConfig` with the resulting ciphertext — mirroring web's `AiProviderSection.tsx handleUpdateKey` exactly, including its try/catch/error-display/finally shape.

## Error Handling

- Bootstrap fetch fails (offline, first launch, permission issue): log, leave local SharedPreferences state as the source of truth for this session, no blocking of app startup — matches this app's established best-effort convention for background sync work.
- `pushProviderSettings` fails: log, local state (already updated) is unaffected — the next successful bootstrap or push retries.
- `encryptApiKey` fails when the user enters a new key in Settings: surfaced as a visible Vietnamese error message with the key NOT saved (neither locally nor remotely), user can retry — this is the one path in this plan that does NOT get best-effort treatment, since it's a direct user action with no silent-retry opportunity otherwise.
- `generateContent` call failures (the 9 existing AI call sites): unchanged from today — each site already handles a thrown exception from `GenerativeModelClient.generateContent()` generically; the new `_CloudFunctionClient` throws on a Cloud Function error the same way `_OpenAiClient` already throws on an HTTP error, so no call site needs new error-handling code.

## Testing

- `ProviderConfig`: `toJson`/`fromJson` round-trip with the renamed `apiKeyCiphertext` field, `isConfigured` boundary cases.
- `AiClientFactory`/`_CloudFunctionClient`: unit tests with a fake `FirebaseFunctions`/`HttpsCallable` (mocktail, matching this codebase's established testing convention), covering: correct `{provider, apiKeyCiphertext, model, prompt}` payload shape, the `openRouter` → `"openrouter"` string mapping specifically, response text correctly wrapped into `GenerateContentResponse`, and a thrown Cloud Function error propagating as a Dart exception.
- `AiSettingsSyncService.bootstrapSync`: fake Firestore (`fake_cloud_firestore`, already a dev dependency from the vocab_records split plan) covering all 3 branches — remote-wins-overwrites-local, local-plaintext-migrates-when-remote-empty, both-empty-no-op — plus a fetch-failure case asserting no exception escapes and local state is untouched.
- `AiSettingsSyncService.pushProviderSettings`: asserts a Firestore write failure doesn't throw back to the caller.
- `UserSettingsNotifier`: existing synchronous-read tests keep passing unchanged; new tests confirm `setActiveProvider`/`setProviderConfig`/`setTargetLanguage` still update local state synchronously and additionally trigger a push (verifiable via a fake `AiSettingsSyncService` injected the same way `VocabRepository` is already injected elsewhere in this codebase's DI).
- Settings screen: the key-entry flow's `encryptApiKey`-then-save-ciphertext sequence, and its visible error state on an `encryptApiKey` failure — mirroring the assertions web's own `AiProviderSection` tests already make for the equivalent flow.
