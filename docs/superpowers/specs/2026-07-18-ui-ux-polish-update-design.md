# LexiCore — UI/UX Polish Update (Web Bug Fixes + Filter Redesign)

**Date:** 2026-07-18
**Status:** Implemented
**Covers:** Bug fixes and UI/UX rework found during web testing, touching **Vocab Bank** (Plan 2), **Practice** (Plan 3), **Settings** (Plan 4), and **Luyện đọc & gõ** (Plan 6/7). Also touches the Dictionary lookup screen (Plan 1).

> **⚠️ If you are reading Plan 1, 2, 3, 4, or 6's spec because of "Chủ đề" / topic chips, CEFR/level dropdowns, the flashcard exercise, or the reading options UI: those sections are superseded by this document.** The old specs describe the *original* implementation; this spec describes what replaced it and why. Read both — the old spec for architecture/data-flow context, this one for the current UI.

---

## 1. Why this update happened

The app was tested on Flutter Web for the first time end-to-end (previous specs were written/validated primarily against mobile). That surfaced a batch of web-specific bugs and rough edges:

- Horizontal chip rows don't respond to mouse wheel on web (only click-drag or shift+wheel) — read as "can't scroll" by users.
- Native `DropdownButtonFormField` menus render as an ugly full-screen-ish overlay on small viewports.
- A `Stack`-based overlay text input (reading/typing exercise) drifted visibly out of alignment with the text underneath as the typed string grew longer.
- Filter/selection state didn't reset between vocab words in Practice because `Exercise` widgets weren't keyed, so Flutter reused the previous word's `State`.
- Vocab Bank showed words from every target language at once, with no way to tell which language a row belonged to.

None of this needed new features — it needed consistent, reusable interaction patterns. That produced two new shared widgets (below) that every affected screen now uses instead of ad hoc dropdowns/chip rows.

---

## 2. New shared components

### `lib/core/widgets/filter_tile.dart` — `FilterTile`
A compact row: `[icon] label ... value ▾`, tappable, opens a picker (almost always one of the sheets below). Replaces inline `Wrap`/`FilterChip` rows and `DropdownButtonFormField` wherever a screen needs "pick one/many things, show the current pick compactly."

### `lib/core/widgets/selection_sheets.dart` — `showSingleSelectSheet` / `showMultiSelectSheet`
Two `showModalBottomSheet`-based pickers, generic over the option type `T` via `SelectOption<T>(value, label, emoji)`:

- **`showSingleSelectSheet<T>`** — radio-list bottom sheet. Returns `SelectOption<T>?`, **not** `T?` — this matters when `T` itself is nullable (e.g. `CEFRLevel?` with a "Tất cả" = `null` entry): returning the wrapper lets callers tell "sheet dismissed without picking" (`null`) apart from "user explicitly picked the null-valued option" (a non-null `SelectOption` whose `.value` is `null`). Returning bare `T?` would collapse both cases to the same value.
- **`showMultiSelectSheet<T>`** — checkbox-list bottom sheet, `DraggableScrollableSheet` (0.3–0.9 of screen height), "Bỏ chọn hết" (clear all) action, confirm button shows the selected count. Optional `maxSelected` disables further checkboxes once the cap is hit (used for vocab topic tagging, capped at 2) and optional `confirmLabel` customizes the confirm button text.

Every picker in the app now goes through one of these two functions — no screen hand-rolls its own bottom sheet or dropdown anymore.

---

## 3. Per-screen changes

### 3.1 Vocab Bank (`vocab_bank_screen.dart`) — supersedes topic-filter UI in Plan 2 spec §Topic filtering

- **Before:** a single-select `FilterChip` row (`_selectedTopicId: String?`) in a horizontal `ListView`, all ~20 predefined + custom topics always visible, no mouse-wheel scroll on web.
- **Now:** one compact `FilterTile` ("Chủ đề: Tất cả" / "Chủ đề: N đã chọn") that opens `showMultiSelectSheet<String>`. Filtering logic changed from equality (`topicIds.contains(selectedId)`) to OR-membership (`topicIds.any(selectedIds.contains)`) to support multiple topics at once.
- **Target-language filtering (new):** the list is now also filtered by `settings.targetLanguage` client-side inside `_filter()`, and the AppBar shows `Vocab Bank · <Language>` so it's obvious which language is active. This filter was deliberately **not** pushed into `vocabBankNotifierProvider` itself — that provider stays unfiltered because `reading_session_screen.dart` and `reading_result_screen.dart` both depend on it returning records across *all* languages (a reading session can be generated in a language different from the current global Settings target language; see §3.3).

### 3.2 Practice (`practice_home_screen.dart`, `practice_session_screen.dart`, `flashcard_widget.dart`) — supersedes the exercise-selection UI and flashcard interaction in Plan 3 spec

