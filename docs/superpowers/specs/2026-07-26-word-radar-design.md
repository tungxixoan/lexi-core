# LexiCore — "Word Radar" Design Spec

**Date:** 2026-07-26
**Status:** Implemented (revised post-launch from manual testing feedback — see §9)
**Covers:** New feature — paste arbitrary text, highlight words already in Vocab Bank, get AI-suggested new words to learn from the same text, save with one tap, and read a Vietnamese translation of the whole text with known-word meanings highlighted. Plus a related fix: `WordPhraseResult`/`SaveVocabSheet` currently hardcode `CEFRLevel.b1` on every save regardless of the word's actual level; this spec adds an AI-sourced `cefrLevel` used when available.

**Depends on:** Practice hub restructuring (bottom nav now Dictionary/Vocab Bank/Luyện tập/Cài đặt; `/practice` is a card hub). Word Radar is the hub's 5th card.

---

## 1. Goal

Turn any pasted text (an article, a chat, a paragraph) into a three-part learning aid:

1. **Known-word recall** — words already in the user's Vocab Bank are highlighted inline, for free (no AI), instantly.
2. **New-word discovery** — an AI call reads the same text and suggests words worth learning at the user's target CEFR level, excluding anything already known, with enough detail (IPA/meaning/definition/synonyms/examples/topic/level) to save in one tap.
3. **Vietnamese translation** — the same AI call also translates the full text, with the Vietnamese meanings of known Vocab Bank words highlighted in the translation the same way their headwords are highlighted in the original.

This is the first LexiCore feature where the input is user-supplied real-world text rather than AI-generated content.

---

## 2. Scope & Non-Goals

- **No new tokenizer.** Highlighting uses plain case-insensitive substring matching, the same approach already shipped in `reading_session_screen.dart`'s `_HighlightedText`. This works unmodified for Chinese/Japanese (no word boundaries needed) and is an accepted-risk simplification for space-delimited languages (a saved word can match inside a longer word) — consistent with this codebase's existing tolerance for that exact trade-off. The translation highlight (§9) reuses the same algorithm against `VocabRecord.meaning` strings instead of headwords.
- **One AI call per scan**, not one per suggested word — and not a second call for the translation either. The prompt returns full `WordPhraseResult`-shaped data (ipa/meaning/definition/synonyms/examples/suggestedTopics/cefrLevel) for every suggestion plus a `translation` field, all in one response, so saving never triggers a second lookup call and the translation never costs a separate request.
- **Not scoped:** multi-language text in a single paste — the scan assumes the pasted text is in the currently selected `targetLanguage`, same assumption every other AI feature in the app makes.
- **Not scoped:** editing/removing a known-word highlight in place, or re-scanning incrementally as the user types (scan only runs on explicit button press).
- **Duplication is intentional, not an oversight:** the highlighted-text renderer is a second, private, near-identical copy of `_HighlightedText` local to the new screen — not extracted into a shared widget. This matches the codebase's established precedent (`_SpeedSelector`, `_ClozeInput`/`_ClozeResult`) of accepting byte-similar duplication at 2 call sites over premature abstraction.
- **One new bundled entity, added post-launch:** `WordRadarAiResult { translation, suggestions }` (§9.1) — the original spec avoided any bundling type since the local pass and AI pass each returned an existing/plain type on their own; once the AI pass had to return two things (translation + suggestions) from one call, a small wrapper became the least-bad option, still far short of a `WordRadarResult` covering both passes (which remain independently timed — see §5.5).

---

## 3. Entry point & navigation

- New 5th card in `PracticeHubScreen`: title **"Quét từ vựng"**, subtitle "Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học."
- Route: `/practice/radar`, nested under the existing `/practice` `GoRoute`.
- `WordRadarScreen` AppBar gets the same `leading: BackButton(onPressed: () => context.go('/practice'))` pattern as the other 3 hub cards (Từ vựng cách khoảng / Đọc & gõ / Luyện nghe), for nav consistency.

---

## 4. Flow

