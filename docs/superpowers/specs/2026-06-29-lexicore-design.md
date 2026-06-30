# LexiCore — Design Spec

**Date:** 2026-06-29
**Status:** Approved

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
|---|---|
| Native language | Vietnamese (fixed) |
| Target languages | English (default), 中文, 한국어, 日本語 |
| Lookup direction | VI → Target, or Target → VI |

Users switch target language in Settings. The active target language persists across sessions.

---

## 4. Features

### 4.1 Dictionary Lookup

The primary screen. User types a word, phrase, or full sentence. The app detects input type and returns a result suited to what was entered.

**Input type detection (heuristic):**

- **Word:** single token (no spaces), or known compound with no verb structure
- **Phrase:** 2–4 words, idiomatic or collocational unit (e.g. "follow up", "break a leg")
- **Sentence:** 5+ words, or contains terminal punctuation (. ? !), or has clear subject-verb structure

Detection runs client-side via heuristic first; Gemini classifies ambiguous cases when AI is ON.

---

**Word / Phrase result fields:**

- Headword / phrase
- IPA phonetic transcription
- Play pronunciation button (word/phrase-level TTS)
- Meaning / definition
- Example sentence(s)
- Play pronunciation button (sentence-level TTS)
- Active Context label (see §4.5)
- Suggested topic tag(s)
- Save button + Edit before save

**Sentence result fields (lightweight — no save):**

- Original sentence
- Translation
- Play pronunciation button (full sentence TTS)

---

**Discover button** — placed adjacent to the search input. Tapping it asks AI to generate a new word the user has not yet saved, matched to the current level and active context. User reviews the result and can Save or Skip (regenerate). Discover only generates words and phrases — not sentences.

**Edit before save** — on word/phrase results, all fields except IPA and the headword itself are editable before saving. This lets users simplify AI-generated definitions or replace example sentences with ones that feel more natural.

**AI toggle** — when AI is ON, Gemini Flash generates all fields. When AI is OFF, the app falls back to Free Dictionary API for English lookups only. For non-English target languages (中文, 한국어, 日本語), AI must be ON — the toggle is disabled with a tooltip explaining this constraint. Toggle lives in Settings and is reflected in a persistent status indicator.

### 4.2 Vocabulary Bank

A personal collection of saved words and phrases. Sentences are never saved here.

**VocabRecord fields:**

| Field | Editable after save |
|---|---|
| Type (word / phrase) | No (set at save time) |
| Headword / phrase | No |
| IPA | No |
| Meaning | Yes |
| Example sentences | Yes (add, edit, delete) |
| Topic tags (max 2) | Yes |
| Personal notes | Yes |
| Language pair | No (set at save time) |

**Filtering & browsing:** filter by type (word/phrase), topic, language pair, date added, level. Search within saved entries.

### 4.3 Topic System

Topics categorize saved vocabulary. Two tiers:

**Predefined topics (20) — cannot be deleted:**
> Daily Life · Travel · Food & Drink · Business · Technology · Health · Education · Entertainment · Nature · Emotion · Academic · Idioms · Phrasal Verbs · Slang · Social/Casual · Sports · Art & Culture · Science · Law & Politics · Other

**Custom topics — user-created, deletable:**
- No hard cap on count; recommended to keep under 30 for usability
- When a custom topic is deleted, all words in it are automatically reassigned to **"Other"** — no words are lost

**Rules:**

- Each word or phrase can have a maximum of 2 topic tags
- When saving, Gemini suggests topic(s) based on the active context; user can confirm or change from the full list
- Topic suggestions are constrained to the predefined + user-created list — no free-form tag creation to prevent tag explosion

### 4.4 Spaced Repetition Review

Flashcard-based review using the **SM-2 algorithm** (same algorithm as Anki).

- Cards are scheduled based on user performance (Again / Hard / Good / Easy)
- Review performance feeds into the level auto-adjustment system (§4.6)
- Users can edit a word's fields directly from the review card

### 4.5 Active Context

A persistent, session-level context selector that shapes AI output for both Lookup and Discover.

**Available contexts (~8):**
> General · Business · Technology · Travel · Food & Drink · Health · Academic · Social/Casual

**How it works:**
- Active context is always visible on the Lookup screen (e.g., `[💼 Business ▾]`), tappable to change at any time
- Context is injected into the Gemini prompt: *"Generate example sentences for [word] in a business context, formal register"*
- The active context also becomes the primary topic suggestion for the saved word
- User can always override the topic tag independently of context

### 4.6 Auto Exercises

Gemini Flash generates exercises from the user's saved vocabulary.

**Exercise types:**
- Fill-in-the-blank (word → sentence with gap)
- Multiple choice (meaning → word, or word → meaning)

**Difficulty:** matched to the user's current level (§4.7). Generated examples respect the active context.

**Level feedback loop:** exercise results (% correct, streaks) are used to adjust the user's estimated level over time.

