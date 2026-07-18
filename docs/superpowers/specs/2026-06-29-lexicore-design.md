# LexiCore Plan 1 — Foundation + Dictionary Lookup Design Spec

**Date:** 2026-06-29
**Status:** Approved
**Covers:** Plan 1 (Foundation + Dictionary Lookup). See sibling specs for Plans 2–5.

> **⚠️ Updated 2026-07-18:** The context-selector UI (the `AppContext` chip row under the search bar) described below was reworked into a `FilterTile` + bottom-sheet picker. See [2026-07-18 UI/UX Polish Update](2026-07-18-ui-ux-polish-update-design.md) §3.5 before touching `context_selector_widget.dart`.

---

## 1. Problem Statement

Existing language learning apps (Duolingo, ELSA Speak, etc.) follow rigid, pre-defined curricula. Users are guided through a fixed path rather than learning at their own pace and context. LexiCore solves this by putting the user in control: look up any word at any time, in any supported language pair, shaped by the context that matters to them.

---

## 2. Core Concept

**LexiCore** is a personal vocabulary-driven language learning app. Users can look up a word, phrase, or full sentence — each returns a different level of result suited to what was entered.

**Word / Phrase core loop:**

```text
Lookup word or phrase → View rich result (meaning + IPA + pronunciation + examples)
    → Save to Vocabulary Bank → Review via Spaced Repetition
    → Practice with Auto-generated Exercises
```

**Sentence flow (lightweight):**

```text
Input full sentence → Translation + play pronunciation → done (no save)
```

Users define their own learning path. AI augments — it does not dictate.

---

## 3. Language Support

| Role | Languages |
| --- | --- |
| Native language | Vietnamese (fixed) |
| Target languages | English (default), 中文, 한국어, 日本語 |
| Lookup direction | VI → Target, or Target → VI |

Users switch target language in Settings. The active target language persists across sessions.

---

## 4. Features (Plan 1 scope)

### 4.1 Dictionary Lookup

The primary screen. User types a word, phrase, or full sentence. The app detects input type and returns a result suited to what was entered.

**Input type detection (heuristic):**

- **Word:** single token (no spaces), or known compound with no verb structure
- **Phrase:** 2–4 words, idiomatic or collocational unit (e.g. "follow up", "break a leg")
- **Sentence:** 5+ words, or contains terminal punctuation (. ? !), or has clear subject-verb structure

Detection runs client-side via heuristic first; Gemini classifies ambiguous cases when AI is ON.

**Word / Phrase result fields:**

- Headword / phrase
- IPA phonetic transcription
- Play pronunciation button (word/phrase-level TTS)
- Meaning / definition
- Example sentence(s)
- Play pronunciation button (sentence-level TTS)
- Active Context label (see §4.2)
- Suggested topic tag(s)
- Save button + Edit before save

**Sentence result fields (lightweight — no save):**

- Original sentence
- Translation
- Play pronunciation button (full sentence TTS)

**Discover button** — placed adjacent to the search input. Tapping it asks AI to generate a new word the user has not yet saved, matched to the current level and active context. User reviews the result and can Save or Skip (regenerate). Discover only generates words and phrases — not sentences.

**Edit before save** — on word/phrase results, all fields except IPA and the headword itself are editable before saving. This lets users simplify AI-generated definitions or replace example sentences with ones that feel more natural.

**AI toggle** — when AI is ON, Gemini Flash generates all fields. When AI is OFF, the app falls back to Free Dictionary API for English lookups only. For non-English target languages (中文, 한국어, 日本語), AI must be ON — the toggle is disabled with a tooltip explaining this constraint. Toggle lives in Settings and is reflected in a persistent status indicator.

### 4.2 Active Context

A persistent, session-level context selector that shapes AI output for both Lookup and Discover.

**Available contexts (~8):**
> General · Business · Technology · Travel · Food & Drink · Health · Academic · Social/Casual

**How it works:**
- Active context is always visible on the Lookup screen (e.g., `[💼 Business ▾]`), tappable to change at any time
- Context is injected into the Gemini prompt: *"Generate example sentences for [word] in a business context, formal register"*
- The active context also becomes the primary topic suggestion for the saved word
- User can always override the topic tag independently of context

### 4.3 Settings (Plan 1 scope)

| Setting | Options |
| --- | --- |
| Target language | English (default) · 中文 · 한국어 · 日本語 |
| Native language | Vietnamese (fixed for now) |
| AI toggle | On / Off |
| Gemini API key | User-provided |
| Active context | Persistent selector (also on Lookup screen) |

---

## 5. Architecture

### 5.1 Platform

- **Flutter** — iOS and Android
- **Riverpod 2.x** — state management with `@riverpod` annotation
- **GoRouter** — navigation
- **Clean Architecture** — domain / data / presentation layers

### 5.2 Layer Structure

```text
Presentation  ── Flutter UI + Riverpod providers
Domain        ── Use cases, Entities, Repository interfaces
Data          ── Repository implementations
               ├── Local: Hive (offline-first, primary storage)
               ├── Remote: Firebase Firestore (sync & backup, Plan 4+)
               └── API:
                    ├── Gemini Flash (AI features)
                    ├── Free Dictionary API (AI-off fallback, English only)
                    └── flutter_tts (pronunciation, offline)
```

### 5.3 Folder Structure

```text
lib/
├── core/
│   ├── theme/
│   ├── router/
│   ├── di/              (dependency injection via Riverpod)
│   └── utils/
├── features/
│   ├── dictionary/      (lookup, discover, context selector)
│   ├── vocabulary/      (bank, word detail, edit — Plan 2)
│   ├── practice/        (spaced repetition + exercises — Plan 3)
│   └── settings/        (language, level, AI toggle, theme — Plan 4)
└── main.dart
```

### 5.4 Data Sources

| Source | Purpose | Cost |
| --- | --- | --- |
| Hive | Primary local storage | Free |
| Firebase Firestore | Cloud sync & backup (Plan 4+) | Free tier (1 GB, 50K reads/day) |
| Gemini Flash | AI generation (meaning, examples, exercises, discover) | Free (1,500 req/day) |
| Free Dictionary API | Fallback when AI is OFF | Free |
| flutter_tts | Word & sentence pronunciation | Free, offline |

---

## 6. Data Model

### UserProfile (Plan 1)

```dart
nativeLanguage: Language     // Vietnamese (fixed)
targetLanguage: Language     // user-selected
activeContext: AppContext
aiEnabled: bool
geminiApiKey: String         // stored locally only, never synced
```

> VocabRecord and Topic entities are defined in Plan 2 spec.

---

## 7. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| No backend server | Firebase direct from Flutter | Zero hosting cost, sufficient for personal + small sharing |
| AI provider | Gemini Flash | Free tier (1,500 req/day), good quality |
| TTS engine | flutter_tts | Offline, free, multi-language support |
| Input type detection | Heuristic (word count + punctuation) + Gemini fallback | Simple cases handled locally; edge cases delegated to AI |
| Sentence not saveable | By design | A sentence is context-specific; saving it would clutter the Vocabulary Bank without learning benefit |
| Input types | Word/phrase → full flow; sentence → translate + TTS only | Sentences don't need spaced repetition; keeping flows separate reduces complexity |

---

## 8. Out of Scope (v1)

- Multi-user / social features
- Custom backend server
- Native language other than Vietnamese
- Listening comprehension exercises (audio-in)
- Speaking / pronunciation scoring
- Import from Anki or other apps
- Web version