1. User opens the screen: a multiline `TextField` (paste target) + a **"Quét"** `FilledButton`, initially disabled while the field is empty.
2. Input is capped at **3000 characters** via `TextField.maxLength` — Flutter enforces this on typed and pasted text alike and renders the counter for free.
3. On Quét:
   - **Local pass (synchronous, no AI):** load `VocabRepository.getAll(language: targetLanguage)`, then for each record check `text.toLowerCase().contains(headword.toLowerCase())`. Matches become `knownRecords` (the full `VocabRecord`s, not just headword strings — needed for both this highlight and the translation highlight in step 4b). The original text renders immediately with matched headwords bolded/underlined, tappable (own copy of the `_HighlightedText` pattern) — this part works even if AI is off.
   - **AI pass (async, only if `aiEnabled`):** call `WordRadarSource.scan(text, targetLanguage, targetCefrLevel, knownRecords.map((r) => r.headword))`. Shows a loading indicator under the highlighted text while pending.
4. Once the AI pass resolves:
   - **(a) Suggestions** render as a list of cards below the text (headword, ipa, meaning, cefrLevel chip). Tapping anywhere on an unsaved card opens the existing `SaveVocabSheet(result: suggestion)` unmodified — same edit-before-save UX as Dictionary lookup (topic pre-selection from `suggestedTopics`, editable meaning/examples/notes). The card's trailing slot is a dismiss (✕) icon that removes that suggestion from the visible list (not interested), or — once saved — a green checkmark (card no longer tappable). A **"Lưu tất cả"** button above the list bulk-saves every still-visible unsaved suggestion directly (no per-item sheet), reusing `SaveVocabSheet`'s own defaults: topic matching against `suggestedTopics`, `cefrLevel ?? CEFRLevel.b1`, empty personal notes. One item failing to save (e.g. a duplicate headword) doesn't block the rest of the batch; a snackbar reports how many of the batch actually saved.
   - **(b) Translation** — if the AI returned a non-empty `translation`, a "Bản dịch" section shows it below the suggestions header, with the Vietnamese `meaning` of every known Vocab Bank record highlighted the same way (bold/underline) but **read-only** (no tap target — see §9.2 for why).
5. Tapping a highlighted known word in the original text resolves the tapped headword against `knownRecords` (already in memory — no repository call needed) and pushes `VocabDetailScreen` for that record.
6. If `aiEnabled == false`: skip step 3's AI pass entirely, show only the local highlight result plus a note: "Bật AI trong Cài đặt để nhận gợi ý từ mới."
7. If AI is enabled but the local pass found zero matching Vocab Bank words at all: still proceed with the AI pass (an empty `knownHeadwords` exclusion list is valid — nothing to exclude).

---

## 5. Data & Architecture

New top-level feature folder `lib/features/word_radar/`, **not** nested under `practice/` — same precedent as `reading/` and `listening/`, which are also reached exclusively via a Practice hub card yet are independent top-level features with their own `data/domain/presentation` layers. Folder placement follows domain ownership, not hub membership. The local pass and the AI pass remain two independently-timed operations (see §5.5); the AI pass's own result is a single small bundled entity, `WordRadarAiResult` (§9.1), added once that one call had to return two things (translation + suggestions) instead of one.

### 5.1 Shared schema fix (used by both Word Radar and the existing Dictionary lookup)

