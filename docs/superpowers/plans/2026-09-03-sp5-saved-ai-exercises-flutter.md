# SP-5: Saved AI exercises on Flutter ("Lưu bài" / "Lấy bài có sẵn")

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Port the web's "save a generated exercise / reuse a saved one" feature to Flutter for all five AI-generated exercise types — Đọc & gõ (bilingual), TOEIC Part 5/6/7, and Nghe chép (dictation), Nghe hiểu (comprehension).

**Architecture:** One `SavedExercisesService` writing the SAME two Firestore collections the web uses — `users/{uid}/reading_exercises` (bilingual + part5/6/7) and `users/{uid}/listening_exercises` (dictation + comprehension) — with byte-compatible document shapes so a doc saved on one platform loads on the other. Each session notifier gains a `loadSaved(...)` method (populates its state from a pre-built passage/set, bypassing the AI). Each home screen gains a "Lấy bài có sẵn" button; each result screen gains a "Lưu bài" button.

**Tech Stack:** Flutter, `cloud_firestore` (+ `fake_cloud_firestore` for tests), `firebase_auth`, `flutter_riverpod`. Bloom widgets.

## Global Constraints

- **Firestore doc shapes must match `apps/web/src/lib/savedReadingExercises.ts` and `savedListeningExercises.ts` exactly** — same collection names, same field names (`type`, `passage`, `generationFilters`, `targetLanguage`, `createdAt` ISO string, `id` in the body). Read those two web files before writing the service. A reading doc's `type` is `'bilingual'|'part5'|'part6'|'part7'`; a listening doc's is `'dictation'|'comprehension'`.
- **`passage` sub-object** = the JSON of the Flutter entity (`ReadingPassage` / `Part5Set` / `Part6Set` / `Part7Set` / `DictationItem` / `ComprehensionItem`). If an entity has no `toJson`/`fromJson`, add them (mirror the web TS shape field-for-field — e.g. web `ReadingPassage` has `sentences: [{target, vietnamese, vocabWords}]`, `vocabIds`). This is the fiddliest part — verify each against the web type.
- **`generationFilters`** — reading bilingual: `{topicIds: string[], maxCefr: string|null, wordCount: int|null}`; reading toeic (part5/6/7): `{topicIds: string[], volumes: string[]}`; dictation: `{difficulty: string}`; comprehension: `{context: string, level: string|null}`. Match web's `BilingualFilters` / `ToeicFilters` / `DictationFilters` / `ComprehensionFilters`.
- **Matching logic** (`getRandomSavedExercise`) — port web's `matchesBilingual` / `matchesToeic` and the dictation/comprehension equivalents verbatim (topic overlap, `maxCefr` ceiling via CEFR order, `wordCount` exact, `volumes` overlap, dictation `difficulty` exact, comprehension `context` exact + `level` null-or-ceiling). Random pick among matches; `excludeId` param to skip the just-saved one on "Bài khác".
- **`prioritizeUnusedWords`** (bilingual only) — port web's: words never used in any saved bilingual exercise sort after unused ones, so repeated generation varies. Apply in `reading_home_screen._generate`.
- **Colors** via `context.bloom`, no raw `Colors.*`/`Color(0x...)`. `flutter analyze` stays 0.
- **Tests** only go up (currently 780). New service tests with `FakeFirebaseFirestore` + a fixed uid (see `stats_service_test.dart` for the pattern). Screen tests: the 5 home + 5 result screens' tests get the new button asserted; behavior assertions preserved.
- **`apps/web/` is never touched.**

## File Structure

**Created:**
- `lib/features/practice/domain/entities/saved_exercise.dart` — `SavedExerciseType` enum + filter classes
- `lib/core/services/saved_exercises_service.dart` — `SavedExercisesService`
- `lib/core/services/saved_exercises_service_test.dart`
- `toJson`/`fromJson` on the entities that lack them (`reading_passage.dart`, `part5_set.dart`, `part6_set.dart`, `part7_set.dart`, `dictation_item.dart`, `listening_passage.dart` — check each)

**Modified:**
- `lib/core/di/app_providers.dart` — `savedExercisesServiceProvider`
- The 6 session notifiers — add `loadSaved(...)`
- `reading_home_screen.dart`, `part5/6/7_home_screen.dart`, `dictation_home_screen.dart`, `comprehension_home_screen.dart` — "Lấy bài có sẵn" button + fetch flow; reading_home also `prioritizeUnusedWords`
- `reading_result_screen.dart`, `part5/6/7_result_screen.dart`, `dictation_result_screen.dart`, `comprehension_result_screen.dart` — "Lưu bài" button (hidden once saved / for a reused exercise)
- The matching `*_test.dart` files

---

## Task 1: Entity JSON round-trips

