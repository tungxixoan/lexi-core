# LexiCore — React Web Redesign & Backend Migration Design Spec

**Date:** 2026-08-11
**Status:** Approved
**Covers:** The umbrella design for replacing Flutter Web with a new React web frontend (design system + screen inventory), plus the backend/infra decisions that frontend depends on (hosting, DB, STT/TTS, LLM proxying). This spec is intentionally broad — implementation will be decomposed into 3 plans (see §10).
**Depends on:** none (new initiative). Does not change the Flutter mobile app or its Firebase usage.

---

## 1. Goal

Replace the current Flutter Web build (`lexi-core.web.app`) with a purpose-built React web frontend, visually redesigned for more polish/appeal (the "Bloom" design system below), while the Flutter mobile app continues unchanged. Alongside the frontend rewrite, move AI-adjacent work — LLM prompt calls and TTS (both exist today, client-side) — to a server layer, for security and quality reasons, not raw speed. STT does not exist yet anywhere in the app (no `speech_to_text` dependency, no feature uses it) — this spec prepares a server-side home for it ahead of a future shadowing-practice feature, it is not migrating anything that currently runs.

## 2. Scope & Non-Goals

**In scope:**
- Architecture decisions for the new web stack: frontend framework/host, backend/API layer, database, STT/TTS, LLM call proxying.
- A complete visual design system ("Bloom") — color tokens (light/dark), typography, and layout language.
- A full navigation/IA and screen inventory for the web app's core flows.
- Two specific interaction patterns worked out in detail: the vocabulary detail view (Side Drawer) and the "gợi ý từ mới" (new-word suggestion) presentation.

**Non-goals / explicitly deferred:**
- **Flutter mobile app is unchanged.** It keeps using Firebase directly exactly as today; nothing here touches it.
- **DB migration to Supabase is deferred**, not adopted now (see §3.3). Revisit only as a separate, isolated project if a concrete need (full-text search, pgvector, heavy relational queries) arises later.
- **Dedicated Part 5 / Part 6 mockups are deferred.** They share Part 7's multiple-choice session/result pattern; Part 7's mockup stands in for the family. Only "Đọc & gõ" (bilingual typing) got its own mockup because it's structurally different (free-text input, not MC).
- **Mobile-web responsive breakpoints are not designed here.** All mockups target desktop web (sidebar nav, ≥1024px). A responsive pass for narrow viewports is future work.
- Pixel-perfect component specs (exact spacing/shadow values for every state) are not in this doc — the mockup artifacts (§6) are the visual reference; implementation should derive tokens from them, not hand-tune independently.

---

## 3. Architecture Decisions

### 3.1 Frontend & hosting

React via **Next.js**, deployed on **Firebase App Hosting** (not Vercel — see decision history below). Firebase App Hosting is framework-aware for Next.js (SSR support, git-connected builds), so it keeps the same "frontend + backend colocated in one deploy" property Next.js is chosen for, without adding a second platform alongside Firebase.

**Decision history — Vercel was the initial pick, revised mid-spec-review:** the original reasoning ("Next.js is the natural fit for Vercel") stood when the backend was expected to do more; once STT/TTS moved to a self-hosted Cloud Run service (§3.4), Vercel's remaining job was two thin proxy endpoints — something **Cloud Functions for Firebase** does equally well, natively in the same GCP project as Cloud Run and Firestore. Consolidating removes an entire platform (one CLI, one console, one billing surface instead of three) and turns the Cloud-Functions-to-Cloud-Run call into same-project IAM instead of a hand-rolled shared secret. Trade-off, stated plainly: Vercel is the more mature, more widely-documented host specifically for Next.js; Firebase App Hosting's Next.js support is newer and less traveled. Judged worth it for a personal-scale project where operational simplicity outweighs marginal hosting polish.

