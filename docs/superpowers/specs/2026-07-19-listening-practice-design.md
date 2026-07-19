# LexiCore Plan 9 & 10 — "Luyện nghe" (Listening Practice) Design Spec

**Date:** 2026-07-19
**Status:** Approved
**Covers:** Two sequential plans — Plan 9 (Nghe chép/dictation) and Plan 10 (Nghe hiểu/TOEIC comprehension) — two listening sub-features, web + mobile.

**Depends on:** Plan 6 (Flutter Web + adaptive nav), Plan 7 (Reading — shares its UI patterns).

---

## 1. Goal

Add a "Luyện nghe" (Listening Practice) tab with two independent sub-features:

- **Nghe chép** (Dictation) — hear one AI-generated sentence built from Vocab Bank words, type what you heard.
- **Nghe hiểu** (TOEIC-style comprehension) — hear an AI-generated two-speaker conversation or one-speaker talk, answer multiple-choice questions about it (main idea / detail / implied meaning — no fill-in-blank), matching the style of real TOEIC Listening Parts 3–4.

Both run on web and mobile using the existing `TtsService` (flutter_tts) — no new packages.

---

## 2. Scope & Non-Goals

Both sub-features live under one `/listening` hub screen (two cards, no separate nav tabs). Out of scope for v1:

- Speech-to-text / microphone input (this is *ear* listening, not pronunciation scoring)
- A true continuous audio scrub bar (seconds-level seeking) — replaced by per-sentence/per-turn seeking, which needs no new audio pipeline
- Adjustable TTS speech rate (slow/normal toggle)
- Saving session history
- Web autoplay on session entry — the user always presses play manually (browsers block programmatic autoplay before a user gesture, and this keeps mobile/web behavior identical)

---

## 3. A. Nghe chép (Dictation)

### 3.1 Content generation