- `WordPhraseResult` (`lib/features/dictionary/domain/entities/lookup_result.dart`) gains one field: `final CEFRLevel? cefrLevel;` defaulting to `null`. Backward compatible — every existing construction site keeps compiling unchanged.
- `GeminiDictionarySource._wordPhrasePrompt` — add `"cefrLevel":"a1|a2|b1|b2|c1|c2 for this word/sense"` to the requested JSON shape; parse with `CEFRLevel.values.byName((json['cefrLevel'] as String).toLowerCase())`, unguarded (consistent with this codebase's existing risk tolerance for AI-sourced enum parsing, e.g. `AiProvider.values.byName()`).
- `FreeDictionarySource` (English, no AI) — unchanged, `cefrLevel` stays `null`.
- `SaveVocabSheet._save()` — change `cefrLevel: CEFRLevel.b1` to `cefrLevel: widget.result.cefrLevel ?? CEFRLevel.b1`. Net effect: any save that came from an AI-sourced `WordPhraseResult` (regular AI-enabled Dictionary lookup, or Word Radar) now stores the real level; Free Dictionary saves and any other still-null case keep today's B1 default.

### 5.2 `FindKnownHeadwordsUseCase` (new, `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`)

```dart
Future<List<VocabRecord>> execute({required String text, required Language language})
```

> Revised post-launch (§9.1): originally returned `List<String>` (headwords only). Once the translation highlight needed each match's `meaning` too, this was widened to return the full `VocabRecord`s from a single local query rather than adding a second lookup — callers that only need headwords derive them via `.map((r) => r.headword)`.

Thin wrapper: calls the existing `VocabRepository.getAll(language: language)`, then for each record checks `text.toLowerCase().contains(record.headword.toLowerCase())`. Returns matching records, deduped by headword. No AI, no new I/O — reuses the same repository every other vocab-listing use case already goes through.

### 5.3 `WordRadarSource` (new, `lib/features/word_radar/data/sources/word_radar_source.dart`, mirrors `ListeningPassageSource`'s constructor/DI pattern exactly)

```dart
Future<WordRadarAiResult> scan({
  required String text,
  required Language targetLanguage,
  required CEFRLevel? targetCefrLevel,
  required List<String> knownHeadwords,
})
```

> Revised post-launch (§9.1): originally returned `Future<List<WordPhraseResult>>`. Now returns `WordRadarAiResult { translation, suggestions }` (§9.1) since the same call also produces the translation — still exactly one AI call per scan.

Prompt: "You are a language learning assistant helping a Vietnamese speaker learn {targetLanguage}. Given this text: \"{text}\", do two things. First, translate the full text into Vietnamese. Second, suggest up to 10 words or short phrases from it worth learning at {level or 'any'} level, for a Vietnamese speaker. Do NOT suggest any of these already-known words: [{knownHeadwords}]. Respond with JSON only: {"translation":"...", "suggestions":[{same per-item shape as GeminiDictionarySource's word/phrase JSON, including cefrLevel}]}". Empty `suggestions` array is valid (nothing new to suggest) and not an error; `translation` is always requested even when there's nothing to suggest.

`_parseSuggestion` defensively handles the AI returning a bare string where `examples`/`suggestedTopics`/`synonyms` were asked for as a JSON array (observed in production — see §9.3) by treating a non-empty string as a single-item list instead of throwing.

### 5.4 `GenerateWordSuggestionsUseCase` (new, `lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart`)

Thin wrapper around `WordRadarSource.scan(...)`, same shape/role as `GenerateListeningPassageUseCase`/`GenerateDictationItemUseCase` wrapping their respective sources. Return type follows `WordRadarSource.scan()` — `Future<WordRadarAiResult>`.

### 5.5 `WordRadarNotifier` (new, Riverpod, `lib/features/word_radar/presentation/providers/`)

Two independently-timed pieces of state, matching the two-stage UX in §4 (highlights appear immediately, suggestions/translation catch up):

```dart
class WordRadarState {
  final List<VocabRecord>? knownRecords;            // null = not scanned yet
  final AsyncValue<WordRadarAiResult>? aiResult;     // null = AI not run (disabled or not reached yet)
}
```

> Revised post-launch (§9.1): fields renamed from `knownHeadwords: List<String>?` / `suggestions: AsyncValue<List<WordPhraseResult>>?` to the above, following the `FindKnownHeadwordsUseCase`/`WordRadarSource` type changes.

`scan(String text)`:

1. Calls `FindKnownHeadwordsUseCase`, sets `knownRecords` on the state immediately — this alone is enough for the screen to render the highlighted text, before anything AI-related starts.
2. If `aiEnabled`: sets `aiResult` to `AsyncValue.loading()`, then calls `GenerateWordSuggestionsUseCase(text, targetLanguage, targetCefrLevel, knownRecords.map((r) => r.headword))` and updates `aiResult` to `AsyncData`/`AsyncError`.
3. If not `aiEnabled`: leaves `aiResult` as `null` — the screen distinguishes "AI off" (`null`) from "AI ran, found nothing" (`AsyncData` with an empty `suggestions` list) to show the right message in each case.

### 5.6 `WordRadarScreen` (new, `lib/features/word_radar/presentation/screens/`)

Per the flow in §4. `knownRecords` drives the highlighted-text render as soon as it's non-null (independent of the AI state). The AI section switches on `aiResult`: `null` → "Bật AI trong Cài đặt..." note; `AsyncValue.loading()` → spinner; `AsyncError` → inline error + "Thử lại" (re-runs only step 2, not the whole scan); `AsyncData(result)` → the translation section (if `result.translation` non-empty) plus the suggestion cards (or "Không có gợi ý mới" if `result.suggestions` — after filtering out dismissed items — is empty).

`_HighlightedText`'s `onTapHighlight` callback is optional (§9.2): the original-text instance passes one (tap → `VocabDetailScreen`), the translation instance omits it (read-only highlight, plain `TextSpan` — no `WidgetSpan`/`GestureDetector`).

---

## 6. Error handling

- AI call failure (network/parse) — the local highlight result still displays; the AI section shows an inline error + "Thử lại" retry button, matching the `AsyncValue.guard` pattern used elsewhere (e.g. `ReadingPassageSource`/`ListeningPassageSource` callers).
- Empty pasted text — Quét button stays disabled (already covered in §4.2).
- A malformed individual suggestion (missing `headword`, or a string where a JSON array was expected for `examples`/`suggestedTopics`/`synonyms`, or an out-of-enum `cefrLevel`) — filtered out or defensively coerced (§5.3, §9.3) so one bad item doesn't discard the rest of the batch.
- A suggested word that turns out to already exist in Vocab Bank (AI ignored the exclusion list) — `SaveVocabSheet`'s save path (single-item) and `WordRadarScreen._saveAll` (bulk) both go through `SaveVocabUseCase`, which throws `VocabException` on duplicate headword; single-item save shows the existing catch-and-snackbar, bulk save skips the failed item and keeps saving the rest (§4.4a), reporting a count.

---

## 7. Testing

Follows this codebase's existing layering (as shipped — see §9 for what was added to this list after the initial plan):

- `FindKnownHeadwordsUseCase` — unit tests for the substring-match logic in isolation (English/Vietnamese word-boundary edge cases, Chinese/Japanese no-space text, empty Vocab Bank, and that full records — not just headwords — come back with `meaning` intact).
- `WordRadarSource` — unit tests with a fake `GenerativeModelClient`, same pattern as `listening_passage_source_test.dart`: empty suggestions array, malformed JSON, exclusion list actually included in the prompt, translation defaults to `''` when the AI omits it, a multi-word suggestion classified as `InputType.phrase` not `.word`, an invalid `cefrLevel` string defaults to `null` without discarding the suggestion, and a bare string accepted where `examples`/`suggestedTopics`/`synonyms` expected a JSON array.
- `WordRadarNotifier` — provider tests: `knownRecords` populates before `aiResult` resolves (two-stage ordering, using a `Completer`-gated fake AI client), AI-disabled leaves `aiResult` null, scan success/failure states, retry only re-runs the AI step (verified via a call-counting fake repository proving the local pass doesn't re-run).
- `WordRadarScreen` — widget tests for: known-word highlight rendering, tapping a suggestion card opens `SaveVocabSheet`, tapping the dismiss icon removes a suggestion from the list, "Lưu tất cả" saves every visible unsaved suggestion and shows checkmarks, AI-disabled note shown/hidden correctly, input length cap, the translation section rendering (and not rendering when empty).
- `SaveVocabSheet` — a case confirming `cefrLevel` falls through from `widget.result.cefrLevel` when present, and defaults to B1 when null (regression-proofs the shared fix in §5.1).

---

## 8. Explicitly not done

- No edit UI for the AI-suggested `cefrLevel` before saving (user can still edit everything else `SaveVocabSheet` already allows editing; level is accepted as-is or falls back to B1 — matching how `ipa`/`definition` are already read-only in that sheet). "Lưu tất cả" (§9.2) inherits the same constraint — it saves with AI defaults, no per-item editing.
- No caching/history of past scans — every visit to the screen starts blank.
- No support for scanning a language different from the current `targetLanguage` setting in one paste.
- No microphone/OCR/URL-fetch input methods — paste only.
- No tap-to-navigate on the translation's highlighted meanings (§9.2) — read-only, unlike the original text's headword highlights.

---

## 9. Post-implementation changes

Everything above reflects the final shipped design. This section records what was added or fixed after the plan's 6 tasks were implemented and initially reviewed, driven by manual testing feedback — for full task-by-task history (including 2 rounds of task-review fixes during implementation), see `.superpowers/sdd/progress.md`'s "LexiCore — Word Radar" sections.

### 9.1 Vietnamese translation

Added per user request after using the shipped feature. Folded into the existing single AI call rather than a second one (§2). Required the type changes called out inline in §5.2–§5.5 above: `FindKnownHeadwordsUseCase` widened from `List<String>` to `List<VocabRecord>`, `WordRadarSource.scan()`/`GenerateWordSuggestionsUseCase.execute()` return the new `WordRadarAiResult` (`lib/features/word_radar/domain/entities/word_radar_ai_result.dart`) instead of a bare suggestions list, and `WordRadarState`'s fields renamed accordingly (`knownHeadwords`→`knownRecords`, `suggestions`→`aiResult`).

### 9.2 Suggestion-card UX overhaul

Added per user request after using the shipped feature. Replaced the original single trailing "Lưu" button with:

- **Tap the card** (when unsaved) to open `SaveVocabSheet` — same destination as the old button, different affordance.
- **Trailing slot**: a dismiss (✕) icon when unsaved (removes the suggestion from the visible list — "not interested"), a green checkmark when saved (card no longer tappable).
- **"Lưu tất cả"** button — bulk-saves every visible unsaved suggestion directly, reusing `SaveVocabSheet`'s own save defaults (topic matching against `suggestedTopics`, `cefrLevel ?? CEFRLevel.b1`) without opening a sheet per item; failures (e.g. duplicate headword) are skipped, not fatal to the rest of the batch.

Also simplified `_openKnownWord`: since `knownRecords` (§9.1) now holds full `VocabRecord`s already in memory, resolving a tapped headword to its `id` no longer needs the async `VocabRepository.getByHeadword` round-trip the original design used — it's a synchronous lookup against state.

The translation's highlighted meanings (§9.1) are deliberately **not** tappable — `_HighlightedText.onTapHighlight` was made optional so the translation instance can render plain, non-interactive spans. Two reasons: there's no natural single target to navigate to for a meaning-match the way there is for a headword-match, and it sidesteps a real layout quirk — a tappable highlight needs `WidgetSpan`+`GestureDetector` (to avoid `TextSpan.recognizer`'s manual-dispose burden), but `WidgetSpan` defaults to bottom-alignment and can't line-wrap mid-phrase, which is fine for short headwords but was visibly off for longer Vietnamese meaning phrases.

### 9.3 Defensive AI-response parsing (production bug fix)

Found via manual testing, not caught by any task review: the AI occasionally returns a bare string where `examples`/`suggestedTopics`/`synonyms` were asked for as a JSON array (e.g. `"suggestedTopics": "Business"` instead of `["Business"]`). The original `as List?` cast threw a `TypeError` on the wrong runtime type (not just on `null`, which the `?` only guards), crashing the entire suggestions batch for one malformed field on one item. `WordRadarSource._parseSuggestion` now goes through a small `_stringList()` helper that accepts a non-empty bare string as a single-item list instead of throwing.

### 9.4 `SaveVocabSheet` gets its own `SelectionArea` (cross-cutting fix, not Word-Radar-specific)

Found via manual testing of Word Radar's save flow, but the fix lives in shared code (`SaveVocabSheet`) also used by the Dictionary lookup's own "Save" button — not scoped to this feature, noted here because it was found and fixed in the same pass. The app-wide `SelectionArea` (`main.dart`) and a `showModalBottomSheet`'s content both sit under the same `Navigator`, but the sheet renders in a separate `OverlayEntry` stacked visually on top of whatever screen opened it. The outer `SelectionArea` attributed mouse drag-select events by widget-tree paint/traversal order, not visual z-order, so dragging over the sheet's own text (e.g. its read-only "Definition" field) selected the screen behind the sheet instead. Fix: wrap `SaveVocabSheet`'s returned `DraggableScrollableSheet` in its own nested `SelectionArea`, giving it an independent selection scope. `Ctrl+A`-select-all was unaffected by the bug (it already operated within whichever `SelectionArea` scope had focus); only mouse drag-select was misattributed.