### 4.7 User Level

CEFR scale: A1 · A2 · B1 · B2 · C1 · C2

**Initial level:** user self-declares during onboarding. No placement test — avoids friction for a personal tool.

**Auto-adjustment:** the system observes:
- Exercise accuracy over a rolling window
- Words looked up repeatedly (signal: not yet internalized → content may be above current level)
- Discover skips (too easy / too hard signal)

Level is always visible in the user profile. Users can manually override at any time.

### 4.8 Settings

| Setting | Options |
|---|---|
| Target language | English (default) · 中文 · 한국어 · 日本語 |
| Native language | Vietnamese (fixed for now) |
| AI toggle | On / Off |
| Gemini API key | User-provided |
| Active context | Persistent selector (also on Lookup screen) |
| Level | A1–C2, self-declared + auto-adjusted |
| Theme | Light / Dark / System |

---

## 5. Architecture

### 5.1 Platform

- **Flutter** — cross-platform (iOS, Android; desktop later if needed)
- **Riverpod** — state management

### 5.2 Clean Architecture Layers

```text
Presentation  ── Flutter UI + Riverpod providers
Domain        ── Use cases, Entities, Repository interfaces
Data          ── Repository implementations
               ├── Local: Hive (offline-first, primary storage)
               ├── Remote: Firebase Firestore (sync & backup)
               └── API:
                    ├── Gemini Flash (AI features)
                    ├── Free Dictionary API (AI-off fallback)
                    └── flutter_tts (pronunciation, offline)
```

### 5.3 Folder Structure

```text
lib/
├── core/
│   ├── theme/
│   ├── router/
│   ├── di/              (dependency injection)
│   └── utils/
├── features/
│   ├── dictionary/      (lookup, discover, context selector)
│   ├── vocabulary/      (bank, word detail, edit)
│   ├── topics/          (predefined + custom topic management)
│   ├── review/          (spaced repetition, SM-2 scheduler)
│   ├── exercises/       (AI exercise generation + scoring)
│   └── settings/        (language, level, AI toggle, theme)
└── main.dart
```

### 5.4 Data Sources

| Source | Purpose | Cost |
|---|---|---|
| Hive | Primary local storage | Free |
| Firebase Firestore | Cloud sync & backup | Free tier (1 GB, 50K reads/day) |
| Gemini Flash | AI generation (meaning, examples, exercises, discover) | Free (1,500 req/day) |
| Free Dictionary API | Fallback when AI is OFF | Free |
| flutter_tts | Word & sentence pronunciation | Free, offline |

---

## 6. Data Model (Key Entities)

### VocabRecord

```dart
id: String
type: InputType              // word | phrase
headword: String
languagePair: LanguagePair   // e.g., EN→VI
meaning: String
ipa: String
examples: List<String>
topics: List<String>         // max 2, references topic ids
personalNotes: String
level: CEFRLevel             // level at time of save
context: AppContext          // active context at time of save
createdAt: DateTime
nextReviewAt: DateTime       // SM-2 scheduling
sm2Data: SM2Data             // interval, ease factor, repetitions
```

### Topic

```dart
id: String
name: String
isPredefined: bool           // predefined topics cannot be deleted
createdAt: DateTime
```

### UserProfile

```dart
nativeLanguage: Language     // Vietnamese (fixed)
targetLanguage: Language     // user-selected
level: CEFRLevel             // self-declared, auto-adjusted
activeContext: AppContext
aiEnabled: bool
geminiApiKey: String
```

---

## 7. Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| No backend server | Firebase direct from Flutter | Zero hosting cost, sufficient for personal + small sharing |
| AI provider | Gemini Flash | Free tier (1,500 req/day), good quality |
| Spaced repetition algorithm | SM-2 | Proven, simple to implement, same as Anki |
| Topic explosion prevention | Predefined list + max 2 tags/word | User-created tags allowed but constrained |
| Deleted custom topic behavior | Words auto-reassigned to "Other" | No data loss, no friction |
| Level assessment | Self-declare + auto-adjust | Avoids placement test friction for personal app |
| TTS engine | flutter_tts | Offline, free, multi-language support |
| Pronunciation fields | Word-level + sentence-level | Core requirement for language learning |
| Input types | Word/phrase → full flow; sentence → translate + TTS only | Sentences don't need spaced repetition; keeping flows separate reduces complexity |
| Sentence not saveable | By design | A sentence is context-specific; saving it would clutter the Vocabulary Bank without learning benefit |
| Input type detection | Heuristic (word count + punctuation) + Gemini fallback | Simple cases handled locally; edge cases delegated to AI when available |

---

## 8. Out of Scope (v1)

- Multi-user / social features
- Custom backend server
- Native language other than Vietnamese
- Listening comprehension exercises (audio-in)
- Speaking / pronunciation scoring
- Import from Anki or other apps
- Web version