- Requires AI enabled. Requires **≥2** Vocab Bank words matching the current filters (language / topic tag / CEFR level) — lower than Reading's 5, because only ~2 words are targeted per sentence (cramming 5 into one natural sentence isn't realistic).
- Prompt: pick 2 words (prefer due-for-review, like Reading's prioritization), ask the model for **one** medium-length sentence naturally using both, plus its Vietnamese translation. Reuses the same `GenerativeModelClient` plumbing as `ReadingPassageSource`.
- Entity: `DictationItem { id, target: String, vietnamese: String, vocabIds: List<String>, level, context, targetLanguage, generatedAt }` — a single-sentence sibling of `ReadingPassage`.

### 3.2 Home screen controls

Mirrors `ReadingHomeScreen` exactly:

- `FilterTile` — Ngôn ngữ (Language picker)
- `FilterTile` — Chủ đề (**Topic tag** multi-select, filters which Vocab Bank words are eligible — same mechanism as Reading, not AppContext)
- `FilterTile` — Cấp độ (CEFR level picker)
- Error states: AI disabled → prompt to enable; <2 matching words → prompt to save more
- "Tạo bài luyện" button → generates and navigates to session

### 3.3 Session flow

1. Screen opens with a large "▶ Phát" button — **no autoplay**.
2. Plain `TextField` for the answer — no live per-character coloring while typing (there's no visible target to compare against during blind dictation; live diffing only makes sense once something is submitted).
3. "🔁 Nghe lại" button — unlimited presses, each press after the first increments `replayCount`.
4. "Nộp bài" button — grades on demand (dictation does **not** auto-complete on an exact match the way Reading does, since the user may never produce a byte-exact match when transcribing from memory).

### 3.4 Scoring & SM-2 integration

- `charAccuracy` = position-by-position character match between typed text and target sentence (same simple algorithm Reading already uses, for consistency — known limitation: a single missed/extra character cascades mismatches for the rest of the string).
- `finalScore = max(0, charAccuracy - 0.05 × replayCount)`.
- Map `finalScore` → SM-2 `quality` (0–5): ≥0.95→5, ≥0.80→4, ≥0.60→3, ≥0.40→2, else→0.
- `GradeDictationUseCase` applies `ComputeSm2UseCase.compute(record, quality)` to **every** `VocabRecord` referenced in `vocabIds` for that sentence — updates their `nextReviewAt` the same way a Practice session would.

### 3.5 Result screen

Shows: final score %, replay count, elapsed time, colored diff (target vs. typed), Vietnamese translation, confirmation that the involved vocab words' review schedules were updated. Buttons: "Câu khác" (regenerate) / "Về trang chính".

---

## 4. B. Nghe hiểu (TOEIC-style comprehension)

### 4.1 Content generation

- Requires AI enabled. **Does not** require Vocab Bank words — content is a generic scenario, not tied to saved vocabulary.
- Prompt asks the model to randomly produce either:
  - a **conversation** (2 speakers, e.g. office/store/travel setting), or
  - a **talk** (1 speaker: announcement, ad, instructions)
  at the chosen CEFR level and AppContext, plus exactly 3 multiple-choice questions (4 options each) testing main idea / detail / implied meaning — never fill-in-blank.
- Entities:

  ```dart
  class ListeningTurn { final String? speaker; final String text; } // speaker null for a talk
  class ListeningQuestion { final String question; final List<String> options; final int correctIndex; } // 4 options
  class ListeningPassage {
    final String id;
    final ListeningKind kind; // conversation | talk
    final List<ListeningTurn> turns;
    final List<ListeningQuestion> questions; // always 3
    final CEFRLevel level;
    final AppContext context;
    final Language targetLanguage;
    final DateTime generatedAt;
  }
  ```

### 4.2 Home screen controls

- `FilterTile` — Ngôn ngữ
- `FilterTile` — Chủ đề (**AppContext** picker — Business/Travel/etc. — since there's no Vocab Bank pool to filter here, unlike Dictation)
- `FilterTile` — Cấp độ
- Error state: AI disabled → prompt to enable (no minimum-words gate)

### 4.3 Playback & controls

- Plays turns sequentially via `TtsService`; alternates a slightly different pitch per speaker in a conversation (single fixed pitch for a talk) so the two voices are distinguishable.
- Controls: ⏮ previous turn / ▶️⏸ play-pause current turn / ⏭ next turn / 🔁 replay from the start — **seek is per-turn**, not a continuous scrub bar (per the earlier trade-off: a real scrub bar needs a cloud TTS pipeline that produces a seekable audio file, which this spec intentionally avoids).
- No autoplay on entry (same reasoning as Dictation) — user presses ▶ to start.
- Unlimited replay/seek, **no scoring penalty** here (unlike Dictation) — the point is comprehension practice, not listening-once discipline.

### 4.4 Questions & grading

- All 3 questions shown together below the player, each with 4 radio options.
- "Nộp bài" grades all 3 at once: shows correct/incorrect per question, highlights the correct answer, and reveals the full transcript for review.
- **No SM-2 impact** — there's no specific vocab word to attribute the result to.

### 4.5 Result screen

Score X/3, per-question breakdown, transcript. Buttons: "Bài khác" (regenerate) / "Về trang chính".

---

## 5. Shared Infrastructure

### 5.1 Navigation

- New route `/listening` → hub screen with 2 cards ("Nghe chép" / "Nghe hiểu").
- `/listening/dictation` (home → session → result), `/listening/comprehension` (home → session → result).
- Tab icon: `Icons.headphones_outlined` / `Icons.headphones` (selected). Label: "Luyện nghe".
- Visibility: shown whenever width ≥ 600dp, or `showListeningPracticeOnMobile == true` — **same width-based rule** as the corrected Reading tab logic (see §5.2 below), not `kIsWeb`.

### 5.2 Related fix already applied: Reading tab visibility bug

While reviewing `AppShell` for this feature, found and fixed a pre-existing bug where the Reading tab's visibility (and its Settings toggle) used `kIsWeb` in a way that made both inert on any Flutter Web build, regardless of screen width. See [Mobile Tab Visibility `kIsWeb` Bug Fix](2026-07-19-mobile-tab-visibility-kisweb-fix-design.md) for the full root cause and fix. The new Listening tab adopts the corrected width-based visibility logic from the start (§5.1 above) rather than repeating the bug.

### 5.3 Settings

- `UserSettingsState.showListeningPracticeOnMobile: bool = false`, persisted under `'show_listening_mobile'` — mirrors `showReadingPracticeOnMobile` exactly.
- Toggle row in `SettingsScreen`: "Hiện tab Luyện nghe trên điện thoại".

### 5.4 File map

```text
lib/
├── features/
│   ├── listening/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── dictation_item.dart            CREATE
│   │   │   │   ├── listening_passage.dart         CREATE (ListeningTurn, ListeningQuestion, ListeningKind, ListeningPassage)
│   │   │   ├── use_cases/
│   │   │   │   ├── generate_dictation_item_use_case.dart      CREATE
│   │   │   │   ├── grade_dictation_use_case.dart               CREATE (accuracy → SM-2 quality → ComputeSm2UseCase)
│   │   │   │   └── generate_listening_passage_use_case.dart    CREATE
│   │   ├── data/sources/
│   │   │   ├── dictation_source.dart              CREATE — Gemini/AI prompt + JSON parse
│   │   │   └── listening_passage_source.dart      CREATE — Gemini/AI prompt + JSON parse
│   │   └── presentation/
│   │       ├── providers/
│   │       │   ├── dictation_practice_provider.dart      CREATE — AsyncNotifier session state
│   │       │   └── listening_comprehension_provider.dart CREATE — AsyncNotifier session state
│   │       └── screens/
│   │           ├── listening_home_screen.dart             CREATE — hub, 2 cards
│   │           ├── dictation_home_screen.dart             CREATE
│   │           ├── dictation_session_screen.dart          CREATE
│   │           ├── dictation_result_screen.dart           CREATE
│   │           ├── comprehension_home_screen.dart         CREATE
│   │           ├── comprehension_session_screen.dart      CREATE
│   │           └── comprehension_result_screen.dart       CREATE
│   ├── dictionary/domain/entities/
│   │   └── user_settings_state.dart                MODIFY — add showListeningPracticeOnMobile
│   └── settings/presentation/screens/
│       └── settings_screen.dart                    MODIFY — add toggle
├── core/
│   ├── widgets/app_shell.dart                      MODIFY (done) — width-based tab visibility + Listening destination
│   ├── di/app_providers.dart                       MODIFY — wire new providers/use cases
│   └── router/app_router.dart                      MODIFY — add /listening routes
```

---

## 6. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Two features, one spec | Combined | Share TTS infra and the "Luyện nghe" tab; precedent set by Plan 6+7 being written together |
| Two features, one tab | Hub screen with 2 cards, not 2 nav tabs | Avoids further crowding an already-dense nav bar |
| Seek mechanism | Per-sentence/per-turn jump, not a continuous scrub bar | A real scrub bar needs a cloud TTS pipeline producing a seekable audio file (new cost/dependency); per-turn seeking reuses the existing live-TTS `TtsService` on both web and mobile |
| Dictation content | AI-generated from Vocab Bank, ~2 words/sentence | 5 words (Reading's number) is unnatural to cram into one sentence; 2 keeps it natural |
| Dictation replay | Unlimited but penalized (−5%/replay) | Encourages listening carefully rather than replaying to transcribe piecemeal |
| Comprehension replay/seek | Unlimited, no penalty | Goal is comprehension training, not one-shot exam pressure (user explicitly wants free replay + seek here) |
| Dictation → SM-2 | Yes, sentence accuracy mapped to quality 0–5, applied to all vocab words in the sentence | User-requested; a coarse per-sentence approximation is acceptable given only ~2 words are involved |
| Comprehension → SM-2 | No impact | No specific vocab word to attribute a conversation-level score to |
| "Chủ đề" meaning per feature | Dictation: Topic tag (filters Vocab Bank pool, like Reading) · Comprehension: AppContext (scenario setting for AI, no vocab pool exists) | Each feature's "topic" concept maps to whatever it actually filters — the two are different underlying concepts that happen to share a UI label |
| Autoplay | Never; explicit ▶ press required | Browsers block programmatic autoplay pre-gesture; keeping mobile/web identical avoids two code paths |
| Speaker voice distinction | Pitch offset per speaker via `_tts.setPitch()` | No multi-voice TTS available cross-platform; pitch shift is a free, good-enough cue |
| Mobile tab visibility | Hidden by default, opt-in Settings toggle, width-based (not `kIsWeb`) | Consistent with (corrected) Reading tab behavior |

---

## 7. Out of Scope (v1)

- Microphone / speech-to-text input
- Continuous (second-level) audio scrubbing
- Adjustable TTS speech rate
- Session history / past attempts log
- Multiplayer or timed/competitive modes
