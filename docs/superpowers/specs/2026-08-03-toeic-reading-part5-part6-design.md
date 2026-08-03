# LexiCore — TOEIC "Đọc hiểu" Part 5 & Part 6 Design Spec

**Date:** 2026-08-03
**Status:** Approved
**Covers:** One plan — Part 5 (Incomplete Sentences) + Part 6 (Text Completion), both under a restructured `/reading` hub. Part 7 (Reading Comprehension) is explicitly deferred to its own future spec/plan.

**Depends on:** Plan 7 (Reading — this restructures its home route), Plan 10 (Nghe hiểu — this reuses its "generate once, answer all, submit" session pattern), Word Radar (reuses its vocab-suggestion use case in results).

---

## 1. Goal

Add two AI-generated TOEIC-style reading drills, matching the real exam format:

- **Part 5 — Incomplete Sentences**: a single sentence with one blank, 4 answer choices (grammar/vocabulary), pick the correct one.
- **Part 6 — Text Completion**: a short business document (email/memo/notice/letter/article) with 4 blanks, each with 4 answer choices — at least one blank per passage is a "choose the best sentence to insert" item, matching the real test.

Both are standalone AI generations — not sourced from Vocab Bank, no SM-2 impact — calibrated to **Economy TOEIC** volume difficulty (a well-known Vietnamese TOEIC prep book series) rather than the app's CEFR scale.

---

## 2. Scope & Non-Goals

- This spec covers **Part 5 + Part 6 only**. Part 7 (single/multi-passage reading comprehension) is a separate future plan — its route/card is not added yet.
- No Vocab Bank word count gate (unlike Reading/Dictation) — content is fully AI-generated, like Nghe hiểu.
- No SM-2 impact — there's no specific vocab word to attribute a grammar-question result to.
- No new mobile-tab-visibility setting — `/reading` is reached only via the "Luyện tập" hub's card (`practice_hub_screen.dart`), not a bottom-nav destination, so `AppShell` is untouched.

---

## 3. Difficulty — `EconomyVolume`

New enum replacing the CEFR-level filter for these two features only (Ngôn ngữ and Chủ đề/AppContext filters stay, since TOEIC content still spans several workplace-adjacent domains):

```dart
enum EconomyVolume {
  vol2, vol3, vol4, vol5;

  String get label => switch (this) {
    EconomyVolume.vol2 => 'Vol 2 · 500–600+',
    EconomyVolume.vol3 => 'Vol 3 · 650–750+',
    EconomyVolume.vol4 => 'Vol 4 · 800–900+',
    EconomyVolume.vol5 => 'Vol 5 · 900+',
  };

  /// Fed into the AI prompt to calibrate question style/difficulty.
  /// Deliberately part-agnostic — shared across Part 5, Part 6, and (later) Part 7.
  String get promptHint => switch (this) {
    EconomyVolume.vol2 => 'easy-medium difficulty, standard trap depth, close to or slightly easier than the real exam',
    EconomyVolume.vol3 => 'medium-high difficulty, some advanced vocabulary, longer passages',
    EconomyVolume.vol4 => 'high difficulty, equal to or harder than the real exam, longer/more complex passages, unusual grammar/vocabulary traps',
    EconomyVolume.vol5 => 'very high difficulty, dense advanced vocabulary and the deepest grammar traps',
  };
}
```

(Vol 1 intentionally excluded — user only wants Vol 2–5.)

### Multi-select

The setup screen's "Độ khó" filter is **multi-select** (`showMultiSelectSheet<EconomyVolume>`, same widget already used for Topic filters). Selected set is passed to the generation use case:

- Non-empty selection → prompt lists the selected volumes' `promptHint`s and asks the model to distribute questions roughly evenly and randomly across them.
- Empty selection → treated as "all 4 volumes" (same semantics as the existing empty-Topic-selection = "no filter" convention).

---

## 4. Part 5 — Incomplete Sentences

### 4.1 Entities

