# SP-6: IA changes (device-test punch list)

**Date:** 2026-09-04
**Status:** approved (autonomous execution per user instruction "Chạy tuần tự đến SP cuối cùng không cần hỏi lại")

Four loosely-related information-architecture changes surfaced by the user's
device test of the Flutter app. They are independent; each ships on its own.

## 6a. Flutter: "Tiến độ" gets its own bottom-bar tab (4 → 5 tabs)

**Now:** `ProgressScreen` lives at `/practice/progress`, reached only by a
`BloomNavCard` on the Luyện tập hub (via `context.push`).

**Change:** promote it to a top-level shell route `/progress` and a 5th
destination in `AppShell._destinations`, between "Luyện tập" and "Cài đặt":

```
Tra từ (/) · Từ vựng (/vocab) · Luyện tập (/practice) · Tiến độ (/progress) · Cài đặt (/settings)
```

Icon: `Icons.insights` (or keep `Icons.bar_chart` — pick one not already used;
`school` is Luyện tập, `settings` is Cài đặt). Label: **"Tiến độ"**.

- New `GoRoute(path: '/progress', builder: … const ProgressScreen())` as a
  direct child of the `ShellRoute` (sibling of `/practice`, NOT nested under it).
- Remove the `/practice/progress` nested route.
- Remove the "Tiến độ học tập" `BloomNavCard` from `PracticeHubScreen` (its
  function moves to the tab). The hub keeps: Từ vựng cách khoảng, Luyện đọc,
  Luyện nghe, Quét từ vựng.
- `ProgressScreen` currently has no `BloomAppBar` back button assumption to
  worry about — verify it renders fine as a root tab (it's a `BloomScaffold`
  with its own app bar; drop any `leading` back-arrow if present).
- 5 tabs still fit `BloomBottomNav` at small widths — labels are short
  ("Tiến độ" is 7 chars). If `BloomBottomNav` overflows at 5 items on a narrow
  device, that's a `BloomBottomNav` bug to fix in the same task (it should
  already handle it — the web redesign used up to 5). Verify with a 320px test.
- The nav-rail (≥600px) path takes the 5th item automatically.
- Tests: `app_shell` test asserts 5 destinations + `/progress` selects index 3;
  `practice_hub_screen` test drops the "Tiến độ học tập" card assertion; any
  test that navigated to `/practice/progress` now uses `/progress`.

**Web:** already has "🏠 Tổng quan" (`/dashboard`) as a top-level sidebar item
— no change; 6a is Flutter-only.

## 6b. Flutter: reading & listening sub-hubs show type options inline

**Now:** Luyện tập → "Luyện đọc" → `ReadingHubScreen` (4 `BloomNavCard`s) →
tap one → a separate `*HomeScreen` with `FilterTile`s + "Tạo bài luyện" /
"Lấy bài có sẵn" + loading/error states. Same shape for Luyện nghe (2 cards).

**Change (match the web `apps/web/src/app/(app)/reading/page.tsx` pattern):**
the hub screen itself becomes stateful. Each type is a **toggle card**; tapping
it expands an inline panel directly below it holding that type's filters +
action buttons + gate messages. Only one type expanded at a time. No navigation
until the user taps "Tạo bài luyện" / "Lấy bài có sẵn", which runs the exact
same generate/reuse flow the `*HomeScreen` runs today and then `context.go`s to
the session route.

Scope decision — **keep the `*HomeScreen` widgets, refactor their body into a
reusable `*Options` widget** that both the old route (kept as a deep-link
target / fallback) and the new inline hub panel embed. This avoids
re-implementing the AI-call orchestration, the `sessionAsync.when`
loading/error handling, the vocab-count gates, and the `AiKeyMissingCard`
gate 6×.

- `ReadingHubScreen` → `ConsumerStatefulWidget`, `String? _expandedMode`
  (`'bilingual'|'part5'|'part6'|'part7'`). Renders 4 `BloomNavCard`s with a
  `selected: _expandedMode == mode` visual and an `onTap` that toggles
  `_expandedMode`. Below the tapped card: an `AnimatedSize`/plain `Column`
  containing `<Type>Options()`.
- Extract from each `*HomeScreen`'s `build` the filter+button+gate subtree into
  a `ReadingBilingualOptions` / `Part5Options` / `Part6Options` / `Part7Options`
  `ConsumerStatefulWidget` (owns its own `_language`/`_level`/`_topicIds`/…
  state + `_generate`/`_reuse`, moved verbatim). The `*HomeScreen` becomes a
  thin `BloomScaffold(appBar: …, body: SingleChildScrollView(child: <Type>Options()))`.
- Same for `ListeningHomeScreen` (the hub) + `DictationHomeScreen` /
  `ComprehensionHomeScreen` → `DictationOptions` / `ComprehensionOptions`.
