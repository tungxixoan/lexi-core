# LexiCore — Vocab `definition`/`synonyms` Fields + Bulk Import

**Date:** 2026-07-19
**Status:** Implemented
**Covers:** `VocabRecord` schema extension, dictionary lookup (AI + Free Dictionary) prompt/parsing changes, related UI, one-off bulk import tooling, and a related word-selection bug fix in Luyện đọc & gõ.

---

## 1. Why this happened

The user had ~300 hand-curated English words in a personal Google Sheet (`Master_List`: headword, part of speech, IPA, synonyms, English definition, Vietnamese translation/explanation, example, topic, personal notes) they wanted in their Vocab Bank instead of re-adding each one through the app. That required two things `VocabRecord` didn't have — an English `definition` separate from the existing Vietnamese `meaning`, and a `synonyms` list — plus a one-time way to get ~300 rows into Firestore without building a permanent import feature for something that runs once.

---

## 2. Schema change

`lib/features/vocabulary/domain/entities/vocab_record.dart` gained two fields, both optional with safe defaults so existing Hive/Firestore records (which predate this change) deserialize without a migration:

```dart
final String definition;      // English definition, default ''
final List<String> synonyms;  // default const []
```

Both are wired through `copyWith`, `toJson`, and `fromJson` the same way `personalNotes`/`sm2Repetitions` already were (`json['x'] as T? ?? default`). This is safe because both Hive (`Box<String>` storing `jsonEncode(record.toJson())`) and Firestore sync (`sync_service.dart` moves raw `Map<String, dynamic>` around, never touching `VocabRecord.toJson()/fromJson()` directly) are schema-less — old records simply don't have these keys until they're next saved.

`partOfSpeech` was deliberately **not** added as a field. Multi-sense words (e.g. "record" as both noun and verb) are instead written inline into `meaning`/`definition`/`ipa` using a `(n) ...; (v) ...` convention, matching how the app already displayed a hand-entered "record" example before this change.

---

## 3. Dictionary lookup changes

### 3.1 `LookupResult.WordPhraseResult`
Gained the same `definition`/`synonyms` fields (default `''`/`const []`) so both lookup sources can populate them.

### 3.2 `GeminiDictionarySource`
The word/phrase prompt now asks for `"definition"` (English) and `"synonyms"` (2-4 items) alongside the existing fields, and instructs the model to use the `(n) ...; (v) ...` convention — with per-sense IPA too (`"N: ...; V: ..."`) — when a word has multiple common parts of speech.

### 3.3 `FreeDictionarySource`
The Free Dictionary API already returns English definitions and per-meaning/per-definition `synonyms` arrays natively. `definition` now reuses the same text as `meaning` (this path has no Vietnamese translation step), and `synonyms` collects+dedupes the API's own synonym arrays (capped at 4).

