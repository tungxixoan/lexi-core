# LexiCore — "Word Radar" Design Spec

**Date:** 2026-07-26
**Status:** Approved
**Covers:** New feature — paste arbitrary text, highlight words already in Vocab Bank, get AI-suggested new words to learn from the same text, save with one tap. Plus a related fix: `WordPhraseResult`/`SaveVocabSheet` currently hardcode `CEFRLevel.b1` on every save regardless of the word's actual level; this spec adds an AI-sourced `cefrLevel` used when available.

**Depends on:** Practice hub restructuring (bottom nav now Dictionary/Vocab Bank/Luyện tập/Cài đặt; `/practice` is a card hub). Word Radar is the hub's 5th card.

---

## 1. Goal

Turn any pasted text (an article, a chat, a paragraph) into a two-part learning aid:

1. **Known-word recall** — words already in the user's Vocab Bank are highlighted inline, for free (no AI), instantly.
2. **New-word discovery** — an AI call reads the same text and suggests words worth learning at the user's target CEFR level, excluding anything already known, with enough detail (IPA/meaning/definition/synonyms/examples/topic/level) to save in one tap.

This is the first LexiCore feature where the input is user-supplied real-world text rather than AI-generated content.

---

## 2. Scope & Non-Goals

- **No new tokenizer.** Highlighting uses plain case-insensitive substring matching, the same approach already shipped in `reading_session_screen.dart`'s `_HighlightedText`. This works unmodified for Chinese/Japanese (no word boundaries needed) and is an accepted-risk simplification for space-delimited languages (a saved word can match inside a longer word) — consistent with this codebase's existing tolerance for that exact trade-off.
- **One AI call per scan**, not one per suggested word. The prompt returns full `WordPhraseResult`-shaped data (ipa/meaning/definition/synonyms/examples/suggestedTopics/cefrLevel) for every suggestion, so saving never triggers a second lookup call.
- **Not scoped:** multi-language text in a single paste — the scan assumes the pasted text is in the currently selected `targetLanguage`, same assumption every other AI feature in the app makes.
- **Not scoped:** editing/removing a known-word highlight in place, or re-scanning incrementally as the user types (scan only runs on explicit button press).
- **Duplication is intentional, not an oversight:** the highlighted-text renderer will be a second, private, near-identical copy of `_HighlightedText` local to the new screen — not extracted into a shared widget. This matches the codebase's established precedent (`_SpeedSelector`, `_ClozeInput`/`_ClozeResult`) of accepting byte-similar duplication at 2 call sites over premature abstraction.

---

## 3. Entry point & navigation

- New 5th card in `PracticeHubScreen`: title **"Quét từ vựng"**, subtitle "Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học."
- Route: `/practice/radar`, nested under the existing `/practice` `GoRoute`.
- `WordRadarScreen` AppBar gets the same `leading: BackButton(onPressed: () => context.go('/practice'))` pattern as the other 3 hub cards (Từ vựng cách khoảng / Đọc & gõ / Luyện nghe), for nav consistency.

---

## 4. Flow

1. User opens the screen: a multiline `TextField` (paste target) + a **"Quét"** `FilledButton`, initially disabled while the field is empty.
2. Input is capped at **3000 characters** client-side; exceeding it disables the Quét button and shows a counter/error, rather than truncating silently.
3. On Quét:
   - **Local pass (synchronous, no AI):** load `VocabRepository.getAll(language: targetLanguage)`, then for each record check `text.toLowerCase().contains(headword.toLowerCase())`. Matches become `knownHeadwords`. The original text renders immediately with matches bolded/underlined (own copy of the `_HighlightedText` pattern) — this part works even if AI is off.
   - **AI pass (async, only if `aiEnabled`):** call `WordRadarSource.scan(text, targetLanguage, targetCefrLevel, knownHeadwords)`. Shows a loading indicator under the highlighted text while pending.
