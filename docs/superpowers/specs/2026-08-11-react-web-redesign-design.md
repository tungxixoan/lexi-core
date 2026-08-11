# LexiCore — React Web Redesign & Backend Migration Design Spec

**Date:** 2026-08-11
**Status:** Approved
**Covers:** The umbrella design for replacing Flutter Web with a new React web frontend (design system + screen inventory), plus the backend/infra decisions that frontend depends on (hosting, DB, STT/TTS, LLM proxying). This spec is intentionally broad — implementation will be decomposed into multiple plans (see §9).
**Depends on:** none (new initiative). Does not change the Flutter mobile app or its Firebase usage.

---

## 1. Goal

Replace the current Flutter Web build (`lexi-core.web.app`) with a purpose-built React web frontend, visually redesigned for more polish/appeal (the "Bloom" design system below), while the Flutter mobile app continues unchanged. Alongside the frontend rewrite, move AI-adjacent work (LLM prompt calls, STT, TTS) from direct client calls to a server layer on Vercel, for security and quality reasons — not raw speed.

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

React via **Next.js**, deployed on **Vercel**. Next.js is the natural fit for "React + Vercel" — colocates API routes/Server Actions with the frontend in one deploy, gives SSR and file-based routing for free. A plain Vite+React SPA was considered and rejected: it would need a separate serverless-functions setup for the backend pieces in §3.2 rather than one coherent app.

### 3.2 Backend / API layer

Vercel serverless functions (Node runtime) expose endpoints for: LLM prompt calls (exercise/passage generation, dictionary lookups, Word Radar suggestions), TTS, and (future) STT. Long-running generations (e.g. a full Part 7 set, which needs several AI calls) should **stream the response** (SSE) to the client rather than block-and-return, both to stay under serverless execution limits and to improve perceived latency.

### 3.3 Database — keep Firebase, do not adopt Supabase now

Supabase (Postgres) is technically a strong fit — RLS, real full-text search (on the roadmap already), pgvector if semantic Word Radar/RAG features happen later, an official Flutter SDK. But adopting it *in this same effort* would mean rewriting Auth (Google Sign-In), Firestore sync, and security rules→RLS on **both** the new web app and the already-live Flutter mobile app simultaneously with the frontend rewrite — two large risks stacked at once, over data real users already have.

**Decision: keep Firestore + Firebase Auth as the single source of truth.** The React web app talks to Firebase the same way mobile does (via the backend layer using Firebase Admin SDK, or the Firebase JS SDK directly where appropriate). Supabase remains a candidate for a future, standalone migration project if a concrete need justifies it — not bundled with this one.

### 3.4 STT / TTS — move server-side

Reasoning is **quality/consistency, not speed**: the Web Speech API (browser TTS/STT) is inconsistent across browsers/OS, often lacking decent Vietnamese voices, and has no reliable STT path for a future shadowing-practice feature. Server-side models (e.g. OpenAI TTS/Whisper-class APIs, or Google Cloud TTS/STT) give one consistent experience across every browser. Flutter mobile keeps `flutter_tts` (native OS voices are fine there) — this change is web-specific.

### 3.5 LLM prompt calls — move server-side, keep BYOK

Moved server-side for **security/control, not speed** (one extra network hop costs tens of ms against multi-second generation times — negligible). What it actually buys: the raw provider API key never appears in a request to a third-party domain from the browser; validation/retry logic (like `Part7Source._hasValidShape`) centralizes in one place instead of duplicating per client; streaming and rate/cost control become possible.

**Key handling — BYOK preserved, no server-side storage:**
- The user still supplies their own Gemini/Groq/OpenRouter key (as today).
- The key is stored **only on the user's device** (as today) — never persisted in the DB, encrypted or otherwise.
- On each AI-backed request, the client sends the key in a request **header** (never a URL query string, which would leak into logs). The Vercel function uses it in-memory for that one upstream call and never logs or caches it.
- **Threat model note (recorded for future readers, not a to-do):** this does not hide the key from someone with DevTools access to the *user's own browser* — nothing can, since the browser must send the key to reach any server. It protects against the key being logged/exposed to *other* parties and centralizes validation. Real damage-limitation comes from **provider-side spend/rate caps** (set on the Gemini/Groq/OpenRouter dashboard), not from the transport mechanism.
- A short-lived session-token optimization (server issues a TTL'd token after the first key submission, client resends that instead of the raw key on subsequent calls, backed by Vercel KV/Upstash with auto-expiry — never a permanent DB row) was discussed as a possible future polish. **Not adopted now** — logged here as a deferred nice-to-have (§9), not a requirement.

### 3.6 Rollout / migration plan

Flutter Web (`lexi-core.web.app`) **stays live and unchanged** throughout development. The React app deploys to a Vercel preview/staging URL first. The production domain only cuts over to React after it's been tested thoroughly — this is a deliberate, explicit gate, not an incidental detail.

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
| Frontend framework | Next.js on Vercel, not a plain Vite SPA | Colocates frontend + API layer in one deploy; Vercel is built around it |
| Database | Keep Firebase, defer Supabase | Avoids stacking a DB migration (Auth + Firestore→Postgres + RLS, across both mobile and web) on top of a frontend rewrite; Supabase remains a candidate for a later, isolated project |
| STT/TTS | Move server-side | Web Speech API is inconsistent cross-browser; server models give one consistent experience. Not about speed. |
| LLM prompt calls | Move server-side, BYOK key never stored in DB | Hides the key from third-party domains and centralizes validation/streaming; storing keys server-side would create a single high-value breach target disproportionate to this app's scale |
| Rollout | Flutter Web stays live; React ships to staging first, production cutover only after testing | Explicit user requirement — no accidental simultaneous kill of the working site |
| Visual direction | Bloom (Warm Modern) over Playful/Gamified or Editorial Minimalist | Best fit for an adult/professional TOEIC-prep audience that still wants encouragement, not clinical minimalism or high-energy gamification |
| Vocab detail pattern | Side Drawer over centered modal or tabbed modal | Keeps reading/list context visible behind it — important specifically for the "tra từ giữa lúc đọc passage" use case |
| Part 5/6 mockups | Not built separately; Part 7 stands in | Same MC session/result shape; building 3 near-identical mockups wasn't worth the redundancy |

---

## 9. Deferred / Open Follow-ups

- **Supabase migration** — revisit only as its own isolated project, if a concrete need (full-text search, pgvector/RAG, heavy relational queries) materializes.
- **BYOK session-token optimization** — issuing a short-lived, TTL'd token after first key submission (via Vercel KV/Upstash) instead of resending the raw key every request. Logged as a possible polish, not required.
- **Responsive/mobile-web breakpoints** — all 12 screens are desktop-only mockups; a narrow-viewport pass is separate future work.
- **Full SM-2 detail view** (ease factor, review history chart) — explored in the Variant C tabbed-modal mockup but not carried into the chosen Side Drawer pattern. Revisit if users want it.

---

## 10. Implementation Note (decomposition)

This spec is intentionally broad and covers two logically separable workstreams that should become **separate plans** under `writing-plans`, not one:

1. **Backend/infra migration** — Next.js + Vercel scaffold, the STT/TTS/LLM-proxy API endpoints, BYOK header-passthrough wiring, staging deploy.
2. **React frontend build-out** — the Bloom design system as real components/tokens, then the screen inventory in §6, roughly in the order: Vocab Bank + Side Drawer (the most-explored pattern) → Dashboard/Lookup/Practice hub → Đọc/Nghe hubs and their session/result screens → Cài đặt.

Plan 2 depends on Plan 1's API endpoints existing (or working stubs) before session/result screens can be wired to real data.