- Routes: `/reading` now renders the inline hub; `/reading/bilingual` etc.
  still exist (deep links, "back to setup" targets, and the `_reuse`/`_generate`
  `context.go('/reading/bilingual/session')` still originates cleanly). The
  hub's action buttons navigate straight to `…/session`.
- The Luyện tập hub's "Luyện đọc" / "Luyện nghe" cards still `context.go('/reading')` / `('/listening')`.
- Tests: each `*_home_screen_test` keeps working (the screen still renders the
  same widgets, just wrapped). New `reading_hub_screen_test` / `listening_home_screen_test`:
  tapping a card expands its options; tapping another collapses the first;
  the action buttons still navigate.

This is the largest of the four — it is fine for it to be several plan tasks.

## 6c. Web: Word Radar leaves the Reading hub, gets a top-level sidebar entry

**Now:** web Word Radar is at `/reading/word-radar`, reached via a 5th card in
the Reading hub (`apps/web/src/app/(app)/reading/page.tsx`).

**Change:**
- Move the route: `apps/web/src/app/(app)/reading/word-radar/` →
  `apps/web/src/app/(app)/word-radar/`. Update every internal link/redirect.
- `Sidebar.tsx` `NAV_GROUPS`: add `{ href: "/word-radar", label: "🛰️ Quét từ vựng" }`
  as its own group directly after the "Đọc" group (a sibling of "Đọc — tổng
  quan", level with it — not nested):
  ```
  { label: "Đọc", items: [{ href: "/reading", label: "📖 Đọc — tổng quan" }] },
  { label: "Quét từ", items: [{ href: "/word-radar", label: "🛰️ Quét từ vựng" }] },
  { label: "Nghe", items: [...] },
  ```
  (Or fold it into the top unlabeled group — pick whichever reads better beside
  the existing groups; a dedicated 1-item group matches how "Đọc"/"Nghe" are
  done.)
- Remove the Word Radar card from the Reading hub page.
- Update `Sidebar.test.tsx` + the Reading-hub page test + any `word-radar` path
  test.

**Flutter:** the user explicitly said the **app keeps Radar on the Luyện tập
hub** — 6c is web-only. (The Flutter Luyện tập hub's "Quét từ vựng" card and
`/practice/radar` route are unchanged.)

## 6d. Vocab Bank filter parity (both platforms)

**Now:**
- **App** `vocab_bank_screen.dart`: search box (headword/meaning substring) +
  topic multi-select (bottom sheet). No due-only, no CEFR filter.
- **Web** `vocab-bank/page.tsx`: `dueOnly` chip + topic multi-select popover +
  CEFR-level multi-select (`VocabFilterState = {dueOnly, topicIds, cefrLevels}`,
  `matchesFilters` in `lib/vocabFilters.ts`). **No search box.**

**Change — converge on the union:**
- **Web gains a search box.** Add a controlled text input above the filter
  chips; filter `records` by case-insensitive substring match on `headword`
  **or** `meaning` (mirror the app's `_filter` predicate). Combine with the
  existing `matchesFilters` (AND). Clear-"x" affordance. Reset on unmount is
  automatic (local state).
- **App gains `dueOnly` + CEFR-level filter.** Extend the app's filter model to
  `{query, topicIds, dueOnly, cefrLevels}`:
  - a "Cần ôn hôm nay (N)" toggle chip (N = count of due records), matching
    web's copy.
  - CEFR-level multi-select — add to the existing filter bottom sheet (or a
    second `FilterTile` → multi-select sheet of a1..c2). "Due" = `nextReviewAt
    == null || isBefore(now)` (same as `StatsService`/web `isDue`).
  - The app's `_filter` applies all four (AND), same semantics as web
    `matchesFilters` + the search predicate.
- Keep both platforms' visual idiom (app: `FilterTile` + bottom sheets + a
  chip; web: chips + popover) — parity is about *which* filters exist and their
  semantics, not pixel-identical UI.
- Tests: app — due-only chip filters; CEFR filter filters; combine with search
  + topic. Web — search box filters by headword and by meaning; combines with
  chips; clear button.

## Non-goals

- No change to the underlying Firestore/Hive vocab schema.
- No change to what "due" means or the SM-2 algorithm.
- 6b does not merge the session/result screens — only the hub↔setup screens.
- No web bottom-nav / no Flutter sidebar changes beyond 6a's tab.

## Testing

Every task ends `flutter analyze` 0 / `flutter test` green (Flutter side) and
`npm run -w apps/web typecheck` + `npm test -w apps/web` green (web side, 6c +
6d-web). Tests only go up. `dart format` per the standing SP-5 caveat
(hand-match, analyze decides).