**Files:** the reading/listening passage + set entities. **For each** (`ReadingPassage`, `Part5Set`, `Part5Question`, `Part6Set`+children, `Part7Set`+children, `DictationItem`, `BlankSpan`, `ListeningPassage`+`ListeningTurn`+`ListeningQuestion`): if it has no `Map<String,dynamic> toJson()` + `fromJson(Map)` factory, add them. Field names MUST match the web TS type (open `apps/web/src/lib/readingPassage.ts`, `part5.ts`, `part6.ts`, `part7.ts`, `dictation.ts`, `listeningPassage.ts`).

- [ ] Step 1 (per entity): write a `toJson`↔`fromJson` round-trip test in the entity's existing test file (or a new one).
- [ ] Step 2: run it (RED — no `toJson`).
- [ ] Step 3: add `toJson`/`fromJson`. Enums serialize as `.name`; DateTimes as `.toIso8601String()`.
- [ ] Step 4: GREEN. `flutter analyze` clean.
- [ ] Step 5: commit `feat(entities): JSON round-trips for reading/listening exercises`.

## Task 2: SavedExercisesService + filter model

**Files:** `saved_exercise.dart`, `saved_exercises_service.dart`, `saved_exercises_service_test.dart`, `app_providers.dart`.

**Interface:**
```dart
enum SavedExerciseType { bilingual, part5, part6, part7, dictation, comprehension }

class SavedExercisesService {
  SavedExercisesService({FirebaseFirestore? firestore, String? Function()? currentUid});

  Future<String> save({
    required SavedExerciseType type,
    required Map<String, dynamic> passageJson,
    required Map<String, dynamic> generationFilters,
    required Language targetLanguage,
  });

  /// A random saved exercise of [type] whose stored filters match [filters],
  /// excluding [excludeId]; null if none. `passageJson` is the raw map — the
  /// caller decodes it with the right entity's fromJson.
  Future<({String id, Map<String, dynamic> passageJson})?> getRandom({
    required SavedExerciseType type,
    required Language targetLanguage,
    required Map<String, dynamic> filters,
    String? excludeId,
  });

  /// Union of vocabId used across all saved bilingual exercises (for
  /// prioritizeUnusedWords).
  Future<Set<String>> usedBilingualVocabIds();
}
```
`bilingual`/`part5`/`part6`/`part7` → `users/{uid}/reading_exercises`; `dictation`/`comprehension` → `users/{uid}/listening_exercises`. Doc body: `{type: type.name, passage: passageJson, generationFilters: filters, targetLanguage: targetLanguage.name, createdAt: <ISO>, id: <docId>}`.

Matching functions — port from web (`matchesBilingual`, `matchesToeic`, and add `matchesDictation` = `difficulty` equal, `matchesComprehension` = `context` equal AND (`level` null OR saved level ≤ requested via CEFR order)).

- [ ] TDD: service tests with `FakeFirebaseFirestore` — save+getRandom round trip per type; filter matching (topic overlap, maxCefr ceiling, wordCount exact, volumes overlap, difficulty exact, comprehension level null=any); excludeId; `usedBilingualVocabIds`; no-uid → save no-ops, getRandom null.
- [ ] Implement. Add `savedExercisesServiceProvider` (mirror `statsServiceProvider`).
- [ ] GREEN, analyze 0, `dart format`, commit `feat(practice): SavedExercisesService (shared Firestore collections with web)`.

## Task 3: notifier `loadSaved` — reading bilingual

**Files:** `reading_practice_provider.dart` (+ test).
- [ ] Add `void loadSaved(ReadingPassage passage, {String? savedId})` — `state = AsyncData(ReadingPracticeState(passage: passage, ... same initial shape `generate` produces on success ..., reusedFromId: savedId))`. Add a `String? reusedFromId` field to `ReadingPracticeState` (defaults null) so the result screen can hide "Lưu bài" and exclude on "Bài khác".
- [ ] Test: `loadSaved` populates state with `isComplete == false` and the passage; `reusedFromId` carried.
- [ ] commit.

## Task 4: notifier `loadSaved` — part5/6/7 + dictation + comprehension

**Files:** the other 5 notifiers (+ tests). Same pattern as Task 3: `loadSaved(<Set/Item>, {String? savedId})` sets the not-yet-started state; add `reusedFromId`.
- [ ] Per notifier: add the method + field, add a test, commit at the end of the batch (one commit `feat(reading,listening): loadSaved on the remaining session notifiers`).

## Task 5: "Lấy bài có sẵn" — reading bilingual home

