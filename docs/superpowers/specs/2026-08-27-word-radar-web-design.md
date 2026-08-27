# Quét từ vựng (Word Radar) on Web — Design

## Context

Word Radar is the last feature from Flutter's shipped set (README.md "Tính năng" → "Quét từ vựng") not yet ported to the React web app (`apps/web/`). Every other React Web Plan 3 phase (A/B/C) plus the deferred Dashboard is complete and deployed.

Flutter's real implementation, confirmed by reading the source (not from memory):

- `lib/features/word_radar/presentation/screens/word_radar_screen.dart` — paste box (`maxLength: 3000`), "Quét" button, then two sections once scanned: the pasted text with known Vocab Bank words highlighted (tap → navigate to that word's detail screen), and an AI section (translation + new-word suggestions).
- `lib/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart` — local substring match against the user's Vocab Bank (`_repo.getAll(language: language)`, filtered to the current target language), no AI, instant, works even with AI disabled.
- `lib/features/word_radar/data/sources/word_radar_source.dart` — **one AI call** returns both the Vietnamese translation of the whole text and up to 10 new-word suggestions (excluding already-known headwords), each with IPA/meaning/definition/synonyms/examples/topics/CEFR.
- `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart` — per-suggestion save (opens the same save sheet as Dictionary lookup), a bulk "Lưu tất cả", per-card dismiss (✕).
- Reached via a card in the Practice hub (`Luyện tập` → `Quét từ vựng`), not a top-level tab.

**Infrastructure already on web, discovered during exploration — most of this feature already half-exists:**

- `apps/web/src/lib/vocabSuggestions.ts` — `findKnownHeadwords`, `buildVocabSuggestionsPrompt`, `parseVocabSuggestions`. Its own code comment says it "ports `word_radar_source.dart`'s suggestion prompt, minus the `includeTranslation` branch" — built for a reading/listening result screen's "gợi ý từ mới" section, deliberately leaving out Word Radar's translation half.
- `apps/web/src/components/shared/VocabSuggestionsSection.tsx` — already does the whole "AI call → suggestion cards → per-card save (opens `EditVocabModal` in `"create"` mode) → bulk save → dismiss" flow, used by 5 existing result screens (bilingual, part5, part6, part7, comprehension).
- `apps/web/src/lib/vocabDraft.ts`'s `buildVocabRecordDraft`, `apps/web/src/lib/vocabRecords.ts`'s `getVocabRecordByHeadword`/`saveVocabRecord` — the save path, already reused everywhere.
- `apps/web/src/components/shared/PronunciationButton.tsx` (`.pron-btn` in `bloom.css`) — the exact "🔊" listen button already used in Tra từ, reused here rather than inventing new listen UI.

## Decisions made during brainstorming

- **Known-word tap → inline popover, no navigation.** Web's Vocab Bank has no per-record detail page (it opens an edit modal in place on the list page), so tapping a highlighted word shows a small popover right on the Word Radar page instead of navigating away: headword, a 🔊 `PronunciationButton` (`tier="word"`), IPA, Vietnamese meaning, CEFR pill. No examples/synonyms/personal notes — viewing/editing the full record is still possible by going to Vocab Bank directly, just not part of this flow.
- **Known-word matching filters by the current target language** (`record.targetLanguage === settings.targetLanguage`), matching Flutter's `getAll(language: language)`. This does **not** require the previously-decided-but-unimplemented per-language `vocab_records` collection split — `targetLanguage` is already a field on every `VocabRecord` in the single existing collection, and `getVocabRecordByHeadword` already filters on it the same way.
- **Reached via a 5th card in the Reading hub** (`/reading`), alongside Đọc & gõ / Part 5 / Part 6 / Part 7, not the Practice hub (matching where Flutter puts it) and not a new top-level sidebar entry. Clicking it navigates straight to `/reading/word-radar`, bypassing the hub's shared topic/CEFR/volume filter footer — that footer is a "configure → generate an exercise" flow specific to the other 4 cards; Word Radar has no generation step.
- **No new Cloud Function.** Reuses the existing `generateContent` onCall exactly like Tra từ and the 5 existing suggestion-section call sites — BYOK, same as everywhere else.

## Architecture

### `apps/web/src/lib/vocabSuggestions.ts` (modify)

Add an `includeTranslation` parameter to `buildVocabSuggestionsPrompt` and restore the translation field it deliberately left out, closing the gap its own comment documents — this makes the prompt match `word_radar_source.dart`'s real prompt exactly when `includeTranslation` is true, while every existing caller (the 5 result screens) keeps passing `false` and sees no change:

```ts
export function buildVocabSuggestionsPrompt(
  text: string,
  targetLanguage: TargetLanguage,
  knownHeadwords: string[],
  includeTranslation: boolean = false
): string
```

When `true`, the prompt asks for a `"translation"` field (Vietnamese, whole-text) alongside `"suggestions"`, worded the same way `word_radar_source.dart`'s `_buildPrompt` does (translate-then-suggest task framing, still exactly one AI call). `parseVocabSuggestions` gains a matching `translation: string` field on its return shape (empty string when the prompt didn't ask for one).