4. AI suggestions render as a list of cards below the text (headword, ipa, meaning, cefrLevel chip), each with a **"Lưu"** button.
5. Tapping "Lưu" opens the existing `SaveVocabSheet(result: suggestion)` unmodified — same edit-before-save UX as Dictionary lookup (topic pre-selection from `suggestedTopics`, editable meaning/examples/notes). After a successful save, that card is marked "Đã lưu" (disabled) rather than removed, so the user keeps context on what they just added.
6. Tapping a highlighted known word in the text pushes `VocabDetailScreen` for that record (reuses the existing screen; look it up via `VocabRepository.getByHeadword`).
7. If `aiEnabled == false`: skip step 3's AI pass entirely, show only the local highlight result plus a dismissible note: "Bật AI trong Cài đặt để nhận gợi ý từ mới."
8. If AI is enabled but the local pass found zero matching Vocab Bank words at all: still proceed with the AI pass (an empty `knownHeadwords` list is valid — nothing to exclude).

---

## 5. Data & Architecture

New top-level feature folder `lib/features/word_radar/`, **not** nested under `practice/` — same precedent as `reading/` and `listening/`, which are also reached exclusively via a Practice hub card yet are independent top-level features with their own `data/domain/presentation` layers. Folder placement follows domain ownership, not hub membership. No new bundled "result" entity — the local pass and the AI pass are two independently-timed operations (see §5.5), each already returning an existing/plain type (`List<String>`, `List<WordPhraseResult>`), so there's nothing to wrap.

### 5.1 Shared schema fix (used by both Word Radar and the existing Dictionary lookup)