**Repo structure: monorepo, one GitHub repo.** The Next.js app lives at **`apps/web/`** — a new top-level folder, *not* `web/`. This repo already has a top-level `web/` directory that is Flutter's own web-platform scaffold (`index.html`, `manifest.json`, icons — what `flutter build web` compiles from into `build/web`, which `firebase.json`'s `hosting.public` points at). Reusing that name for the Next.js app would silently collide with it. The existing Flutter code (`lib/`, `pubspec.yaml`, `web/`, `android/`, `ios/`) stays exactly where it is at the repo root, untouched. Firebase App Hosting is configured with `apps/web/` as its root/backend directory; classic Firebase Hosting keeps deploying `build/web` (Flutter) as today — both are Firebase Hosting-family products but target different directories/output, and coexist in the same Firebase project and GitHub repo until the cutover in §3.6. Add `apps/web/node_modules` and `apps/web/.next` to `.gitignore`.

**Confirmed at React Web Plan 1 implementation time** (resolving the earlier "verify against the live CLI" hedge): `firebase init apphosting` writes a `firebase.json` top-level `"apphosting"` block (`{"backendId": "lexicore-web", "rootDir": "apps/web", "ignore": [...]}`) plus a generated `apps/web/apphosting.yaml` (Cloud Run `runConfig`, and an `env:` list for environment variables — non-secret values, like the Firebase Web config, are committed directly there rather than set through the Console). Backend region and Node runtime are also CLI prompts at init time, independent of the Cloud Functions region/runtime — see §8's table for the region actually chosen (asia-southeast1, not us-central1, for Vietnam latency).