### `apps/web/src/components/shared/VocabSuggestionsSection.tsx` (modify)

Add an `includeTranslation?: boolean` prop (default `false`, so the 5 existing call sites are unaffected). When `true`:

- Passes `includeTranslation: true` into `buildVocabSuggestionsPrompt`.
- Renders the returned translation in a "Bản dịch" block above the existing "Gợi ý từ mới" block, using `HighlightedText` (see below) in static (non-clickable) mode to highlight the Vietnamese *meanings* of known words within the translation — mirroring Flutter's translation highlight exactly.

The component still returns `null` when AI is disabled (`!aiEnabled`), unchanged — Word Radar's page (not this shared component) is responsible for showing a fallback message in that case, so the 5 existing call sites keep their current "show nothing" behavior with zero risk of regression.

### `apps/web/src/components/shared/HighlightedText.tsx` (new)

A single component covering both of Word Radar's highlight needs:

```ts
interface HighlightedTextProps {
  text: string;
  variant: "interactive" | "static";
  // interactive: matches VocabRecord.headword substrings, tap opens a popover
  records?: VocabRecord[];
  ttsLanguage?: TtsLanguage | null;
  // static: matches arbitrary strings (e.g. known-word meanings), no popover
  highlights?: string[];
}
```

Case-insensitive substring match, ported from Flutter's `_HighlightedText` exactly: scans all candidate words for each one's earliest occurrence in the remaining text and highlights whichever candidate's earliest occurrence comes first overall, then continues from the end of that match — no overlapping highlights, and no length-based tie-break (matching Flutter's real behavior, not an idealized one). In `"interactive"` mode, clicking a highlighted span toggles a small popover positioned under that span (headword, `PronunciationButton`, IPA, meaning, CEFR pill — styled with the same tokens as `.pron-btn` and the existing card/pill classes, not new visual language). In `"static"` mode, spans are visually highlighted only, no click handler, no popover.

### `apps/web/src/app/(app)/reading/word-radar/page.tsx` (new)

- Textarea (`maxLength=3000`), live character counter, "Quét" button (disabled when empty).
- On "Quét": takes a client-side snapshot of `records` (already fetched via `getVocabRecords(uid)` on mount, filtered to `r.targetLanguage === settings.targetLanguage`) and renders the pasted text through `<HighlightedText variant="interactive" records={knownRecords} ttsLanguage={...} />` immediately — no AI call, works even when AI is disabled.
- Below that: if `settings.aiEnabled`, renders `<VocabSuggestionsSection text={...} existingRecords={knownRecords} topics={topics} includeTranslation />` (same component 5 other screens already use, just with the new prop). If AI is disabled, renders the Vietnamese hint "Bật AI trong Cài đặt để nhận gợi ý từ mới." instead — matching Flutter's exact message.
- No new save/error-handling logic — the suggestion-save flow (including duplicate-check, dismiss, bulk save, and the AI-failure `role="alert"` + "Thử lại" retry) is entirely `VocabSuggestionsSection`'s existing, already-shipped behavior.

### `apps/web/src/app/(app)/reading/page.tsx` (modify)

Add a 5th card, "🔎 Quét từ vựng", to the existing `reading-hub-cards` grid. Unlike the other 4 (`bilingual`/`part5`/`part6`/`part7`, which set `mode` and reveal the shared filter footer), this card navigates directly: `onClick={() => router.push("/reading/word-radar")}`, no `mode` state involved, no filter footer ever shown for it.

## Error Handling

- AI call (translation + suggestions) fails: `VocabSuggestionsSection`'s existing `role="alert"` message + "Thử lại" retry button — no new error path.
- Text empty: "Quét" button disabled, no error state needed.
- Text at/over 3000 chars: `maxLength` on the textarea blocks further input (matches Flutter — a hard cap, not a validation error).
- No known words matched: the highlighted-text section still renders, simply with no highlighted spans — no separate empty state.
- AI disabled: page shows the static Vietnamese hint in place of `VocabSuggestionsSection`, as described above.

## Testing

- `vocabSuggestions.test.ts`: `buildVocabSuggestionsPrompt`/`parseVocabSuggestions` with `includeTranslation` true and false (existing false-path tests must keep passing unchanged).
- `VocabSuggestionsSection.test.tsx`: new case(s) for `includeTranslation` — translation renders above suggestions, known-word meanings highlighted within it; existing 5 call sites' tests (which don't pass the prop) must keep passing unchanged.
- `HighlightedText.test.tsx` (new component, new test file): case-insensitive substring matching, first-match-wins on overlapping candidates, interactive mode's popover open/close + `PronunciationButton` rendering, static mode never renders a popover or click handler.
- `reading/word-radar/page.test.tsx` (new): known-word highlight appears instantly without AI enabled, language filter excludes records of a different `targetLanguage`, "Bật AI" hint shows when AI is disabled, char counter/disabled-button behavior, `maxLength` enforcement.
- `reading/page.test.tsx`: new card renders and navigates to `/reading/word-radar` without touching `mode`/filter-footer state; existing 4-card tests unaffected.
