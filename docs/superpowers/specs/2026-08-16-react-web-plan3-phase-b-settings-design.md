# LexiCore — Cài đặt (Settings): React Web Plan 3 Phase B, Part 1

**Date:** 2026-08-16
**Status:** Approved
**Covers:** The `/settings` screen (spec §6 screen #12) for the Next.js web app — the first of two ordered sub-specs that make up React Web Plan 3 Phase B. Builds first because neither Tra từ (Lookup) nor Luyện tập (Practice hub) can make repeated AI calls without a persisted BYOK API key — today the only AI-key UI is `GenerateContentPanel.tsx`'s raw dev/verify form, which must be re-typed on every use (no persistence at all).
**Depends on:** React Web Plan 3 Phase A (`SignInButton`, `useAuthUser`, app shell/sidebar — the `/settings` link already exists and currently 404s) and React Web Plan 1 (`generateContent` onCall, Firebase Auth/Firestore wiring).
**Followed by:** A second sub-spec covering Tra từ (Lookup) + Luyện tập (Practice hub, full session flow) — not yet written; needs a visual-mockup pass for the practice-session screen first, since no mockup exists for it in the official Bloom artifact.

---

## 1. Goal

Give the web app a working `/settings` screen so the user can persist their AI provider choice, model, and API key once instead of re-entering it every session — a hard prerequisite for Lookup and Practice hub, both of which call `generateContent` repeatedly.

## 2. Scope & Non-Goals

**In scope:** Tài khoản (account), AI Provider + API Key (BYOK), Giao diện (theme + font-size), Vùng nguy hiểm (sign-out only). The Cloud KMS encryption backend work this screen depends on (new `encryptApiKey` onCall, `generateContent` changes).

**Non-goals:**
- **Đồng bộ (Sync) section** — omitted entirely. It exists in Flutter as a Hive-local-vs-Firestore sync status indicator; the web app has no local storage layer at all (confirmed against spec §3.3/§8), so there is nothing to sync in that sense.
- **Danger-zone actions beyond sign-out** — no "delete all vocab data" / "delete account." Matches Flutter's current `settings_screen.dart`, which also only has "Đăng xuất" in this area.
- **Multiple API keys per provider** — one key per provider (Gemini/Groq/OpenRouter), matching Flutter's existing `ProviderConfig` shape exactly. Rejected explicitly (see §5) in favor of simplicity and Flutter-schema compatibility; revisit only if a concrete quota-rotation need shows up later.
- **Flutter-side changes of any kind** — Flutter keeps reading/writing its AI settings purely from local `SharedPreferences` (`lib/features/dictionary/presentation/providers/user_settings_provider.dart`), unchanged. Migrating Flutter onto the same Firestore-backed settings doc this spec introduces is a deliberately deferred, separate follow-up (see §5).
- **Lookup/Practice hub themselves** — covered by the second sub-spec, not this one.

---

## 3. Design

### 3.1 Data model

New Firestore path, following the existing `users/{uid}/vocab_records` / `users/{uid}/topics` subcollection convention:

```
users/{uid}/settings/config
{
  activeProvider: "gemini" | "groq" | "openrouter",
  providers: {
    gemini:     { model: string, apiKeyCiphertext: string | null },
    groq:       { model: string, apiKeyCiphertext: string | null },
    openrouter: { model: string, apiKeyCiphertext: string | null },
  },
  theme: "light" | "dark" | "system",
  fontSize: "small" | "medium" | "large",
}
```

Theme and font-size are bundled into the same document as the AI provider config — both are per-user preferences with no sensitivity concerns, and bundling avoids a second document/read for a screen this small. They sync across devices the same way the AI settings do.

`apiKeyCiphertext` is `null` until the user has entered a key for that provider at least once. Model presets themselves (§3.3) are **not** stored in Firestore — they're a static list in the web app's code, matching how Flutter hardcodes `AiProvider.modelPresets`.

### 3.2 BYOK API key encryption — Cloud KMS

**Reverses a prior decision.** The original umbrella spec (§3.5) stated the API key is "never persisted in the DB, encrypted or otherwise" — device-local only, an explicit React Web Plan 1 security decision. This spec supersedes that: the key now persists in Firestore so the user isn't forced to re-enter it on every device. §3.5 has been updated in place (marked "REVISED") rather than left stale.

To avoid hand-rolled client-side cryptography, encryption/decryption happens **only on the backend**, via **Google Cloud KMS** — a managed GCP service already available in this project:

- **New GCP setup:** enable the Cloud KMS API; create a keyring + crypto key in `asia-southeast1` (same region policy as every other resource in this project — see CLAUDE.md); grant `roles/cloudkms.cryptoKeyEncrypterDecrypter` to the Cloud Functions runtime service account. Confirm the real service account directly (`gcloud functions describe <fn> --gen2 --format="value(serviceConfig.serviceAccountEmail)"`) rather than assuming — React Web Plan 2's notes recorded the actual SA (`243190098866-compute@developer.gserviceaccount.com`) differing from what an earlier plan guessed.
- **New `encryptApiKey` onCall function:** client sends the raw API key (same `onCall` auth-verification pattern as every other function in `functions/src/`) → the function calls Cloud KMS `encrypt` → returns ciphertext → the client writes that ciphertext into `users/{uid}/settings/config`. The raw key is never written to Firestore.
- **`generateContent` changes:** currently accepts `apiKey: string` (the raw key) in its request payload — unchanged for backward compatibility with any direct/dev-panel caller. The web Settings/Lookup/Practice-hub flow instead sends the **ciphertext** it read from Firestore, tagged so the function knows to decrypt it via Cloud KMS in-memory before using it for the upstream LLM call. The decrypted key is never logged or cached, exactly as today.
- **Client never runs any crypto.** It only ever handles opaque ciphertext blobs — write path goes through `encryptApiKey`, read/use path goes through the modified `generateContent`.

### 3.3 AI Provider + API Key UI

Mirrors Flutter's existing `_ModelTile` / `_CustomModelDialog` pattern (`lib/features/settings/presentation/screens/settings_screen.dart`) field-for-field:

- A provider selector (Gemini / Groq / OpenRouter) — matches `AiProvider`.
- A model picker: a dropdown of that provider's preset models (hardcoded in web code, copied from `AiProvider.modelPresets`/`defaultModel`), plus a "Khác..." (Other) option that opens a small text-input dialog for typing an arbitrary model string. Reason (user-stated): providers add/deprecate models faster than a hardcoded preset list can track, so free-text entry must always be available alongside the convenience presets.

| Provider | Default model | Presets |
| --- | --- | --- |
| Gemini | `gemini-2.5-flash` | + `gemini-2.5-pro`, `gemini-2.0-flash`, `gemini-1.5-flash` |
| Groq | `llama-3.3-70b-versatile` | + `llama-3.1-8b-instant`, `mixtral-8x7b-32768`, `gemma2-9b-it` |
| OpenRouter | `meta-llama/llama-3.3-70b-instruct` | + `google/gemini-2.5-flash`, `anthropic/claude-haiku-4-5`, `mistralai/mixtral-8x7b-instruct` |

- An API key input (password-masked, matching `GenerateContentPanel.tsx`'s existing `type="password"` pattern) with a "Cập nhật" (update) action that calls `encryptApiKey` and writes the returned ciphertext. If a key already exists for that provider, the field shows a masked placeholder (e.g. `••••••••`) rather than the real value — the ciphertext can't be decrypted client-side anyway, so there is nothing to show even if desired.

### 3.4 Giao diện (theme + font-size)

Theme: light / dark / system (a three-way toggle, matching the existing `bloom.css` tokens' `:root` / `prefers-color-scheme` / `[data-theme]` structure already built in React Web Plan 3 Phase A — Settings just needs to read/write the `data-theme` attribute and persist the choice to Firestore, not invent new CSS tokens).

Font-size: small / medium / large, matching Flutter's existing font-scaling concept (`lib/core/utils/web_text_scale.dart`'s `webScaled()` on the Flutter Web side) in spirit, though the web app's own scaling mechanism (likely a CSS custom property multiplier) is an implementation detail for the plan, not fixed here.

### 3.5 Tài khoản + Vùng nguy hiểm

Tài khoản: reuses the existing `SignInButton`/`useAuthUser` (React Web Plan 1), displaying the signed-in Google account's name/email/photo.

Vùng nguy hiểm: a single "Đăng xuất" (sign out) action. No other destructive actions in this phase.

---

## 4. Key Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| API key storage | Firestore (`users/{uid}/settings/config`), reversing the original "device-only" spec decision | User wants to avoid re-entering the key on every device; accepted as an explicit, recorded trade-off |
| Encryption approach | Google Cloud KMS (backend-only), not client-side crypto | Avoids hand-rolled cryptography; no user-managed passphrase to forget; one standard, audited, managed tool instead of a bespoke scheme |
| Keys per provider | One (matches Flutter's `ProviderConfig` exactly) | Simplicity; keeps the schema compatible with a future Flutter sync; no concrete need for key rotation surfaced |
| Model selection | Preset dropdown (hardcoded, mirrors Flutter's `modelPresets`) + free-text "Khác..." | Providers add/deprecate models faster than a preset list can track; matches an already-proven Flutter UI pattern |
| Theme/font-size storage | Same Firestore doc as AI settings, not localStorage | Non-sensitive, cheap to bundle, gets cross-device sync for free |
| Đồng bộ section | Removed entirely | Web has no local storage layer, so there is nothing to sync in the sense Flutter's UI means |
| Vùng nguy hiểm scope | Sign-out only | Matches Flutter's current scope exactly; no destructive-data actions requested |

---

## 5. Deferred / Open Follow-ups

- **Flutter-side sync for both this settings doc and the streak collection (from the Dashboard scope discussion) is explicitly deferred**, same shape as the Phase A "delete on web doesn't tombstone on Flutter resync" gap: Flutter continues reading/writing its own AI settings purely from local `SharedPreferences`, unaware of `users/{uid}/settings/config`. A user who changes their key/model on web won't see it reflected on mobile (and vice versa) until a future cross-repo task migrates Flutter onto the same Firestore doc. Must be flagged again in the final whole-branch review for this sub-spec's plan, not just here.
- **Dashboard (Tổng quan) and the `users/{uid}/streak` collection are postponed out of Phase B entirely**, picked up as their own later phase once Lookup/Practice hub are shipped and stable. Streak trigger criteria were already decided for whenever that phase starts: completing at least 1 session of vocab SM-2 practice, Đọc & gõ, Part 5/6/7, Nghe chép, or Nghe hiểu counts; Word Radar does not.
- **Multiple API keys per provider** — not built now; revisit only if a real quota-rotation need appears.
- **BYOK session-token optimization** (§9 of the umbrella spec, still not adopted) is superseded in spirit by this spec's Cloud KMS approach — no longer relevant to revisit separately.
- **Firestore security rules for `users/{uid}/settings/config` must be confirmed to enforce `request.auth.uid == uid` on both read and write** before this ships — a recurring open recommendation from prior React Web Plan 3 reviews (no `firestore.rules` file exists in this repo to check directly; must be verified against the live Firebase Console/CLI at implementation time). This collection is more sensitive than `vocab_records`/`topics` since it holds ciphertext of the user's own API key, so this check matters more here than it did for those.
