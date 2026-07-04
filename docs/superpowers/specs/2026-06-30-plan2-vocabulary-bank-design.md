# LexiCore Plan 2 — Vocabulary Bank + Topic System Design Spec

**Date:** 2026-06-30
**Status:** Approved
**Covers:** Plan 2 (Vocabulary Bank + Topic System).
**Depends on:** [Plan 1 spec](2026-06-29-lexicore-design.md) for architecture and folder structure.

---

## 1. Goal

Let users save looked-up words and phrases to a personal Vocabulary Bank, organize them by topic (20 predefined + custom), and view/edit entries — using Hive for offline-first local storage.

---

## 2. Features

### 2.1 Vocabulary Bank

A personal collection of saved words and phrases. Sentences are never saved here.

**VocabRecord fields:**

| Field | Editable after save |
| --- | --- |
| Type (word / phrase) | No (set at save time) |
| Headword / phrase | No |
| IPA | No |
| Meaning | Yes |
| Example sentences | Yes (add, edit, delete) |
| Topic tags (max 2) | Yes |
| Personal notes | Yes |
| Language pair | No (set at save time) |
| CEFR level | No (set at save time from user's current level) |
| Active context | No (set at save time) |

**Filtering & browsing:** filter by type (word/phrase), topic, language pair, date added, level. Search within saved entries.

**Save flow:** triggered from Dictionary Lookup result. All editable fields are pre-filled from the AI result; user can adjust before confirming. After saving, the button toggles to "Saved ✓".

### 2.2 Topic System

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

### 2.3 Navigation

Bottom navigation bar added in Plan 2 via GoRouter ShellRoute, exposing:
- Dictionary (existing, Plan 1)
- Vocab Bank (new, Plan 2)

Practice and Settings tabs added in later plans.

---

## 3. Data Model

### VocabRecord

```dart
id: String                   // uuid v4
type: InputType              // word | phrase (sentence never saved)
headword: String
languagePair: LanguagePair   // e.g., EN→VI
meaning: String
ipa: String
examples: List<String>
topics: List<String>         // max 2, references topic ids
personalNotes: String
level: CEFRLevel             // user's CEFR level at time of save
context: AppContext          // active context at time of save
createdAt: DateTime
nextReviewAt: DateTime?      // SM-2 scheduling (set in Plan 3)
sm2Interval: int             // SM-2 interval in days (set in Plan 3)
sm2EaseFactor: double        // SM-2 ease factor (set in Plan 3)
sm2Repetitions: int          // SM-2 repetition count (set in Plan 3)
```

**Storage:** Hive `Box<String>` with `jsonEncode/jsonDecode` — no Hive type adapters or code generation.

### Topic

```dart
id: String                   // uuid v4 for custom; slug for predefined
name: String
isPredefined: bool           // predefined topics cannot be deleted
createdAt: DateTime
```

**Storage:** Hive `Box<String>`, same pattern as VocabRecord. Predefined topics are seeded once on first run if the box is empty.

---

## 4. CEFR Level

CEFR scale used to tag each saved word at save time: A1 · A2 · B1 · B2 · C1 · C2

**Initial level:** user self-declares (no placement test — avoids friction for a personal tool). Level auto-adjustment based on exercise results is handled in Plan 3+.

---

## 5. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Sentence not saveable | By design | A sentence is context-specific; saving it would clutter the bank without learning benefit |
| Max 2 topic tags per word | Hard limit | Prevents over-tagging; forces users to choose the most relevant categories |
| Topic explosion prevention | Predefined list + constrained suggestions | Free-form tags create unusable noise at scale |
| Deleted custom topic behavior | Words auto-reassigned to "Other" | No data loss, no friction |
| Hive storage format | `Box<String>` + JSON | No code generation; simple to read/write; human-readable for debugging |
| Predefined topic seeding | On first open if box is empty | Idempotent; no migration needed |
| SM-2 fields on VocabRecord | Defined in Plan 2, populated in Plan 3 | Schema defined early so the Hive JSON is stable; Plan 3 just starts writing the fields |