```dart
// lib/features/reading/domain/entities/part5_question.dart
final class Part5Question {
  final String sentenceWithBlank; // contains exactly one '___'
  final List<String> options;     // always 4
  final int correctIndex;         // 0-3
  final String explanation;       // why correct, briefly why others are wrong
}

final class Part5Set {
  final String id;
  final List<Part5Question> questions; // always 15
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

### 4.2 Generation

- `part5_source.dart` (new, mirrors `ListeningPassageSource`'s structure): one AI call returns all 15 questions as JSON, using `AiClientFactory` + `parseAiJsonObject`.
- Prompt asks for a realistic TOEIC Part 5 mix: word form, verb tense/agreement, prepositions, conjunctions, vocabulary-in-context — spread across the selected `EconomyVolume` hints.
- `GeneratePart5SetUseCase` (domain) wraps the source call.

### 4.3 Home screen (`Part5HomeScreen`)

Same shape as `ComprehensionHomeScreen`:

- FilterTile — Ngôn ngữ
- FilterTile — Chủ đề (AppContext)
- FilterTile — Độ khó (multi-select `EconomyVolume`, §3)
- Error state: AI disabled → prompt to enable
- "Tạo bài luyện" → generate → navigate to session

### 4.4 Session screen (`Part5SessionScreen`)

Single scrollable list of 15 `RadioListTile`-based question cards (sentence-with-blank as the prompt, 4 options). "Nộp bài" enabled once all 15 are answered (`canSubmit` on session state, same as `ListeningSessionState`).

### 4.5 Result screen (`Part5ResultScreen`)

- Score `X/15` header.
- Per-question breakdown (colored correct/incorrect, like `_QuestionBreakdown` in Nghe hiểu) **plus a new explanation line** under each question.
- `VocabSuggestionsSection` fed the concatenation of all 15 sentences (reuses `getVocabSuggestionsForTextUseCaseProvider` verbatim).
- `statsServiceProvider.recordPracticeSession(15)` for streak/stats.
- Buttons: "Bài khác" (regenerate) / "Về trang chính".

---

## 5. Part 6 — Text Completion

### 5.1 Entities

```dart
// lib/features/reading/domain/entities/part6_passage.dart
final class Part6Question {
  final List<String> options; // always 4 — may be words/phrases OR full sentences
  final int correctIndex;
  final String explanation;
}

final class Part6Passage {
  final String passageText; // blanks inline, e.g. "... the office (131)___ Monday ..."
  final List<Part6Question> questions; // always 4, ordered to match blank numbering
}