- `WordPhraseResult` (`lib/features/dictionary/domain/entities/lookup_result.dart`) gains one field: `final CEFRLevel? cefrLevel;` defaulting to `null`. Backward compatible — every existing construction site keeps compiling unchanged.
- `GeminiDictionarySource._wordPhrasePrompt` — add `"cefrLevel":"a1|a2|b1|b2|c1|c2 for this word/sense"` to the requested JSON shape; parse with `CEFRLevel.values.byName((json['cefrLevel'] as String).toLowerCase())`, unguarded (consistent with this codebase's existing risk tolerance for AI-sourced enum parsing, e.g. `AiProvider.values.byName()`).
- `FreeDictionarySource` (English, no AI) — unchanged, `cefrLevel` stays `null`.
- `SaveVocabSheet._save()` — change `cefrLevel: CEFRLevel.b1` to `cefrLevel: widget.result.cefrLevel ?? CEFRLevel.b1`. Net effect: any save that came from an AI-sourced `WordPhraseResult` (regular AI-enabled Dictionary lookup, or Word Radar) now stores the real level; Free Dictionary saves and any other still-null case keep today's B1 default.

### 5.2 `FindKnownHeadwordsUseCase` (new, `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart`)

```dart
Future<List<String>> execute({required String text, required Language language})
```

Thin wrapper: calls the existing `VocabRepository.getAll(language: language)`, then for each record checks `text.toLowerCase().contains(record.headword.toLowerCase())`. Returns matching headwords, deduped. No AI, no new I/O — reuses the same repository every other vocab-listing use case already goes through.

### 5.3 `WordRadarSource` (new, `lib/features/word_radar/data/sources/word_radar_source.dart`, mirrors `ListeningPassageSource`'s constructor/DI pattern exactly)

```dart
Future<List<WordPhraseResult>> scan({
  required String text,
  required Language targetLanguage,
  required CEFRLevel? targetCefrLevel,
  required List<String> knownHeadwords,
})
```

Prompt: "You are a language learning assistant helping a Vietnamese speaker learn {targetLanguage}. Given this text: \"{text}\", suggest up to 10 words or short phrases from it worth learning at {level or 'any'} level, for a Vietnamese speaker. Do NOT suggest any of these already-known words: [{knownHeadwords}]. Respond with JSON only: {"suggestions":[{same per-item shape as GeminiDictionarySource's word/phrase JSON, including cefrLevel}]}". Empty `suggestions` array is valid (nothing new to suggest) and not an error.

### 5.4 `GenerateWordSuggestionsUseCase` (new, `lib/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart`)

Thin wrapper around `WordRadarSource.scan(...)`, same shape/role as `GenerateListeningPassageUseCase`/`GenerateDictationItemUseCase` wrapping their respective sources.

### 5.5 `WordRadarNotifier` (new, Riverpod, `lib/features/word_radar/presentation/providers/`)

Two independently-timed pieces of state, matching the two-stage UX in §4 (highlights appear immediately, suggestions catch up):

```dart
class WordRadarState {
  final List<String>? knownHeadwords;       // null = not scanned yet
  final AsyncValue<List<WordPhraseResult>>? suggestions; // null = AI not run (disabled or not reached yet)
}
```

`scan(String text)`:

1. Calls `FindKnownHeadwordsUseCase`, sets `knownHeadwords` on the state immediately — this alone is enough for the screen to render the highlighted text, before anything AI-related starts.
2. If `aiEnabled`: sets `suggestions` to `AsyncValue.loading()`, then calls `GenerateWordSuggestionsUseCase(text, targetLanguage, targetCefrLevel, knownHeadwords)` (passing the headwords found in step 1) and updates `suggestions` to `AsyncData`/`AsyncError`.
3. If not `aiEnabled`: leaves `suggestions` as `null` — the screen distinguishes "AI off" (`null`) from "AI ran, found nothing" (`AsyncData([])`) to show the right message in each case.

### 5.6 `WordRadarScreen` (new, `lib/features/word_radar/presentation/screens/`)

Per the flow in §4. `knownHeadwords` drives the highlighted-text render as soon as it's non-null (independent of the AI state). The suggestions area switches on `suggestions`: `null` → "Bật AI trong Cài đặt..." note; `AsyncValue.loading()` → spinner; `AsyncData([])` → "Không có gợi ý mới"; `AsyncData(list)` → suggestion cards; `AsyncError` → inline error + "Thử lại" (re-runs only step 2, not the whole scan).

---

## 6. Error handling

- AI call failure (network/parse) — the local highlight result still displays; suggestions section shows an inline error + "Thử lại" retry button, matching the `AsyncValue.guard` pattern used elsewhere (e.g. `ReadingPassageSource`/`ListeningPassageSource` callers).
- Empty pasted text — Quét button stays disabled (already covered in §4.2).
- A suggested word that turns out to already exist in Vocab Bank (AI ignored the exclusion list) — `SaveVocabSheet`'s save path already goes through `SaveVocabUseCase`, which throws `VocabException` on duplicate headword; the existing sheet's catch-and-snackbar handling covers this with no new code needed.

---

## 7. Testing

Follows this codebase's existing layering:

- `FindKnownHeadwordsUseCase` — unit tests for the substring-match logic in isolation (English/Vietnamese word-boundary edge cases, Chinese/Japanese no-space text, empty Vocab Bank).
- `WordRadarSource` — unit tests with a fake `GenerativeModelClient`, same pattern as `listening_passage_source_test.dart` (empty suggestions array, malformed JSON, exclusion list actually included in the prompt).
- `WordRadarNotifier` — provider tests: `knownHeadwords` populates before `suggestions` resolves (two-stage ordering), AI-disabled leaves `suggestions` null, scan success/failure states, retry only re-runs the AI step.
- `WordRadarScreen` — widget tests for: known-word highlight rendering, tapping a suggestion's Lưu opens `SaveVocabSheet`, AI-disabled note shown/hidden correctly, input length cap.
- `SaveVocabSheet` — add a case confirming `cefrLevel` falls through from `widget.result.cefrLevel` when present, and defaults to B1 when null (regression-proofs the shared fix in §5.1).

---

## 8. Explicitly not done

- No edit UI for the AI-suggested `cefrLevel` before saving (user can still edit everything else `SaveVocabSheet` already allows editing; level is accepted as-is or falls back to B1 — matching how `ipa`/`definition` are already read-only in that sheet).
- No caching/history of past scans — every visit to the screen starts blank.
- No support for scanning a language different from the current `targetLanguage` setting in one paste.
- No microphone/OCR/URL-fetch input methods — paste only.