**Cloud Functions code location:** a new top-level `functions/` directory (Firebase CLI's default convention, created by `firebase init functions`) — a third sibling alongside `web/` (Flutter) and `apps/web/` (Next.js), with its own `package.json` (Node.js/TypeScript). Tested locally via the **Firebase Local Emulator Suite** (`firebase emulators:start` — runs Functions/Firestore/Auth/Storage locally, no cost, no production data touched) before deploying with `firebase deploy --only functions` — the same manual-CLI-push pattern already used for Flutter Web (`firebase deploy --only hosting`), not a git-triggered auto-deploy unless a CI workflow is added for it later.

### 3.2 Backend / API layer

**Scope boundary:** the backend is limited to the three AI-proxy endpoint families below — it is **not** a general data-access proxy. Firestore reads/writes and Auth (Google Sign-In) happen **client-side**, via the Firebase JS SDK in the browser, exactly the same trust model Flutter Web already uses today. Existing Firestore security rules apply unchanged — no rule changes needed, since the web app is just another authenticated client of the same Firebase project.

**Cloud Functions for Firebase** (2nd gen — runs on Cloud Run under the hood) expose three `onCall` functions:

- `generateContent` — LLM prompt calls (exercise/passage generation, dictionary lookups, Word Radar suggestions) — thin proxy to Gemini/Groq/OpenRouter using the client-supplied BYOK key (§3.5).
- `getPronunciation` — TTS proxy, including the Storage cache check (§3.4).
- `transcribeAudio` (future) — STT proxy, once a shadowing-practice feature exists.

The client calls these via the Firebase Functions SDK's `httpsCallable()`, not raw `fetch` — the SDK attaches the caller's ID token automatically, so no app code manages an Authorization header. The BYOK provider key travels as a field in the callable's `data` payload (still never a URL query string).

Long-running generations (e.g. a full Part 7 set, which needs several AI calls) should ideally **stream the response** to the client for perceived-latency reasons — 2nd-gen Cloud Functions allow execution times up to 60 minutes, far more headroom than the original Vercel-Hobby-function assumption that motivated streaming, so this is now a UX nicety rather than a hard requirement. **Verify at implementation time** whether `onCall`'s streaming support (`stream: true` / `sendChunk`) is mature enough to rely on; if not, a plain block-and-return response is an acceptable fallback given the relaxed time limit.

**Auth requirement:** every AI-proxy function requires the caller to be signed in — enforced by using Firebase's **`onCall`** function type, which automatically verifies the Firebase ID token before the function body runs (no manual Admin SDK token-verification code needed, unlike a bare HTTPS endpoint would require). This applies even to the LLM-proxy, though callers still need their own BYOK key to get a useful response from it: without the `onCall` check, a stranger who finds the function URL could spam it and burn *your* Cloud Functions invocation quota for free, even though they can't burn your AI-provider spend (they'd need their own key for that).

### 3.3 Database — keep Firebase, do not adopt Supabase now

Supabase (Postgres) is technically a strong fit — RLS, real full-text search (on the roadmap already), pgvector if semantic Word Radar/RAG features happen later, an official Flutter SDK. But adopting it *in this same effort* would mean rewriting Auth (Google Sign-In), Firestore sync, and security rules→RLS on **both** the new web app and the already-live Flutter mobile app simultaneously with the frontend rewrite — two large risks stacked at once, over data real users already have.

**Decision: keep Firestore + Firebase Auth as the single source of truth.** The React web app talks to Firebase client-side via the Firebase JS SDK — see §3.2's scope boundary; the backend does not proxy Firestore/Auth. Supabase remains a candidate for a future, standalone migration project if a concrete need justifies it — not bundled with this one.

### 3.4 STT / TTS — move server-side, self-hosted open-source models

Reasoning is **quality/consistency, not speed**: the Web Speech API (browser TTS/STT) is inconsistent across browsers/OS, often lacking decent Vietnamese voices, and has no reliable STT path for a future shadowing-practice feature. Flutter mobile keeps `flutter_tts` (native OS voices are fine there) — this change is web-specific.

**Models — self-hosted open-source, not a paid third-party API:**

- **TTS:** [Piper](https://github.com/rhasspy/piper) — lightweight, CPU-friendly, has both Vietnamese and English voices, low latency for short clips (words/sentences).
- **STT (future):** [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (`base`/`small` checkpoint) — CPU-friendly, good Vietnamese support.
- Rejected: paying per-call for OpenAI TTS/Whisper API or Google Cloud TTS/STT — no reason to pay per-call for a capability decent open-weight models already cover well at this app's scale.

**Hosting — Google Cloud Run, not a Cloud Function:** these are compute-heavy model-inference workloads (larger container, longer-running, wants more memory than a typical function) — a custom Cloud Run service fits better than trying to fit model weights and inference into a Cloud Function. Piper + faster-whisper are packaged into one Docker container (a small FastAPI service) and deployed to **Cloud Run**, called by the Cloud Functions proxy (§3.2) via same-project IAM service-to-service auth — the Cloud Run service has no public ingress and is never reachable directly from the browser.

- Cloud Run's free tier (2M requests/mo, ~180k vCPU-seconds, ~360k GB-seconds/mo) comfortably covers personal-project scale — genuinely free, not a "trial" that later requires payment.
- Trade-off: **scale-to-zero** — an idle container costs nothing but adds cold-start latency (a few seconds, dominated by loading model weights into memory) to the first request after a quiet period. Acceptable here because usage is session-shaped (a practice session makes several TTS/STT calls in a row; only the first pays the cold-start cost, the container stays warm for the rest of the session).
- If cold-start latency ever becomes a real complaint, the fallback is an Oracle Cloud "Always Free" ARM VM (4 OCPU/24GB RAM, permanently free, always-on, no scale-to-zero) — logged as a deferred alternative (§9), not adopted now since it trades less latency for more ops burden (self-managed VM vs. a managed container platform).

**Cache layer for pronunciation TTS (the high-frequency path):** this is real file storage, not a config/settings cache — Firebase Storage is Google Cloud Storage under the hood, the same category of service as S3 or Azure Blob. The mechanism is content-addressable: the `getPronunciation` Cloud Function computes `hash = sha256(normalize(text) + language + voiceId)` (`normalize` = trim + Unicode-normalize, so trivial whitespace differences don't fragment the cache) and checks whether a file already exists at the deterministic path for that hash. A hit returns that file's download URL directly — no Cloud Run call, no model run, no cold-start exposure. A miss calls the Cloud Run Piper service once, uploads the resulting audio to that path, then returns its URL. There is no explicit "is this stale" check anywhere: identical text always resolves to the same path (cache hit), and any change to the text — an edited or regenerated example sentence — produces a different hash and therefore a different path (cache miss → fresh file), automatically, with no invalidation logic needed. Deleting a cached file is always safe: a future request for that exact text just becomes a miss and regenerates from scratch, so cache entries can be pruned with zero correctness risk.

Two tiers, stored under different path prefixes, because they have very different sharing/growth characteristics:

- **`tts-cache/word/{language}/{voiceId}/{hash}.wav`** — standalone headword pronunciation (no sentence). Vocabulary is finite (tens of thousands of words at most, across every language/topic this app will ever cover) and identical for anyone who looks up the same word — high cross-account cache-hit rate, the cache converges and basically stops growing. **No lifecycle/expiry** — small enough, and valuable enough, to keep indefinitely.
- **`tts-cache/sentence/{language}/{voiceId}/{hash}.wav`** — full example-sentence pronunciation. AI-generated example sentences are not deterministic, so N accounts looking up the same word typically get N different sentences — cross-account sharing is weak here; the real value is *within* one account's repeated SM-2 reviews of the same saved example over time. This tier grows much faster (proportional to accounts × examples × edits) — bounded with a **Cloud Storage Object Lifecycle rule**: auto-delete objects older than 90 days, a bucket-level config, no custom cleanup code. At this app's actual expected scale (personal project, not thousands of users), storage stays comfortably inside Firebase Storage's free tier (5GB, genuinely free, not a trial) for a long time regardless; the lifecycle rule is a hygiene bound, not a cost emergency.

**Nghe (Listening) audio is never cached** — dictation/comprehension text is freshly AI-generated per session and essentially unique each time, so caching it wouldn't produce meaningful hit rates. Those requests always call the Cloud Run service live and return the audio directly, without ever touching Storage.

### 3.5 LLM prompt calls — move server-side, keep BYOK

Moved server-side for **security/control, not speed** (one extra network hop costs tens of ms against multi-second generation times — negligible). What it actually buys: the raw provider API key never appears in a request to a third-party domain from the browser; validation/retry logic (like `Part7Source._hasValidShape`) centralizes in one place instead of duplicating per client; streaming and rate/cost control become possible.

**Key handling — BYOK preserved:**
- The user still supplies their own Gemini/Groq/OpenRouter key (as today).
- On each AI-backed call, the key travels as a field in the `httpsCallable` **`data` payload** (never a URL query string, which would leak into logs). The Cloud Function uses it in-memory for that one upstream call and never logs or caches it — this remains true regardless of where the key sits at rest client-side.
- **Threat model note (recorded for future readers, not a to-do):** this does not hide the key from someone with DevTools access to the *user's own browser* — nothing can, since the browser must send the key to reach any server. It protects against the key being logged/exposed to *other* parties and centralizes validation. Real damage-limitation comes from **provider-side spend/rate caps** (set on the Gemini/Groq/OpenRouter dashboard), not from the transport mechanism.
- A short-lived session-token optimization (server issues a TTL'd token after the first key submission, client resends that instead of the raw key on subsequent calls — e.g. a Firestore document with a TTL policy for auto-expiry, never a permanent row) was discussed as a possible future polish. **Not adopted now** — logged here as a deferred nice-to-have (§9), not a requirement.

**REVISED (2026-08-16, user-confirmed, React Web Plan 3 Phase B — Cài đặt design):** the original "never persisted in the DB" line above is **superseded**. The key now IS persisted in Firestore (`users/{uid}/settings`, exact shape defined in the Phase B plan), same access-boundary/security-rules model as `vocab_records`/`topics` (owner-only via `request.auth.uid == uid`), so the user isn't forced to re-enter their key on every device/browser. Flutter currently stores the equivalent (`ai_config_{provider}` JSON, `ai_active_provider`) purely in local `SharedPreferences` (`lib/features/dictionary/presentation/providers/user_settings_provider.dart`) — **not yet updated to match**; syncing Flutter onto the same Firestore-backed settings doc is an explicitly deferred, known follow-up, same deferred-cross-repo-sync shape as the streak-collection decision (§10.3 Phase B notes). The rest of this section (in-memory-only handling on the Cloud Function side, `data`-payload transport, threat model) is unchanged.

### 3.6 Rollout / migration plan

Flutter Web (`lexi-core.web.app`) **stays live and unchanged** throughout development. The React app deploys to a non-production preview URL first (exact mechanism per §3.1's verification note — App Hosting's preview-deploy flow, checked at implementation time). The production domain only cuts over to React after it's been tested thoroughly — this is a deliberate, explicit gate, not an incidental detail.

---

## 4. Design System — "Bloom" (Warm Modern)

Chosen from three explored directions (Playful/Gamified, Editorial Minimalist, Bloom/Warm Modern) — see mockup artifacts in §6 for the two rejected directions' visual reference if ever revisited. Bloom reads as approachable but organized — closer to Headspace than Duolingo — which fit better than the higher-energy gamified direction or the colder editorial one for a TOEIC-prep audience that skews adult/professional but still wants encouragement.

### 4.1 Color tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--bg-a` / `--bg-b` | `#FFF3EE` / `#F1EEFF` | `#241923` / `#1C1B2B` | Radial gradient wash behind the app frame (blush → lavender), not a flat cream |
| `--surface` | `#FFFFFF` | `#2A2028` | Cards, drawer, modals |
| `--surface-2` | `#FBF3F7` | `#322730` | Sidebar, list rows, nested panels |
| `--ink` / `--ink-soft` / `--ink-faint` | `#362A33` / `#7A6B76` / `#A493A0` | `#F3E9EE` / `#C2AEB9` / `#8B7783` | Text hierarchy |
| `--accent` (dusty rose) | `#C9587A` | `#E693AC` | Primary accent — CTAs, active states, brand |
| `--sage` (secondary) | `#6F9A87` | `#8FC1AA` | CEFR pills, topic chips, secondary accents |
| `--success` / `--danger` | `#4C8F6E` / `#C15B4E` | `#7DCBA6` / `#E38A79` | Correct/incorrect states only — never used as the brand accent |
| `--border` | `#EFDDE3` | `#43323C` | Hairlines, card borders |

All three theme states (explicit light, explicit dark, system/unstamped) are defined per the standard token pattern — see any mockup artifact's `<style>` block for the exact `:root` / `@media` / `[data-theme]` structure to carry into the real app's theme file.

### 4.2 Typography

No custom webfont embedding — a deliberate system-font choice for a fast, dependency-free web build. Display/headings use a rounded-leaning system stack (`"Trebuchet MS", "Segoe UI", -apple-system, system-ui, sans-serif`) at weight 700, body text the same family at 400. Numbers/scores/timers use `ui-monospace` with `font-variant-numeric: tabular-nums`.

### 4.3 Layout language

- Persistent left sidebar (~220-230px) with a rounded-pill active-state indicator (not underline/border), grouped by section with small uppercase group labels (Đọc, Nghe, Khác).
- A soft radial-gradient blob decorates the top-right corner of the main app frame — the one deliberate "flourish," used once, not repeated per-card.
- Cards are generously rounded (16-26px radius), no hard shadows — soft, colored-tinted shadows instead (`rgba` mixed toward the accent hue).
- Two-column layout for content-plus-context screens (Tra từ, Part 7 session, Nghe hiểu): a primary content column plus a ~250px right rail with something genuinely useful (recent lookups, question navigator, session stats) — not decorative empty space. Screens without natural rail content (Dashboard, Vocab Bank, Practice hub) use full-width flex/grid layouts instead of an artificially narrow column.

---

## 5. Navigation / Information Architecture

Sidebar groups, top to bottom:

```
🏠 Tổng quan
🔍 Tra từ
📚 Ngân hàng từ vựng
🎯 Luyện tập
── Đọc ──
📖 Đọc — tổng quan          (hub: 4 mode cards)
✍️ Đọc & gõ                  (bilingual typing)
📝 Part 7 · Làm bài / Kết quả (MC pattern — represents Part 5/6 too)
── Nghe ──
🎧 Nghe — tổng quan          (hub: 2 mode cards)
✏️ Nghe chép                 (dictation)
🎙️ Nghe hiểu                 (MC comprehension)
── Khác ──
⚙️ Cài đặt
```

Part 5 and Part 6 are reachable from the Đọc hub as mode cards but do not get their own nav entries or dedicated mockups (§2 non-goals) — they render with the same session/result shape Part 7 demonstrates.

---

## 6. Screen Inventory

All 12 screens are mocked in one consolidated artifact (desktop web, both themes token-ready): **[Bloom — Thiết kế chi tiết toàn app](https://claude.ai/code/artifact/a7202d87-3a45-40ed-96fa-6a61766a0396)**.

| # | Screen | Notes |
| --- | --- | --- |
| 1 | Tổng quan (Dashboard) | New — didn't exist as a distinct screen in Flutter. Streak/due-today/accuracy stats, 3 quick-access mode cards, recent activity list. |
| 2 | Tra từ (Lookup) | Word card + right rail "Tra cứu gần đây". |
| 3 | Ngân hàng từ vựng (Vocab Bank) | List + Side Drawer detail (§7.1) + "Gợi ý từ mới" grid (§7.2) below the list. |
| 4 | Luyện tập (Practice hub) | Stat row, 3 filter tiles that open inline popovers (§7.3) instead of Flutter's bottom sheets, CTA row. |
| 5 | Đọc — tổng quan | Hub: 4 mode cards (Luyện đọc song ngữ, Part 5, Part 6, Part 7). |
| 6 | Đọc & gõ | VN prompt → EN free-text input → diff-style feedback. |
| 7 | Part 7 · Làm bài | Passage + MC question + right rail question-navigator (answered/current state). |
| 8 | Part 7 · Kết quả | Score ring + mini-stats, per-question breakdown, vocab-suggestion grid. |
| 9 | Nghe — tổng quan | Hub: 2 mode cards (Nghe chép, Nghe hiểu), difficulty note (Dễ/Trung bình/Khó). |
| 10 | Nghe chép | Player (waveform, speed 0.75x/1x/1.25x, seek), dictation textarea + feedback, right rail session stats + tip. |
| 11 | Nghe hiểu | Player (no waveform — comprehension, not transcription) + MC question + right rail question-navigator. |
| 12 | Cài đặt | Tài khoản (Google), AI provider + API key (BYOK, reflects §3.5), Giao diện (theme + font-size), Đồng bộ, Vùng nguy hiểm. |

Two earlier-stage exploration artifacts remain as reference for the road not taken (color/layout comparison only, not authoritative for final component specs):
[Sparkline — Playful/Gamified](https://claude.ai/code/artifact/bf782536-96af-4de7-a1e7-09082a3feaa1), [Ledger — Editorial Minimalist](https://claude.ai/code/artifact/59b2af7d-85f5-447b-a9a4-b4e0c030645e).

---

## 7. Key Interaction Patterns

### 7.1 Vocabulary detail — Side Drawer

Chosen over a centered modal (Variant A) and a tabbed modal (Variant C) — [comparison artifact](https://claude.ai/code/artifact/530b41ea-eb51-4c34-9fc2-cfb2e4ba34ab). Detail slides in from the right (~320-340px) instead of covering the screen, so context (the vocab list, or a reading passage when triggered from in-line text) stays visible and scrollable behind it. Sections use `<details>`-style accordions (Nghĩa & định nghĩa, Ví dụ open by default; Từ đồng nghĩa & chủ đề, Ghi chú collapsed) rather than tabs. Footer shows a compact SM-2 "độ thành thạo" progress bar plus Sửa/Xoá actions — full SM-2 detail (ease factor, review history) was explored in Variant C's tabbed layout but not carried into the chosen pattern; revisit only if users want it.

Fields shown map directly to `VocabRecord` (headword, ipa, meaning, definition, examples, synonyms, topicIds resolved to names, personalNotes) plus the previously-unused `nextReviewAt`/`sm2Repetitions`/`sm2EaseFactor` surfaced as the footer progress bar — this is new: the current Flutter `VocabDetailScreen` doesn't show SM-2 data anywhere.

### 7.2 "Gợi ý từ mới" (new-word suggestions)

Grid of cards (not the current Flutter carousel/list), each showing headword + CEFR pill + meaning + an inline "Xem thêm" expand (definition + example, no navigation away) + a one-tap save button that flips to a saved (✓) state. A bulk "Lưu tất cả" action stays available above the grid, matching current behavior. Where context justifies it (e.g. Part 7 result screen), a small "vì sao gợi ý từ này" line ties the suggestion back to the passage/session it came from.

### 7.3 Practice-hub filters — inline popovers

Flutter's `FilterTile` → bottom-sheet pattern doesn't fit web. Each of the 3 filter tiles (Chủ đề, Trình độ, Số từ/phiên) opens a small anchored popover directly below it: multi-select chips for Chủ đề and Trình độ (CEFR range), a +/− stepper for Số từ/phiên, each with an "Áp dụng" action. This was flagged mid-review as missing from the first pass of mockups — worth calling out explicitly since it's easy to forget again when this becomes an implementation plan.

---

## 8. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Frontend hosting | Next.js on **Firebase App Hosting**, not Vercel | Vercel's remaining role shrank to two thin proxies once STT/TTS moved to Cloud Run; consolidating onto Firebase/GCP means one platform instead of three, and native same-project IAM instead of a hand-rolled shared secret. Trade-off: Firebase App Hosting's Next.js support is newer/less traveled than Vercel's |
| Backend/API layer | Cloud Functions for Firebase (2nd gen), not Vercel serverless functions | Same platform as Auth/Firestore/Storage/Cloud Run; `onCall` gives free built-in ID-token verification |
| Region | `asia-southeast1` (Singapore) for both App Hosting and Cloud Functions, not the default `us-central1` | ~200-250ms RTT from Vietnam to `us-central1` vs ~30-50ms to `asia-southeast1` — meaningful for an interactively AI-calling app. Both sides must agree: the client's `getFunctions(app, region)` call and the server's `onCall({region}, handler)` both specify it, or `httpsCallable` targets the wrong region entirely |
| Database | Keep Firebase, defer Supabase | Avoids stacking a DB migration (Auth + Firestore→Postgres + RLS, across both mobile and web) on top of a frontend rewrite; Supabase remains a candidate for a later, isolated project |
| STT/TTS | Move server-side | Web Speech API is inconsistent cross-browser; server models give one consistent experience. Not about speed. |
| STT/TTS models | Self-hosted open-source (Piper, faster-whisper) on Cloud Run, not a paid third-party API | No reason to pay per-call for capability decent open-weight models already cover; Cloud Run's free tier comfortably covers personal-project scale |
| Pronunciation TTS caching | Real audio files in Firebase Storage, keyed by `sha256(text+lang+voice)`; two tiers — `word/` (no expiry, high cross-account sharing) and `sentence/` (90-day lifecycle rule, mostly per-account reuse); Nghe (Listening) audio never cached | Word pronunciation is finite and shared across everyone; example sentences vary per account/generation so grow faster and share less — different lifecycle needs. Deleting a cache entry is always safe (a miss just regenerates), so a blunt auto-expiry rule carries no correctness risk |
| AI-proxy endpoint auth | Require a valid Firebase ID token on every call (`onCall` functions) | Prevents strangers from spamming the endpoints and burning Cloud Functions quota, even though they can't burn AI-provider spend without their own BYOK key |
| LLM prompt calls | Move server-side, BYOK key never stored in DB | Hides the key from third-party domains and centralizes validation/streaming; storing keys server-side would create a single high-value breach target disproportionate to this app's scale |
| Firebase access boundary | Web app talks to Firestore/Auth client-side via the JS SDK, same as Flutter Web; backend limited to AI-proxy only | No security-rule changes needed; avoids scope creep of the backend into a general data proxy |
| Rollout | Flutter Web stays live; React ships to staging first, production cutover only after testing | Explicit user requirement — no accidental simultaneous kill of the working site |
| Visual direction | Bloom (Warm Modern) over Playful/Gamified or Editorial Minimalist | Best fit for an adult/professional TOEIC-prep audience that still wants encouragement, not clinical minimalism or high-energy gamification |
| Vocab detail pattern | Side Drawer over centered modal or tabbed modal | Keeps reading/list context visible behind it — important specifically for the "tra từ giữa lúc đọc passage" use case |
| Part 5/6 mockups | Not built separately; Part 7 stands in | Same MC session/result shape; building 3 near-identical mockups wasn't worth the redundancy |

---

## 9. Deferred / Open Follow-ups

- **Supabase migration** — revisit only as its own isolated project, if a concrete need (full-text search, pgvector/RAG, heavy relational queries) materializes.
- **BYOK session-token optimization** — issuing a short-lived, TTL'd token after first key submission (e.g. a TTL'd Firestore document) instead of resending the raw key every request. Logged as a possible polish, not required.
- **Oracle Cloud "Always Free" ARM VM** — alternative to Cloud Run for the STT/TTS model host, if scale-to-zero cold-start latency ever becomes a real complaint. Trades less latency for more self-managed-server ops burden; not adopted now.
- **Responsive/mobile-web breakpoints** — all 12 screens are desktop-only mockups; a narrow-viewport pass is separate future work.
- **Full SM-2 detail view** (ease factor, review history chart) — explored in the Variant C tabbed-modal mockup but not carried into the chosen Side Drawer pattern. Revisit if users want it.

---

## 10. Implementation Note (decomposition)

This spec is intentionally broad and covers three logically separable workstreams that became **separate plans** under `writing-plans`, not one:

This spec's own "Plan 1/2/3" numbering is prefixed **"React Web Plan N"** everywhere outside this list (in plan filenames, `.superpowers/sdd/progress.md`, memory, etc.) to avoid colliding with the Flutter app's own, unrelated Plan 1-10 — renamed 2026-08-16 after the collision caused real confusion.

1. **React Web Plan 1 — Backend/infra core** ✅ complete — Next.js scaffold on Firebase App Hosting, client-side Firebase wiring (Auth + Firestore, reusing existing security rules), the LLM-proxy `onCall` function with BYOK header/payload passthrough and built-in ID-token verification, staging/preview-channel deploy. No TTS/STT yet.
2. **React Web Plan 2 — STT/TTS service** ✅ complete — the Piper + faster-whisper Docker container on Cloud Run, the TTS/STT `onCall` proxy functions (reusing React Web Plan 1's auth pattern), and the Firebase Storage pronunciation cache. Depended on React Web Plan 1 existing (Firebase project, auth pattern) but is otherwise a self-contained deployable unit — a genuinely separate service, not just more functions.
3. **React Web Plan 3 — React frontend build-out** — the Bloom design system as real components/tokens, then the screen inventory in §6. Large enough that it is itself split into four phases, in dependency order:
   - **Phase A — Vocab Bank + Side Drawer** ✅ complete — the most-explored pattern, needs only React Web Plan 1 (Firestore/Auth). See `docs/superpowers/plans/2026-08-15-react-web-plan3-phase-a-bloom-foundation-vocab-bank.md` plus the `2026-08-15-vocab-bank-polish*` follow-up plan/spec for post-launch fixes.
   - **Phase B — Dashboard / Tra từ (Lookup) / Luyện tập (Practice hub)** — needs React Web Plan 2's cached pronunciation TTS.
   - **Phase C — Đọc/Nghe hubs and their session/result screens** — Nghe needs React Web Plan 2's live TTS/STT.
   - **Phase D — Cài đặt** (account, BYOK key UI, theme/font-size).

React Web Plan 3 depends on React Web Plan 1 for any screen touching Firestore/Auth/LLM generation, and on React Web Plan 2 specifically for any screen playing pronunciation or listening audio — in practice, most screens need both before they're more than a static mockup. The "Phase A/B/C/D" labels are this spec's own naming for React Web Plan 3's internal ordering (introduced when Phase A's plan doc was written) — they do not appear elsewhere in this document outside this section.
