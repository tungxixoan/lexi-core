# SP-6: IA changes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`.

**Goal:** Ship the 4 IA changes in `docs/superpowers/specs/2026-09-04-sp6-ia-changes-design.md` — a Flutter "Tiến độ" bottom-bar tab, inline type-options on the Flutter reading/listening hubs, a top-level web Word Radar sidebar entry, and Vocab Bank filter parity across platforms.

**Architecture:** Mostly widget/route re-wiring. 6b extracts the body of each Flutter `*HomeScreen` into a reusable `*Options` `ConsumerStatefulWidget` that both the kept route and a new stateful inline hub embed.

**Tech Stack:** Flutter (`go_router`, Riverpod, Bloom widgets) + Next.js/React (`apps/web/`).

## Global Constraints

- Flutter: `flutter analyze` stays **0**; `dart format` per the SP-5 caveat (repo predates SDK 3.11.5 tall-style — hand-match new code, `analyze 0` is the gate, no repo-wide reformat). Colors via `context.bloom`.
- Web: `npm run -w apps/web typecheck` clean; `npm test -w apps/web` green.
- Tests only go up (Flutter suite ~879 at plan start). `apps/web/` is only touched by Tasks 2 & 3.
- No Firestore/Hive schema change. "Due" = `nextReviewAt == null || nextReviewAt.isBefore(DateTime.now())` (Flutter) / the existing `isDue` (web) — do not redefine.
- Every commit trailer: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

**Flutter — created:**
- `lib/features/reading/presentation/widgets/reading_bilingual_options.dart`, `part5_options.dart`, `part6_options.dart`, `part7_options.dart`
- `lib/features/listening/presentation/widgets/dictation_options.dart`, `comprehension_options.dart`
- `lib/core/widgets/vocab_filter.dart` — `VocabFilterState` model + `matchesVocabFilters` (mirrors web `vocabFilters.ts`)

**Flutter — modified:**
- `lib/core/router/app_router.dart` — `/progress` top-level route; drop `/practice/progress`
- `lib/core/widgets/app_shell.dart` — 5th destination
- `lib/features/practice/presentation/screens/practice_hub_screen.dart` — drop the Tiến độ card
- the 6 `*_home_screen.dart` — bodies move to the new `*Options` widgets; screens become thin wrappers
- `lib/features/reading/presentation/screens/reading_hub_screen.dart` + `lib/features/listening/presentation/screens/listening_home_screen.dart` — stateful inline hubs
- `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart` — dueOnly + CEFR filter

**Web — modified (Tasks 2 & 3):**
- `apps/web/src/app/(app)/word-radar/` (moved from `reading/word-radar/`)
- `apps/web/src/components/shell/Sidebar.tsx` + `.test.tsx`
- `apps/web/src/app/(app)/reading/page.tsx` — drop the Radar card
- `apps/web/src/app/(app)/vocab-bank/page.tsx` — search box

---

## Task 1: Flutter — "Tiến độ" bottom-bar tab (spec 6a)

**Files:** `app_router.dart`, `app_shell.dart`, `practice_hub_screen.dart`, `progress_screen.dart` (maybe), + tests `test/core/widgets/app_shell_test.dart`, `test/features/practice/presentation/screens/practice_hub_screen_test.dart`, `test/features/practice/presentation/screens/progress_screen_test.dart`.