### 3.4 UI
Read-only display added in three places, all following the existing pattern (no edit controls added — out of scope for this pass):
- `WordResultWidget` (pre-save lookup card): definition as a small italic caption under `meaning`, synonyms as a chip `Wrap`.
- `SaveVocabSheet`: "Definition" and "Synonyms" sections between Meaning and Examples.
- `VocabDetailScreen`: same sections, shown only when non-empty, in both view and edit mode (edit mode doesn't yet let you change these two fields).

`SaveVocabSheet._save()` now passes `widget.result.definition`/`.synonyms` through into the created `VocabRecord`.

---

## 4. Bulk import (`scripts/import-vocab/`)

One-off Node.js tooling, **not shipped with the app** (lives outside `lib/`, has its own `package.json`). Kept in git as a record of how the import was done; not wired into any app feature or CI.

### 4.1 Data prep (`prepare_data.py`, run locally, not part of the committed pipeline output)
Read the source `.xlsx` (`Master_List` sheet, 299 rows) with `openpyxl` and did a deterministic pass:
- **Column mapping:** `Từ vựng`→headword, `Mean`→`definition`, `Ý nghĩa`→dropped (unused — "Dịch nghĩa" was the better fit for the app's existing `meaning` convention, confirmed against real saved records like "record"), `Dịch nghĩa`→`meaning`, `Từ đồng nghĩa`→`synonyms` (parsed: split on newline, strip leading `- ` and trailing `,`, drop literal "None"), `Ghi chú`/`Audio`/`Pronounce`/`Ran`→**ignored entirely** (verified these were boilerplate "🔊 Audio"/"🔊 Nghe" button labels and a random sort key, not real data).
- **Topic mapping:** sheet topics → app topics. Exact/close matches reused predefined `Topic` ids (`Workplace`/`Negotiation`/`Office English`→`business`, `IT/Technical`→`technology`, `Daily Life`→`daily-life`, `Academic`→`academic`); `Project Management`, `Personal Well-being`, and `Meetings` had no good predefined fit and became new custom topics.
- **Duplicate headwords (12 groups, 25 rows):** where a headword had multiple rows with genuinely different parts of speech (`update` N/V, `follow up` P/N, `overhead` N/Adv, `commute` V/N, `compromise` V/N), rows were merged into one record using the `(pos) ...; (pos) ...` convention. Where rows were same-POS near-duplicates (typos/re-entries), one row was picked by hand and the rest discarded — final record count: **286**.

### 4.2 AI enrichment (dispatched agents, not a runtime script dependency)
`cefrLevel` (required field, absent from the sheet) and missing `synonyms` (205 of 286 rows) were generated by dispatching 5 parallel agents over even chunks of the 286 records, each returning strict JSON. This was a deliberate choice over having `import.js` call an LLM API at runtime — no rate limiting/retry logic needed in the script, and the output could be reviewed as a plain file before any Firestore write.

### 4.3 Spellcheck pass
A second round of 5 parallel agents proofread every field (headword, definition, meaning, examples, synonyms) for genuine typos only (not style/wording), conservative about jargon vs. real mistakes. 113 of 286 records got at least one fix (8 of them a headword rename, e.g. "Overhual"→"Overhaul"). Applied as a second Firestore **update** pass (matched by old headword text) after the initial import, rather than re-running the import — see `update_spellfix.js`.

### 4.4 `import.js`
```
node import.js --email=<login email> [--commit]
```
- Resolves the target user's Firestore UID via `admin.auth().getUserByEmail()` — no manual UID lookup needed.
- **Dry-run by default**: prints how many records would import vs. skip (deduped by case-insensitive headword against the account's existing `english` records) without writing anything. `--commit` is required to actually write.
- On commit: upserts the 3 new custom topics (`set`, idempotent), then batch-writes new `vocab_records` docs (id via `uuid`, `createdAt`/`updatedAt` = now, SM-2 fields at their just-added-word defaults, `nextReviewAt: null` so they surface as due immediately — same defaults `SaveVocabUseCase` uses for a normal single-word save).
- Run twice, once per `--email`, for the two accounts that needed this data (`tungxixoan@gmail.com`, `dmtung.dev@gmail.com`) — dedup and topic creation are naturally per-account since each writes under its own `users/{uid}/...` subtree.

### 4.5 Cleanup
The service account key and source `.xlsx` were deleted after both accounts were confirmed imported (per explicit instruction — this data is not meant to live in the repo). `.gitignore` was extended to guard against ever committing a `*firebase-adminsdk*.json` file or anything under `scripts/import-vocab/` other than `package.json` and the `.js`/`.py` source files, plus a general `**/node_modules/` rule (previously missing from this repo's `.gitignore`).

---

## 5. Related fix: random word selection in Luyện đọc & gõ

Found while testing the freshly-imported data: `reading_home_screen.dart`'s word-count picker sorted candidates by (due-first, then `createdAt` descending) and took the first N — deterministic, not random. Every word from the bulk import starts with `nextReviewAt == null` (counts as due), so with more due words than the selected count, generating a passage always pulled the same "newest" slice.

Fix: partition into due/not-due, `shuffle()` each list independently, concatenate due-then-not-due, then take N. Due words still get priority (SRS value preserved), but which due words appear is now random per generation instead of a fixed slice.

---

## 6. Explicitly not done

- No in-app "Import from CSV/Excel" feature — this was a one-time need; see `docs/superpowers/specs/*` roadmap note in the README if that changes.
- No edit UI for `definition`/`synonyms` on `VocabDetailScreen` — display only for now.
- `partOfSpeech` is not a queryable/filterable field anywhere; it only exists as inline text inside `meaning`/`definition`/`ipa` for multi-sense words.
- Listening/pronunciation practice — discussed as a follow-up feature idea during this session, not started.