**Files:** `reading_home_screen.dart` (+ test).
- [ ] Below the "Tạo bài luyện" `BloomPillButton`, add `BloomPillButton(label: 'Lấy bài có sẵn', variant: BloomButtonVariant.secondary, block: true, onPressed: () => _reuse(context, ref))`.
- [ ] `_reuse`: build `BilingualFilters` from `_level`/`_selectedTopicIds`/`_wordCount` → `savedExercisesService.getRandom(type: bilingual, targetLanguage: _language, filters: <json>)`. If non-null: `readingPracticeNotifier.loadSaved(ReadingPassage.fromJson(result.passageJson), savedId: result.id)` then `context.go('/reading/bilingual/session')`. If null: a `SnackBar('Chưa có bài đã lưu khớp bộ lọc.')`.
- [ ] In `_generate`: fetch `usedBilingualVocabIds()` and apply `prioritizeUnusedWords` to the word list before taking `_wordCount`.
- [ ] Test: button present; a stubbed `savedExercisesServiceProvider` returning a passage → tapping navigates to the session; returning null → snackbar. Behavior of the existing "Tạo bài luyện" test preserved.
- [ ] commit.

## Task 6: "Lấy bài có sẵn" — part5/6/7 + dictation + comprehension homes

**Files:** the other 4 home screens (+ tests). Same recipe as Task 5, with the type-appropriate filter (`ToeicFilters` from `_volumes`/topic; `DictationFilters` from `_difficulty`; `ComprehensionFilters` from `_context`/`_level`).
- [ ] Per screen: button + `_reuse` + test. One commit at the end.

## Task 7: "Lưu bài" — reading bilingual result

**Files:** `reading_result_screen.dart` (+ test).
- [ ] `_SaveState` local: `saving`, `savedId` (seeded from `result.reusedFromId`). If `savedId == null`: show a `BloomPillButton(label: saving ? 'Đang lưu…' : 'Lưu bài', variant: secondary, onPressed: saving ? null : _save)` alongside the existing "Sinh bài mới" / "Về trang chính" buttons. Once saved (or if reused): show a `Text('Đã lưu bài này', ...)` instead.
- [ ] `_save`: `savedExercisesService.save(type: bilingual, passageJson: result.passage.toJson(), generationFilters: <the filters from result — add them to ReadingPracticeState if not carried; else reconstruct minimally>, targetLanguage: result.passage.targetLanguage)` → setState savedId. On error: SnackBar.
  - NOTE: the result screen needs the generation filters. Simplest: carry `BilingualFilters` (or its json) on `ReadingPracticeState` from `generate`/`loadSaved`. Add that field in Task 3 if you didn't — update Task 3's brief accordingly.
- [ ] "Sinh bài mới" passes `excludeId: savedId` when it regenerates (so it doesn't immediately re-offer the same saved one). Actually simpler: regenerate always calls the AI `generate` — no exclude needed there; exclude only matters for "Lấy bài có sẵn" which isn't on the result screen. Leave regenerate as-is.
- [ ] Test: "Lưu bài" visible for a fresh (non-reused) result; tapping calls `save` (stubbed) and swaps to "Đã lưu bài này"; hidden for a `reusedFromId`-carrying result.
- [ ] commit.

## Task 8: "Lưu bài" — part5/6/7 + dictation + comprehension results

**Files:** the other 4 result screens (+ tests). Same recipe as Task 7 with the type-appropriate `save(...)` call and filters carried on each session state.
- [ ] Per screen: button + `_save` + test. One commit at the end.

## Task 9: full-suite gate + docs

- [ ] `flutter test` (green, > 780) + `flutter analyze` (0).
- [ ] `README.md` — add "Lưu / dùng lại bài AI" to the feature list; note the shared `reading_exercises` / `listening_exercises` Firestore collections.
- [ ] commit `docs: SP-5 saved AI exercises`.

---

## Self-Review

- Coverage: all 5 result screens get "Lưu bài" (Tasks 7–8), all 5 home screens get "Lấy bài có sẵn" (Tasks 5–6), one shared service (Task 2) writing the same two Firestore collections the web uses (verified against `savedReadingExercises.ts` / `savedListeningExercises.ts`), notifiers gain `loadSaved` (Tasks 3–4), entity JSON round-trips (Task 1). `prioritizeUnusedWords` for bilingual generation (Task 5).
- Risk: the entity JSON shapes are the most error-prone — Task 1 must diff each Flutter entity against its web TS counterpart field-by-field, since a mismatched key silently makes cross-platform reuse fail. The `ComprehensionItem.speakerGenders` field (web persists it deliberately) must be in the Flutter `ListeningPassage` JSON or reused conversations collapse to same-gender voices.
- Risk: session states must now carry the generation filters (for the result screen's "Lưu bài") and a `reusedFromId` — additive fields, default null/empty, no behavior change for the generate path.
- The web also has `getAllUsedVocabIds` used by the bilingual generate path; ported as `usedBilingualVocabIds` (Task 2), applied in Task 5.

## Execution Handoff

Subagent-driven. 9 tasks.