- [ ] `app_router.dart`: add `GoRoute(path: '/progress', builder: (c, s) => const ProgressScreen())` as a direct child of the `ShellRoute` (sibling of `/`, `/vocab`, `/practice`, `/settings`). Remove the nested `GoRoute(path: 'progress', …)` under `/practice`.
- [ ] `app_shell.dart`: add `_Dest(path: '/progress', icon: Icons.insights, label: 'Tiến độ')` to `_destinations` between the `/practice` and `/settings` entries. (Verify `Icons.insights` isn't already used; else `Icons.trending_up`.)
- [ ] `practice_hub_screen.dart`: delete the "Tiến độ học tập" `BloomNavCard` (and its trailing `SizedBox(height: 12)`).
- [ ] `progress_screen.dart`: if its `BloomAppBar` has a `leading:` back button or a `context.pop`-based action, remove it — it is now a root tab. Keep the app bar title.
- [ ] Tests: `app_shell_test` — 5 nav items; location `/progress` → selectedIndex 3; `/practice/progress` no longer routed. `practice_hub_screen_test` — the Tiến độ card assertion removed; other 4 cards still present. `progress_screen_test` — still renders; if it navigated via `/practice/progress`, update to `/progress`. Add a 320px-wide `BloomBottomNav` render test with 5 items asserting no overflow (`tester.takeException()` is null).
- [ ] `flutter analyze` 0, `flutter test` green.
- [ ] Commit `feat(nav): Tiến độ gets its own bottom-bar tab`.

## Task 2: Web — Word Radar → top-level sidebar entry (spec 6c)

**Files:** `apps/web/src/app/(app)/word-radar/page.tsx` (git-mv from `reading/word-radar/page.tsx` + its test), `apps/web/src/components/shell/Sidebar.tsx` + `Sidebar.test.tsx`, `apps/web/src/app/(app)/reading/page.tsx` + `page.test.tsx`.

- [ ] `git mv apps/web/src/app/(app)/reading/word-radar apps/web/src/app/(app)/word-radar` (and the co-located test if any). Update any `import`/`Link href`/`router.push` that referenced `/reading/word-radar` → `/word-radar` (grep the whole `apps/web/src`).
- [ ] `Sidebar.tsx`: insert a new group after the "Đọc" group: `{ label: "Quét từ", items: [{ href: "/word-radar", label: "🛰️ Quét từ vựng" }] }`.
- [ ] `reading/page.tsx`: remove the Word Radar hub card + any now-unused import.
- [ ] `Sidebar.test.tsx`: assert the new link renders + is `active` on `/word-radar`. `reading/page.test.tsx`: drop the Radar-card assertion. Move/rename the word-radar page test.
- [ ] `npm run -w apps/web typecheck` + `npm test -w apps/web` green.
- [ ] Commit `feat(web): Word Radar leaves the Reading hub for its own sidebar entry`.

## Task 3: Web — search box on the Vocab Bank (spec 6d-web)

**Files:** `apps/web/src/app/(app)/vocab-bank/page.tsx` + `page.test.tsx`.

- [ ] Add `const [query, setQuery] = useState("")` + a controlled `<input>` above `.vb-toolbar` (reuse an existing input class if the codebase has one; else a minimal `className="vb-search"` — check `globals.css` / the Lookup page for a search-input pattern first). Include a clear-"✕" button when `query` is non-empty.
- [ ] Fold the query into the `filtered` `useMemo`: after `matchesFilters`, also require (when `query.trim()` non-empty) `r.headword.toLowerCase().includes(q) || r.meaning.toLowerCase().includes(q)` where `q = query.trim().toLowerCase()`.
- [ ] Add `query` to `filterSignature` so `usePaginatedScroll` resets on query change.
- [ ] `clearFilters` also resets `query`.
- [ ] Tests: typing a headword substring narrows the list; typing a meaning substring narrows it; clearing restores; query + a chip filter combine (AND).
- [ ] `npm run -w apps/web typecheck` + `npm test -w apps/web` green.
- [ ] Commit `feat(web): search box on the Vocab Bank`.

## Task 4: Flutter — dueOnly + CEFR filter on the Vocab Bank (spec 6d-app)

**Files:** create `lib/core/widgets/vocab_filter.dart`; modify `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart` + `test/features/vocabulary/presentation/screens/vocab_bank_screen_test.dart`; new `test/core/widgets/vocab_filter_test.dart`.

- [ ] `vocab_filter.dart`:
```dart
import '../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../features/vocabulary/domain/entities/cefr_level.dart';

class VocabFilterState {
  const VocabFilterState({
    this.query = '',
    this.topicIds = const {},
    this.dueOnly = false,
    this.cefrLevels = const {},
  });
  final String query;
  final Set<String> topicIds;
  final bool dueOnly;
  final Set<CEFRLevel> cefrLevels;

  bool get isActive =>
      query.trim().isNotEmpty || topicIds.isNotEmpty || dueOnly || cefrLevels.isNotEmpty;

  VocabFilterState copyWith({
    String? query, Set<String>? topicIds, bool? dueOnly, Set<CEFRLevel>? cefrLevels,
  }) => VocabFilterState(
        query: query ?? this.query,
        topicIds: topicIds ?? this.topicIds,
        dueOnly: dueOnly ?? this.dueOnly,
        cefrLevels: cefrLevels ?? this.cefrLevels,
      );
}

bool vocabRecordIsDue(VocabRecord r, {DateTime? now}) {
  final at = now ?? DateTime.now();
  return r.nextReviewAt == null || r.nextReviewAt!.isBefore(at);
}

bool matchesVocabFilters(VocabRecord r, VocabFilterState f, {DateTime? now}) {
  if (f.dueOnly && !vocabRecordIsDue(r, now: now)) return false;
  if (f.topicIds.isNotEmpty && !r.topicIds.any(f.topicIds.contains)) return false;
  if (f.cefrLevels.isNotEmpty && !f.cefrLevels.contains(r.cefrLevel)) return false;
  final q = f.query.trim().toLowerCase();
  if (q.isNotEmpty &&
      !(r.headword.toLowerCase().contains(q) || r.meaning.toLowerCase().contains(q))) {
    return false;
  }
  return true;
}
```
- [ ] `vocab_filter_test.dart`: dueOnly excludes not-due; topic overlap; cefr membership; query on headword & meaning; combined AND; `isActive`.
- [ ] `vocab_bank_screen.dart`: replace the ad-hoc `_selectedTopicIds` + `_searchQuery` with a single `VocabFilterState _filters`. Keep the search `BloomTextField` (write into `_filters = _filters.copyWith(query: v)`). Add:
  - a "Cần ôn hôm nay (N)" toggle `BloomChip` (N = `records.where((r) => vocabRecordIsDue(r)).length`) — toggles `dueOnly`.
  - a second `FilterTile` "Cấp độ" → `showMultiSelectSheet<CEFRLevel>` of `CEFRLevel.values` (label `.label`), writing `cefrLevels`.
  - `_filter()` → `records.where((r) => r.targetLanguage == lang).where((r) => matchesVocabFilters(r, _filters)).toList()`.
- [ ] Tests: due-only chip filters to due records; CEFR sheet selection filters; search + topic + due + cefr combine; empty-state copy unchanged.
- [ ] `flutter analyze` 0, `flutter test` green.
- [ ] Commit `feat(vocab): dueOnly + CEFR filter on the Vocab Bank (web parity)`.

## Task 5: Flutter — extract `*Options` widgets from the 4 reading home screens (spec 6b, part 1)

**Files:** create the 4 `lib/features/reading/presentation/widgets/*_options.dart`; modify the 4 `*_home_screen.dart`; their 4 `*_home_screen_test.dart` should keep passing unchanged (or with import-path tweaks only).

- [ ] For each of bilingual / part5 / part6 / part7: move the **entire body** of `_*HomeScreenState` — all filter fields, `initState`, `_reload`, the pickers, `_generate`, `_reuse`, `_filters()`, and the `build`'s returned `SingleChildScrollView`/`Column` subtree (everything **inside** the `BloomScaffold.body`) — into a new `ReadingBilingualOptions` / `Part5Options` / `Part6Options` / `Part7Options` `ConsumerStatefulWidget` in `widgets/`. The `*Options` widget's `build` returns the `Column` (no scaffold, no app bar).
- [ ] Each `*HomeScreen` becomes:
```dart
class ReadingHomeScreen extends StatelessWidget {
  const ReadingHomeScreen({super.key});
  @override
  Widget build(BuildContext context) => BloomScaffold(
        appBar: BloomAppBar(title: '…', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/reading'))),
        body: const SingleChildScrollView(padding: EdgeInsets.all(16), child: ReadingBilingualOptions()),
      );
}
```
- [ ] The `*Options` widgets must be self-contained: `context.go('…/session')` for navigation still lives in their `_generate`/`_reuse` (unchanged). They render their own `AiKeyMissingCard` / vocab-count gates.
- [ ] Run each `*_home_screen_test.dart` — they should pass (same widget tree, just nested). Fix only import paths / any `find.byType(ReadingHomeScreen)` that should now be `find.byType(ReadingBilingualOptions)`.
- [ ] `flutter analyze` 0, `flutter test test/features/reading/` green.
- [ ] Commit `refactor(reading): extract *Options widgets from the 4 reading home screens`.

## Task 6: Flutter — inline stateful Reading hub (spec 6b, part 2)

**Files:** `lib/features/reading/presentation/screens/reading_hub_screen.dart` + `test/features/reading/presentation/screens/reading_hub_screen_test.dart`.

- [ ] `ReadingHubScreen` → `StatefulWidget`, `String? _expanded` (`'bilingual'|'part5'|'part6'|'part7'`).
- [ ] Body is a `ListView` of 4 entries; each entry = a `BloomNavCard`(`selected: _expanded == mode`, `onTap: () => setState(() => _expanded = _expanded == mode ? null : mode)`) followed by, when expanded, the matching `*Options()` widget in a padded container (a subtle `BloomCard` or just indented `Padding`). Use `AnimatedSize` for a smooth expand if trivial; a plain conditional is acceptable.
- [ ] Keep the app bar (title "Luyện đọc", back to `/practice`).
- [ ] Tests: initially no `*Options` shown; tap "Đọc & gõ" → `ReadingBilingualOptions` appears; tap "Part 5" → bilingual options gone, `Part5Options` shown; tap "Part 5" again → collapses. (Stub the providers the options need — reuse the pattern from the `*_home_screen_test` harnesses; a `savedExercisesServiceProvider` + `userSettingsNotifierProvider` + `vocabRepositoryProvider` override.)
- [ ] `flutter analyze` 0, `flutter test test/features/reading/` green.
- [ ] Commit `feat(reading): inline type options on the Luyện đọc hub`.

## Task 7: Flutter — extract listening `*Options` + inline Listening hub (spec 6b, part 3)

**Files:** create `lib/features/listening/presentation/widgets/dictation_options.dart`, `comprehension_options.dart`; modify `dictation_home_screen.dart`, `comprehension_home_screen.dart`, `listening_home_screen.dart` + tests.

- [ ] Same extraction as Task 5 for dictation + comprehension → `DictationOptions` / `ComprehensionOptions`. The 2 `*HomeScreen`s become thin wrappers (`body: SingleChildScrollView(child: const DictationOptions())`).
- [ ] `ListeningHomeScreen` (the hub) → `StatefulWidget` with `String? _expanded` (`'dictation'|'comprehension'`), same inline-expand pattern as Task 6, 2 cards.
- [ ] Tests: `dictation_home_screen_test` / `comprehension_home_screen_test` keep passing (nested tree). New `listening_home_screen_test`: tap a card → its options appear; tap the other → first collapses.
- [ ] `flutter analyze` 0, `flutter test test/features/listening/` green.
- [ ] Commit `feat(listening): inline type options on the Luyện nghe hub`.

## Task 8: full gate + docs

- [ ] Flutter: `flutter analyze` (0) + `flutter test` (green, > 879). Web: `npm run -w apps/web typecheck` + `npm test -w apps/web` (green).
- [ ] `README.md`: update the "Luyện đọc"/"Luyện nghe" hub descriptions (options now inline, no separate setup screen); note the new "Tiến độ" tab in the nav description; the web sidebar's new "Quét từ vựng" entry; the Vocab Bank filter set (search + due + topic + CEFR on both platforms).
- [ ] `CLAUDE.md` "Theme (Flutter)" or a nav note if one exists — only if it references the old 4-tab nav.
- [ ] Commit `docs: SP-6 IA changes`.

---

## Self-Review

- 6a → Task 1. 6b → Tasks 5–7 (reading extract, reading hub, listening). 6c → Task 2. 6d → Task 3 (web) + Task 4 (app). Docs → Task 8. All spec sections covered.
- Risk: Task 5/7's extraction is mechanical but large — the `*Options` widget must carry *all* state and the `context.go` navigation; a missed field breaks generate/reuse. Mitigation: the `*_home_screen_test` suites already exercise generate + reuse + gates and must stay green unchanged.
- Risk: Task 6/7 inline hub — the `*Options` widgets each `ref.watch` several providers; embedding 4 at once (all collapsed → not built; one expanded → one built) is fine, but the test harness must override every provider each `*Options` touches. Reuse the existing per-screen harness overrides.
- Type consistency: `VocabFilterState` (Task 4) uses `Set<CEFRLevel>` (Flutter enum) where web uses `Set<string>` — deliberate, the semantics match.

## Execution Handoff

Subagent-driven. 8 tasks.