final class Part6Set {
  final String id;
  final List<Part6Passage> passages; // always 3
  final Set<EconomyVolume> volumes;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

### 5.2 Generation

- `part6_source.dart` (new): one AI call returns all 3 passages (with their 4 questions each) as JSON.
- Prompt: realistic TOEIC document types (email, memo, notice, advertisement, article), each with exactly 4 numbered blanks; **at least one of the 4 blanks per passage must be a "select the sentence that best fits" item** (options become full sentences instead of words) — matches the real test's fixed pattern.
- `GeneratePart6SetUseCase` wraps the source call.

### 5.3 Home screen (`Part6HomeScreen`)

Same filters as Part 5 (§4.3), same wording pattern.

### 5.4 Session screen (`Part6SessionScreen`)

For each of the 3 passages, in order:

- Card showing `passageText` with inline blank numbers.
- Below it, the passage's 4 `RadioListTile` question groups (options rendered as their raw text — words or full sentences).

One "Nộp bài" button at the bottom, enabled once all 12 answers are filled.

### 5.5 Result screen (`Part6ResultScreen`)

- Score `X/12` header.
- Per-question breakdown + explanation line (same as Part 5), grouped visually under each passage.
- Full passage texts shown for review (like Nghe hiểu's transcript block).
- `VocabSuggestionsSection` fed the concatenation of all 3 passage texts.
- `statsServiceProvider.recordPracticeSession(12)`.
- Buttons: "Bài khác" / "Về trang chính".

---

## 6. Shared Infrastructure

### 6.1 Navigation

`/reading` becomes a hub screen (`ReadingHubScreen`, replacing today's `ReadingHomeScreen` at that path), mirroring `ListeningHomeScreen`:

```text
/reading                         → ReadingHubScreen (3 cards)
/reading/bilingual                → today's ReadingHomeScreen content (moved)
/reading/bilingual/session        → today's ReadingSessionScreen (route moved)
/reading/bilingual/session/result → today's ReadingResultScreen (route moved)
/reading/part5                    → Part5HomeScreen
/reading/part5/session            → Part5SessionScreen
/reading/part5/session/result     → Part5ResultScreen
/reading/part6                    → Part6HomeScreen
/reading/part6/session            → Part6SessionScreen
/reading/part6/session/result     → Part6ResultScreen
```

`practice_hub_screen.dart`'s "Đọc & gõ" card is relabeled "Luyện đọc" with a subtitle covering all 3 modes (mirrors the existing "Luyện nghe" card wording), `onTap` unchanged (`/reading`, now the hub).

### 6.2 File map

```text
lib/
├── features/
│   ├── reading/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── economy_volume.dart              CREATE
│   │   │   │   ├── part5_question.dart               CREATE (Part5Question, Part5Set)
│   │   │   │   ├── part6_passage.dart                 CREATE (Part6Question, Part6Passage, Part6Set)
│   │   │   ├── use_cases/
│   │   │   │   ├── generate_part5_set_use_case.dart   CREATE
│   │   │   │   └── generate_part6_set_use_case.dart   CREATE
│   │   │   ├── data/sources/
│   │   │   │   ├── part5_source.dart                  CREATE
│   │   │   │   └── part6_source.dart                  CREATE
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── part5_practice_provider.dart       CREATE — AsyncNotifier session state
│   │       │   └── part6_practice_provider.dart       CREATE — AsyncNotifier session state
│   │       └── screens/
│   │           ├── reading_hub_screen.dart             CREATE — replaces reading_home_screen at "/reading"
│   │           ├── part5_home_screen.dart              CREATE
│   │           ├── part5_session_screen.dart           CREATE
│   │           ├── part5_result_screen.dart             CREATE
│   │           ├── part6_home_screen.dart              CREATE
│   │           ├── part6_session_screen.dart            CREATE
│   │           └── part6_result_screen.dart              CREATE
│   └── practice/presentation/screens/
│       └── practice_hub_screen.dart                    MODIFY — relabel "Đọc & gõ" card → "Luyện đọc"
├── core/
│   ├── di/app_providers.dart                           MODIFY — wire new sources/use-cases/providers
│   └── router/app_router.dart                           MODIFY — restructure /reading routes (§6.1)
```

---

## 7. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| One spec for Part 5 + Part 6 | Combined, one plan | User explicitly grouped them; share `EconomyVolume`, session pattern, result layout |
| Part 7 | Deferred, separate future spec/plan | User explicitly wants it split out |
| Difficulty scale | New `EconomyVolume` (Vol 2–5), not app's CEFR | TOEIC prep difficulty doesn't map to CEFR; user named a specific, well-known book series |
| Volume selection | Multi-select, empty = all 4 | User request; mirrors existing empty-Topic-selection = "no filter" convention |
| Vocab Bank sourcing | None — fully AI-generated | User explicitly said these parts don't need to draw from the bank |
| SM-2 impact | None | No specific vocab word to attribute a grammar-question result to (same reasoning as Nghe hiểu) |
| Explanation field | New on both `Part5Question` and `Part6Question` | User explicitly requested answer explanations; no existing entity has this field, so it's new |
| Vocab suggestions in results | Reuse `VocabSuggestionsSection` + `getVocabSuggestionsForTextUseCaseProvider` verbatim | Already built for Đọc & gõ / Nghe hiểu; user explicitly asked for the same behavior here |
| Part 6 sentence-insertion blank | At least 1 of 4 per passage, no new schema field | Matches real TOEIC Part 6 format; representable purely as longer option text, no data model change needed |
| Session grading | Answer-all-then-submit (not per-question feedback) | Matches Nghe hiểu's established pattern, avoids introducing a second UX style |
| Batch size per generation call | 1 AI call for all 15 (Part 5) / all 3 passages (Part 6) | Matches existing multi-item single-call pattern (`ReadingPassageSource`, `ListeningPassageSource`); fewer calls, cheaper, faster |
| `/reading` route restructuring | Becomes a hub (like `/listening`), existing content moves to `/reading/bilingual` | Same precedent as Listening's dictation+comprehension hub; avoids overloading a single screen with unrelated filters |
| Mobile tab visibility | No change | `/reading` is reached only via the Practice hub card, not a bottom-nav tab — `AppShell` has no reading/listening destinations to update |

---

## 8. Out of Scope (this plan)

- Part 7 (Reading Comprehension) — separate future spec
- Vol 1 Economy TOEIC (only Vol 2–5 requested)
- Per-question immediate feedback (grading happens only at submit, like Nghe hiểu)
- Session history / past attempts log
- SM-2 / spaced-repetition integration