- **Filter rows:** Topic (`FilterChip` `Wrap`), Cấp độ, and Số từ mỗi session — all converted from `SegmentedButton`/`DropdownButtonFormField` to `FilterTile` + `showSingleSelectSheet`. All three remain single-select (unlike Vocab Bank/Reading, Practice sessions still pull from exactly one topic/level/count).
- **Stale exercise state bug (root cause fix):** `_buildExerciseWidget` now assigns `key: ValueKey(exercise.vocabRecord.id)` to every exercise widget (`FlashcardWidget`, `MultipleChoiceWidget`, `FillInBlankWidget`, `TranslationExerciseWidget`). Previously, with no key, Flutter reused the same `State` object across consecutive words of the same exercise type — so a flashcard's "revealed" flag, a multiple-choice's selected answer, a fill-in-blank's submitted flag, etc. all leaked into the next word. This affected **all four** exercise types, though only the flashcard case was reported.
- **Flashcard redesign:** tap-to-flip 3D card (`rotateX` — vertical flip, top/bottom, not left/right) replaces the "Xem đáp án" button; back face buttons renamed **"Chưa hiểu" / "Đã hiểu"** (same SM-2 quality mapping: 1 / 5). Because each word gets a fresh `State` (see above), the card always starts front-facing for a new word with no manual reset code needed.
- **Cross-word transition:** the exercise widget is wrapped in an `AnimatedSwitcher` (fade + slight upward slide, 300ms) so moving to the next word animates instead of popping in instantly.

### 3.3 Luyện đọc & gõ (`reading_home_screen.dart`, `reading_session_screen.dart`) — supersedes reading-options and typing-input sections of Plan 6/7 spec

- **Cursor misalignment bug (root cause):** the typing screen stacks an invisible `TextField` (for the caret) over a `RichText` (for the colored feedback text). The two were using different effective font metrics — `RichText`'s unset style properties fell back to the ambient `DefaultTextStyle` (~14sp) while `TextField`'s style merged against its own default (~16sp) — so every typed character landed at a slightly different x-offset than its colored counterpart, drift growing with sentence length. Fix: both layers now share one explicit `TextStyle` (`theme.textTheme.bodyLarge`) and one `StrutStyle`, passed to both the `RichText` root span and the `TextField.style`.
- **New per-session options:** language, topic (multi-select), CEFR level (single-select — see below), and word count (5/10/20/Tất cả) are now editable directly on this screen via `FilterTile` rows, independent of the global Settings values (previously: hardcoded to the global target language/level and a fixed 10 words, with no in-screen controls at all).
  - Topic is multi-select (`showMultiSelectSheet`) — OR-membership filter, same as Vocab Bank.
  - **Level is single-select** (`showSingleSelectSheet<CEFRLevel?>`) — this was briefly multi-select in an earlier iteration of this update, but was reverted: the generated passage needs exactly one target CEFR difficulty to hand to the AI prompt, and single-select removes the need for a "which of several selected levels do we actually generate at" heuristic.
  - Word filtering: language + level are filtered server-side via `GetVocabListUseCase.execute(language:, maxCefrLevel:)`; topic is filtered client-side afterward (OR-membership across a `Set<String>`) since the use case only accepts one `topicId`.
- Note this screen's word source (`getVocabListUseCaseProvider`, filtered by the screen's own language/level/topic picks) is intentionally decoupled from `vocabBankNotifierProvider` (all-languages, used for cross-session headword lookups in the session/result screens) — see §3.1's note on why that provider stays unfiltered.

### 3.4 Settings (`settings_screen.dart`) — supersedes "Ngôn ngữ mục tiêu" control in Plan 4 spec

- "Ngôn ngữ mục tiêu" changed from a native `DropdownButton<Language>` to a `ListTile` + `showSingleSelectSheet<Language>`, matching the "Cấp độ mục tiêu" row immediately below it (which already used a bottom-sheet picker).

### 3.5 Dictionary (`context_selector_widget.dart`) — supersedes context-selector UI in Plan 1 spec

- The horizontal `FilterChip` row for `AppContext` (general/business/technology/.../socialCasual — same wheel-scroll problem as the old topic row) is now a single `FilterTile` opening `showSingleSelectSheet<AppContext>`.

### 3.6 Topic tagging when saving/editing a word (`save_vocab_sheet.dart`, `vocab_detail_screen.dart`) — supersedes topic-tagging UI in Plan 2 spec

- Both the "Save to Vocab Bank" sheet and the Vocab Bank detail/edit screen replaced their max-2 `FilterChip` `Wrap` with `FilterTile` + `showMultiSelectSheet(..., maxSelected: 2)`.

---

## 4. Explicitly not changed

- `vocabBankNotifierProvider` / `vocabBankProvider` remain **unfiltered by language** — see the reasoning in §3.1 and §3.3. Do not "fix" this without re-checking `reading_session_screen.dart` and `reading_result_screen.dart`'s headword lookups first.
- Practice's topic/level/word-count stayed single-select (only Vocab Bank and Reading's topic got multi-select) — Practice pulls one topic/level/count per session, there's no per-word filtering step downstream that would benefit from a set.

---

## 5. Testing

- `flutter analyze`: clean (only pre-existing `RadioListTile.groupValue`/`onChanged` deprecation infos, present before this update too).
- `flutter test`: 135/135 passing. Updated `context_selector_widget_test.dart` (rewritten for the new tile+sheet interaction, was asserting directly on `FilterChip`) and `reading_home_screen_test.dart` (rewritten to override `vocabRepositoryProvider` with a fake instead of `vocabBankProvider`, since the reading screen now fetches its own filtered word list directly via `getVocabListUseCaseProvider`).
- No automated browser test exists for the mouse-wheel scroll fix or the flip animation/cursor alignment — these were reasoned through font-metrics/gesture-arena analysis, not visually verified in a live browser. Recommend a manual `flutter run -d chrome` pass on Vocab Bank, Practice, and Luyện đọc & gõ before treating this as fully verified.
