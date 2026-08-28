# Tách `vocab_records` theo ngôn ngữ mục tiêu — Design

## Context

`users/{uid}/vocab_records` is currently a single flat Firestore collection (~290+ real production records) shared across every target language the user has ever saved words in, filtered client-side by each record's own `targetLanguage` field wherever filtering happens at all. Both apps read/write this same collection directly — `apps/web/src/lib/vocabRecords.ts` (Next.js, always Firestore-direct) and `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` (Flutter, Firestore-direct as of the just-shipped `2026-08-27-flutter-drop-hive` plan, which removed the bidirectional Hive↔Firestore sync engine that would otherwise have made this split require rewriting a multi-collection sync listener).

The user first decided to split this collection per target language on 2026-08-16 (documented in `docs/superpowers/specs/2026-08-11-react-web-redesign-design.md` §9), motivated by the app's "Ngôn ngữ mục tiêu" (target language) setting making per-language storage the more natural fit than one shared collection filtered by a field. Implementation was deferred until the Hive-sync blocker was removed.

**Discovered during this brainstorm, not previously known:** almost nothing in the current web app actually filters vocab records by language today — confirmed by grep. `getVocabRecords(uid)` is called unfiltered from 12 different pages (Dashboard, Vocab Bank, Practice, all 4 Reading modes, both Listening modes), meaning a user learning multiple languages currently gets them all mixed into one pool for practice-session generation, not just for the overview screens. Only Word Radar (client-side `.filter`) and headword-duplicate-checking (`getVocabRecordByHeadword`, which already takes an explicit `language` param) scope by language today. The Flutter side shows the identical pattern: `StatsService`/`notification_notifier.dart` call `VocabRepository.getAll()` with no language filter; only `find_known_headwords_use_case.dart` (Word Radar's Flutter equivalent) passes one.

## Decisions made during brainstorming

- **Every consumer on both platforms now filters to the current `targetLanguage` — no cross-language aggregation remains anywhere**, including Dashboard/Tổng quan and Vocab Bank/Ngân hàng từ vựng (both previously unfiltered, now explicitly decided to scope to the current language like everything else). This is a genuine behavior change for Practice/Reading/Listening/Dashboard/Vocab-Bank, not just a storage refactor — a user with vocab in multiple languages will, after this ships, only ever see/practice one language's words at a time, matching what "Ngôn ngữ mục tiêu" implies but never actually enforced.
- Since no consumer needs cross-language aggregation anymore, `language`/`targetLanguage` becomes a **required** parameter everywhere it touches vocab reads/writes on both platforms — no optional/fan-out-and-merge mode.
- **Rollout risk is low**: the Flutter mobile app has never been installed/distributed anywhere (confirmed with the user) — the only live, real-usage surfaces are Flutter Web and the React web app, both deployed via Firebase Hosting from this same repo, both redeployed together after this change lands. No app-store rollout lag, no stale-client window to coordinate around.
- **Migration is a one-time manual script**, not a Cloud Function — run once by hand from a dev machine using the Firebase Admin SDK, with clear logging of what moved. The old `vocab_records` collection is **not deleted** by the script — left in place as a backup, removed manually later once both apps are confirmed working against the new collections.
- Deploy order: update both apps' code first (not yet deployed) → run the migration script against production Firestore → deploy Flutter Web and the React web app together.

## Architecture

### Collection naming

`users/{uid}/vocab_records_{language}`, where `{language}` is the lowercase enum name already shared identically between both platforms (`vietnamese`, `english`, `chinese`, `korean`, `japanese` — confirmed byte-identical between web's `TargetLanguage` type and Flutter's `Language` enum, so no translation table is needed). E.g. `users/{uid}/vocab_records_english`.

`topics` stays a single shared collection, unsplit (unchanged decision from 2026-08-16).

### Web (`apps/web/src/lib/vocabRecords.ts`)

Every exported function gains a required `language: VocabRecord["targetLanguage"]` parameter (or keeps its existing one, for the 2 functions that already take it) and targets `vocab_records_{language}` instead of the flat `vocab_records` collection:

- `getVocabRecords(uid, language)` — was `(uid)`. All 12 call sites (Dashboard, Vocab Bank, Practice, Reading×4, Listening×2, Word Radar, and their tests) pass `settings.targetLanguage`.
- `countVocabRecords(uid, language)` — was `(uid)`. 1 call site (`VocabRecordCount.tsx`).
- `deleteVocabRecord(uid, id, language)` — was `(uid, id)`. 1 call site (`vocab-bank/page.tsx`), which already has the selected record (and thus its `targetLanguage`) in scope.
- `updateVocabRecord(uid, id, updates, language)` — was `(uid, id, updates)`. Same call site, same source for `language`.
- `updateVocabRecordSm2(uid, id, sm2Fields, language)` — was `(uid, id, sm2Fields)`. 2 call sites (`practice/page.tsx`, `listening/dictation/page.tsx`) — both already have the record (and its `targetLanguage`) in scope from the session they're grading.
- `getVocabRecordByHeadword(uid, headword, language)` — signature unchanged (already took `language`), only its internal Firestore path changes.
- `saveVocabRecord(uid, record)` — signature unchanged; `record.targetLanguage` (already required on every `VocabRecord`) determines the target collection internally, so no call site needs to change.

### Flutter (`lib/features/vocabulary/data/repositories/vocab_repository_impl.dart` + `VocabRepository` interface)

`getAll({required Language language, String? topicId, InputType? inputType, CEFRLevel? maxCefrLevel, bool dueOnly = false})` — `language` moves from optional to required (a real interface change, needs updating at all 4 real call sites: `stats_service.dart`, `notification_notifier.dart`, `get_vocab_list_use_case.dart`, `find_known_headwords_use_case.dart` — the first 2 currently pass no language at all and need a source for it, likely `ref.read(userSettingsNotifierProvider).targetLanguage`, matching how web call sites source it from `settings.targetLanguage`).

`getById`, `update`, `delete` all operate on a single record by `id` — since the record itself carries `targetLanguage`, these can either take an explicit `language` parameter (mirroring the web API) or internally resolve which collection to query by first reading the record's own language from a passed-in `VocabRecord` rather than a bare `id` string; exact signature to finalize during planning by checking what's actually available at each of this interface's real call sites.

`existsByHeadword`/`getByHeadword` — already take `language`, only the internal path changes.

`getTopics`/`addTopic`/`deleteTopic` — unchanged, `topics` isn't split.

### Migration script

A standalone Node.js script (not a Cloud Function), using `firebase-admin`, run manually once against production Firestore:

1. List every document in the top-level `users` collection to get every `uid`, then read every document in that user's `vocab_records` subcollection.
2. For each record, read its own `targetLanguage` field.
3. Write it (same `id`, same full document body) into `users/{uid}/vocab_records_{targetLanguage}`.
4. Log a per-user, per-language count of records moved, and any record whose `targetLanguage` is missing/invalid (flag for manual review, don't silently drop or guess).
5. Do **not** delete the original `vocab_records` collection — left as a backup.

### Deploy sequencing

1. Land and commit both apps' code changes (this plan's implementation), not yet deployed.
2. Run the migration script against production Firestore.
3. Deploy Flutter Web (`flutter build web --release` + `firebase deploy --only hosting`) and the React web app (push triggers App Hosting auto-deploy) together, in the same session.
4. Manually verify both surfaces read real per-language data correctly before considering the old `vocab_records` collection safe to delete (a separate, later manual step — not part of this plan).

## Error Handling

- Migration script: a record with a missing/invalid `targetLanguage` is logged and skipped, not silently dropped or defaulted to a guessed language — surfaced for manual review after the script completes.
- Both apps: a Firestore read/write failure on any per-language collection uses the exact same error-handling convention already established at each call site today (this plan changes which collection is targeted, not how errors from that collection are handled) — no new error-handling design needed beyond what's already in place.

## Testing

- Web: every modified function in `vocabRecords.test.ts` gets its Firestore-path assertions updated to the per-language collection path; each call site's own test file (Dashboard, Vocab Bank, Practice, Reading×4, Listening×2, Word Radar) gets its mock updated to expect the new required `language` argument.
- Flutter: `vocab_repository_impl_test.dart` (already using `fake_cloud_firestore` from the drop-Hive plan) gets new/updated tests asserting reads/writes target `vocab_records_{language}` paths correctly, and that mixing two languages' records in the fake Firestore never cross-contaminates a single-language `getAll()` call.
- Migration script: a dry-run/test mode against `fake_cloud_firestore` (Node.js) or the Firebase Local Emulator Suite, covering: multiple users, multiple languages per user, a record with a missing `targetLanguage` (flagged not dropped), and confirming the original collection is untouched afterward.
