# Knowledge Notes ("Kiến thức") — Design

**Date:** 2026-09-06
**Status:** Design — approved in brainstorming, pending spec review
**Platforms:** Flutter (mobile) + React web (`apps/web/`), same release

---

## 1. Summary

A new **"Kiến thức"** section: a per-language reference library of structured
grammar / sentence-structure notes ("thì", "câu điều kiện", "mệnh đề quan hệ",
common spoken structures, …).

The user can:

- **Read / browse / search** notes, organised into a fixed per-language group
  taxonomy.
- **Write a note by hand.**
- **Ask AI to draft a note** from a free-text request ("Giải thích câu điều
  kiện loại 2 và 3, khi nào dùng cái nào"), review/edit the draft, then save.
- Get a **starter library of ~10–12 basic English grammar notes** seeded into
  their account automatically.

First version is **reference only** — no SM-2, no "practice this note", no
flashcards from notes. The data model leaves room to add a "Luyện cái này"
button later (an AI exercise generated from a note, SM-2-neutral like Part
5/6/7), but that is explicitly out of scope now.

### Why build it

- The app is strong on *vocabulary* (Vocab Bank + SM-2) and *skills*
  (reading/listening/typing) but has **no home for grammar knowledge**. Today
  the user leaves the app to look up "how do I use the third conditional".
- It **reuses existing patterns** almost entirely: AI drafts structured JSON
  (like `LookupResult` / `Exercise`), saved content lives in a flat Firestore
  collection shared shape-for-shape with web (like `reading_exercises` /
  `listening_exercises`), review-before-save mirrors the Dictionary save sheet
  and Word Radar suggestions, filters mirror Vocab Bank.

### Architectural approach

Follow `SavedExercisesService` (`lib/core/services/saved_exercises_service.dart`)
exactly: a plain service class talking to `FirebaseFirestore.instance`
directly — **no Hive box, no `SyncService` involvement** for this collection.
Flutter and web both read/write `users/{uid}/knowledge_notes` directly. This is
the same trust model already used for saved exercises and is what the user
asked for ("lưu vào Firestore hết, không lưu local").

---

## 2. Data model

### Firestore: `users/{uid}/knowledge_notes/{id}`

```
id: string                          // duplicated into the doc body (matches
                                    //   SavedExercisesService convention)
title: string
summary: string                     // 1–2 sentences. Shown in list rows AND
                                    //   used by the duplicate-check haystack
explanation: string                 // \n\n = paragraph break, **x** = bold.
                                    //   Nothing else. See §6.
patterns: string[]                  // e.g. "If + S + V-past, S + would + V"
                                    //   rendered verbatim (monospace-ish), not parsed
examples: { text: string, translation: string }[]
                                    //   bilingual; known vocab highlighted (reuse
                                    //   existing bilingual-sentence widget)
pitfalls: string[]                  // each item also parsed for \n\n + **bold**
groupId: string                     // stable key from the targetLanguage taxonomy
                                    //   (§3), e.g. "en_tenses"
tags: string[]                      // free-form; compared accent-folded
cefrLevel: string | null            // "a1".."c2" (lowercase, matches CEFRLevel.name)
targetLanguage: string              // Language.name — "english" | "chinese" |
                                    //   "korean" | "japanese" | "vietnamese",
                                    //   matching reading_exercises/listening_exercises
source: "ai" | "manual" | "starter"
sourcePrompt: string | null         // most recent request that created/edited it
                                    //   (reference only; no prompt history)
createdAt: string                   // ISO-8601 UTC (matches SavedExercisesService)
updatedAt: string                   // ISO-8601 UTC
```

Notes:

- **Flat JSON**, no nested entities beyond `examples`. A Dart model and a TS
  type mirror each other; a note saved on one platform opens on the other.
- **No version history.** "Bổ sung vào ghi chú" overwrites the note in place and
  bumps `updatedAt`.
- **No special Firestore index.** The whole `knowledge_notes` collection for the
  signed-in user is loaded and filtered client-side (small set, exactly like
  vocab records and saved exercises).
- Firestore security rules already cover this: `users/{uid}/{document=**}` —
  **no rules change needed.**

### Seeded flag: `users/{uid}/knowledge_meta/seed`

A dedicated one-document collection (the existing `settings/config` doc is
owned by `AiSettingsSyncService` and merged by both platforms — keep the
seeding flag out of it). Shape:

```
{ english?: boolean, chinese?: boolean, korean?: boolean,
  japanese?: boolean, vietnamese?: boolean }
```

Keyed by `Language.name`. Only English has starter content in v1, so in
practice only `english` is ever set. Covered by the existing
`users/{uid}/{document=**}` rule — no rules change.

---

## 3. Group taxonomy (fixed, per language)

The **target language selected in Settings** decides which group set is shown
(same "per-language" model as `vocab_records`). Groups are **app-defined and not
user-editable**. Users get unlimited notes and unlimited free-form **tags** for
cross-cutting slices (`#toeic`, `#hay-nhầm`, `#văn-nói`); the "Khác" group is the
escape hatch for anything that fits no group.

`groupId` stores a **stable key**; the display label is looked up from a table
in code, so relabelling never breaks stored data.

### English (`en`)

| key | label |
|---|---|
| `en_tenses` | Thì |
| `en_conditionals` | Câu điều kiện |
| `en_relative_clauses` | Mệnh đề quan hệ |
| `en_passive` | Câu bị động |
| `en_reported_speech` | Câu tường thuật |
| `en_modals` | Động từ khuyết thiếu |
| `en_gerunds_infinitives` | Danh động từ & Nguyên mẫu |
| `en_articles_nouns` | Mạo từ & Danh từ |
| `en_prepositions` | Giới từ |
| `en_conjunctions_linking` | Liên từ & Nối câu |
| `en_spoken_structures` | Cấu trúc nói thông dụng |
| `en_other` | Khác |

### Chinese (`zh`)

| key | label |
|---|---|
| `zh_aspect_particles` | Thể & Trợ từ động thái (了/着/过) |
| `zh_complements` | Bổ ngữ (kết quả/xu hướng/khả năng/mức độ) |
| `zh_ba` | Câu chữ 把 |
| `zh_bei` | Câu chữ 被 (bị động) |
| `zh_measure_words` | Lượng từ |
| `zh_modal_particles` | Trợ từ ngữ khí (吗/呢/吧/啊) |
| `zh_comparison` | Cấu trúc so sánh (比/没有/一样) |
| `zh_conjunctions` | Liên từ & Phức câu |
| `zh_word_order` | Trật tự từ & Trạng ngữ |
| `zh_spoken_structures` | Cấu trúc nói thông dụng |
| `zh_other` | Khác |

### Korean (`ko`)

| key | label |
|---|---|
| `ko_particles` | Trợ từ (조사) |
| `ko_endings_honorifics` | Đuôi câu & Kính ngữ (존댓말/반말) |
| `ko_tense_aspect` | Thì & Thể |
| `ko_clause_connectors` | Liên kết vế câu (연결어미) |
| `ko_modifiers` | Định ngữ (관형사형) |
| `ko_grammar_patterns` | Mẫu ngữ pháp thông dụng |
| `ko_irregulars` | Bất quy tắc (불규칙 활용) |
| `ko_spoken_structures` | Cấu trúc nói thông dụng |
| `ko_other` | Khác |

### Japanese (`ja`)

| key | label |
|---|---|
| `ja_particles` | Trợ từ (助詞) |
| `ja_verb_forms` | Chia động từ (辞書形/て形/た形…) |
| `ja_politeness_keigo` | Thể lịch sự & Kính ngữ (敬語) |
| `ja_tense_aspect` | Thì & Thể |
| `ja_connectors` | Liên kết câu (接続) |
| `ja_grammar_patterns` | Mẫu ngữ pháp (文型) |
| `ja_voice` | Khả năng / Bị động / Sai khiến |
| `ja_spoken_structures` | Cấu trúc nói thông dụng |
| `ja_other` | Khác |

### Vietnamese target (`vi`) — minimal

| key | label |
|---|---|
| `vi_sentence_structure` | Cấu trúc câu |
| `vi_word_classes` | Từ loại & chức năng |
| `vi_linking` | Liên kết câu |
| `vi_spoken_structures` | Cấu trúc nói thông dụng |
| `vi_other` | Khác |

---

## 4. Screens & navigation

**Entry point (Flutter):** a **card "Kiến thức"** in the **"Luyện tập" hub**,
below "Quét từ vựng" (Word Radar). **Entry point (web):** a **"Kiến thức"**
sidebar item, sibling of "Quét từ vựng".

### 4.1 KnowledgeHomeScreen — `/knowledge`

- Top: **search field** + a **tag chip row** (only tags that currently have
  notes in the active language).
- Body: **grid of group cards** for the active language — group label + note
  count. Empty groups still render (dimmed, count 0).
- Actions: **"+ Nhờ AI soạn"** and **"+ Tự viết"**.
- Typing in the search field switches the body to a **flat result list** across
  all groups: each row = title + summary + group/CEFR chips.
- **Empty state** (no notes at all for the active language, after any seeding):
  a few example prompts + a prominent "Nhờ AI soạn" button.
- **Overflow menu:** "Khôi phục ghi chú mẫu" (English only; §7).

### 4.2 KnowledgeGroupScreen — `/knowledge/group/:groupId`

- Notes in the group, **sectioned by CEFR** (A1 → C2, then "Chưa gắn cấp độ").

### 4.3 KnowledgeDetailScreen — `/knowledge/note/:id`

Render order:

1. title
2. summary
3. explanation — paragraphs, with **bold** runs (§6)
4. **Mẫu câu** (patterns) — only if non-empty
5. **Ví dụ** — bilingual list, known vocab highlighted (reuse existing widget)
6. **Lỗi thường gặp** (pitfalls) — only if non-empty
7. chips: group · CEFR · tags · a small "Mẫu" chip if `source == "starter"`

AppBar: **Sửa** · **Xoá** (confirm dialog).

### 4.4 KnowledgeEditScreen

One form shared by **write-by-hand / edit / review-AI-draft**:

- `title`, `summary` — text fields
- `explanation` — multiline field + hint *"bọc `**...**` để in đậm"*
- `patterns`, `pitfalls` — add/remove string rows
- `examples` — add/remove `{text, translation}` rows
- `groupId` — required, single-select from the active language taxonomy
  (`showSingleSelectSheet`)
- `cefrLevel` — optional single-select
- `tags` — free-form add/remove

"Review-AI-draft" mode = the same form pre-filled from the AI response, plus a
banner indicating it is an unsaved draft. Nothing is written to Firestore until
**Lưu**.

---

## 5. AI "Nhờ AI soạn" flow

### 5.1 Steps

1. **Request sheet:** free-text request field + optional hints (group, CEFR;
   may be left blank for the AI to infer).

2. **Layer 1 — local duplicate check, BEFORE any AI call** (§5.2). If one or
   more existing notes score at/above threshold, show a banner *"Bạn đã có N
   ghi chú liên quan"* with up to 3 cards. Each card: **Mở** · **Bổ sung vào
   ghi chú này**; plus a shared **Vẫn tạo mới** action.
   - **Mở** → leave the flow, open that note.
   - **Bổ sung** → continue to the AI call, passing the old note's full content;
     on save, **overwrite that note's id**.
   - **Vẫn tạo mới** → continue, create a new id.

3. **AI call:** a new `KnowledgeNoteSource` using `AiClientFactory` /
   `GenerativeModelClient` → Cloud Function `generateContent` (identical wiring
   to every other AI source; see README "Luồng dữ liệu AI"). The prompt
   includes: the user request, target language, the language's group taxonomy,
   and a list of `{id, title, summary}` for **existing notes in the same
   group + language** (for Layer 2). For "Bổ sung", also the old note body.

4. **AI response JSON:**
   ```
   { title, summary, explanation, patterns[], examples[], pitfalls[],
     suggestedGroupId, suggestedCefr | null, suggestedTags[],
     relatedNoteId | null }
   ```
   `relatedNoteId` is **Layer 2** — the AI flags a substantive duplicate that
   Layer 1's string match missed (synonyms, cross-language: "second
   conditional" vs "câu điều kiện loại 2").

5. If `relatedNoteId` is set and Layer 1 did **not** already warn, show the same
   3-choice banner now (Mở / Bổ sung / Vẫn tạo mới), pre-targeted at that note.

6. Open **KnowledgeEditScreen in review mode**, pre-filled (`suggested*` →
   the corresponding fields, editable). On **Lưu**:
   - "Bổ sung" → `set` on the existing id, `source` unchanged unless it was
     `starter` (then → `ai`), `updatedAt` bumped.
   - otherwise → new id, `source: "ai"`.
   - `sourcePrompt` = the request just typed.

### 5.2 Layer 1 — local tokeniser & match (Dart + TS, shared logic)

**Who:** the app, in pure Dart / TS. **No AI.**

**`normalize(s)`** (shared with §7 search and reused everywhere a fold is
needed):

1. lowercase
2. strip Vietnamese diacritics (`đ→d`, `điều→dieu`, …)
3. remove every non-alphanumeric char (keep spaces)
4. collapse whitespace, trim

**Tokenise the request:**

1. `normalize()` → split on space
2. drop stopwords — a small fixed list:
   `và khi nào cho của là các một với thì dùng giải thích ví dụ đời thường cách`
   `the a an and or when how what explain give example`
   (final list refined during implementation; kept short)
3. build **bigrams and trigrams** from the surviving tokens (so "cau dieu kien"
   survives as a phrase)

**Score each existing note** (same active language) against
`haystack = normalize(title + " " + summary + " " + tags.join(" ") + " " + groupLabel)`:

| match | points |
|---|---|
| a request phrase (bi/trigram) is a substring of `haystack` | +3 |
| …and that phrase is a substring of the **title** specifically | +2 (additional) |
| a note tag equals a request token or phrase exactly | +3 |
| a single request token is a substring of `haystack` | +1 |

**Threshold: total score ≥ 3** → "possibly already exists". Show the top 3 by
score.

### 5.3 Error handling

`KnowledgeNoteSource` follows the existing best-effort convention: network
failure or unparseable JSON → a user-visible "không tạo được, thử lại" message,
nothing saved. No partial writes.

---

## 6. The `**bold**` mini-parser (shared Dart + TS)

Applied to `explanation` and to each `pitfalls` item. **Not** applied to
`patterns` or `examples` (rendered flat).

Rules:

- Split into paragraphs on `/\n\n+/`; trim each paragraph.
- Within a paragraph, scan for `**X**` where `X` is non-empty and contains no
  `**` (non-greedy) → a **bold run**. Text outside → normal runs.
- An unpaired `**` → rendered as the literal two characters; it does not
  "swallow" the rest of the text.
- **No other syntax.** Single `*`, `_`, `#`, `-`, `>`, `` ` `` are literal.
- No nesting, no italics, no links, no lists, no headings.

**Output:** `List<List<Run>>` (paragraphs → runs), `Run = { text, bold }`.

**Shared test vectors:** one JSON file `test/fixtures/bold_parser_vectors.json`
(input string → expected paragraph/run tree). The Dart test and the TS test both
load it. Cases include: plain text, multi-paragraph, one bold span, multiple
bold spans, bold at start/end, adjacent bold spans, unpaired `**` leading /
trailing / middle, `**` with no closing, empty `****`, literal `*`/`_`/`#`.

---

## 7. Search & filters

- **One search field**, local, accent-folded substring match (`normalize()`)
  over `title + summary + explanation + patterns + pitfalls + tags`.
- Filters, mirroring Vocab Bank:
  - **Language** — follows the Settings target language (not a separate
    control), same as Vocab Bank's per-language behaviour.
  - **Group**, **CEFR**, **tag** — multi-select chips.
- No server-side full-text, no Firestore composite index. Load the user's whole
  `knowledge_notes` collection, filter in memory.

---

## 8. Starter library (English only, v1)

### 8.1 Content source

Starter notes live in the repo as a **single shared JSON source** consumed by
both apps:

- Flutter: `assets/knowledge/starter_en.json` (registered in `pubspec.yaml`
  assets).
- Web: the same file imported by `apps/web/` (via a small build step or a
  copied/symlinked asset — decided in the plan; the **content** is authored
  once).

Each entry carries a **stable doc id** (`starter_en_present_perfect`, …) and the
full note shape from §2 with `source: "starter"`.

### 8.2 Seeding — lazy, per language, once

When the user opens Knowledge for language X and:

- `knowledge_notes` for X is **empty**, **and**
- `settings/user.knowledgeSeeded.X` is not `true`

then: write each starter note for X whose id **does not already exist** into
`users/{uid}/knowledge_notes`, and set `knowledgeSeeded.X = true`.

Only `en` has starter content in v1. Other languages: the flag is still set on
first open (with zero writes) so the check is cheap thereafter — or simply skip
languages with no starter set. (Plan picks the simplest correct option.)

### 8.3 "Khôi phục ghi chú mẫu"

Overflow-menu action on KnowledgeHomeScreen (shown only when the active language
has a starter set, i.e. English). Re-creates every starter note whose stable id
is **absent** (deleted by the user). Never overwrites a note that still exists,
so user edits to a starter note are safe.

### 8.4 Content updates in later releases

A newer app version with improved starter JSON does **not** push changes into
existing accounts (would clobber user edits). Only "Khôi phục" brings back
deleted ids. Accepted trade-off — versioning/merge machinery is YAGNI for a
personal app.

### 8.5 The ~10–12 English starter notes

Draft list (final wording authored in the plan / implementation, reviewed by the
user):

| id | title | group | CEFR |
|---|---|---|---|
| `starter_en_tenses_overview` | Tổng quan 12 thì tiếng Anh | `en_tenses` | a2 |
| `starter_en_present_simple` | Hiện tại đơn | `en_tenses` | a1 |
| `starter_en_present_continuous` | Hiện tại tiếp diễn | `en_tenses` | a1 |
| `starter_en_present_simple_vs_continuous` | Hiện tại đơn vs. tiếp diễn | `en_tenses` | a2 |
| `starter_en_past_simple` | Quá khứ đơn | `en_tenses` | a1 |
| `starter_en_present_perfect` | Hiện tại hoàn thành | `en_tenses` | a2 |
| `starter_en_present_perfect_vs_past` | Hiện tại hoàn thành vs. Quá khứ đơn | `en_tenses` | b1 |
| `starter_en_future_forms` | Các cách nói tương lai (will / be going to / present continuous) | `en_tenses` | a2 |
| `starter_en_conditionals_0_1` | Câu điều kiện loại 0 và 1 | `en_conditionals` | a2 |
| `starter_en_conditionals_2_3` | Câu điều kiện loại 2 và 3 | `en_conditionals` | b1 |
| `starter_en_articles` | Mạo từ a / an / the / zero | `en_articles_nouns` | a2 |
| `starter_en_comparatives_superlatives` | So sánh hơn và so sánh nhất | `en_articles_nouns` | a1 |

Each note is fully populated: `summary`, a `**bold**`-marked `explanation`,
2–4 `patterns`, 3–5 bilingual `examples`, 2–3 `pitfalls`, and 1–2 `tags`.

---

## 9. Testing

**Dart:**

- `**bold**` parser — the shared test vectors.
- Layer 1 tokeniser — normalize, stopword drop, bigram/trigram build, scoring,
  threshold.
- `KnowledgeNoteSource` — mock AI: valid JSON parses; malformed JSON →
  best-effort error, no throw.
- `KnowledgeNotesService` — CRUD against a fake Firestore; lazy seeding
  (seeds once, respects the flag, skips existing ids); "Khôi phục" restores
  only absent ids.
- Notifier — filtering (group/CEFR/tag), search, "Bổ sung" overwrites the same
  id.
- Widget — KnowledgeHomeScreen (grid + counts + empty state), DetailScreen
  (sections shown/hidden), EditScreen (validation: group required).

**TS (`apps/web/`):**

- `**bold**` parser — the *same* test vectors file.
- Layer 1 tokeniser.
- Components: list / detail / form / "Nhờ AI soạn" flow.

**Targets:** no drop in test counts; `flutter analyze` clean.

---

## 10. Out of scope (YAGNI)

- **No SM-2, no "Luyện cái này", no flashcards** from notes. (Data model leaves
  room; behaviour is not built.)
- No version history / undo.
- **No sharing notes between users.** (The starter library is bundled content,
  not user-to-user sharing.)
- No full Markdown — only `\n\n` and `**bold**`.
- No user-created groups — fixed taxonomy + free-form tags only.
- No offline support — direct Firestore; offline behaves like any other network
  call (fails, best-effort).
- No image / audio attachments.
- No deeper multi-language taxonomy work beyond §3.
- Starter library is **English only** in v1.

---

## 11. Open items for the plan

- Confirm the exact web mechanism for sharing the starter JSON and the parser
  test-vector file between `test/` (Flutter) and `apps/web/`.
- Confirm whether the "Luyện tập" hub card ordering / layout needs adjustment
  for a 4th card.
- Final stopword list and Layer 1 threshold tuning (start at ≥ 3, adjust if it
  proves noisy).
- Final wording of all 12 English starter notes.
