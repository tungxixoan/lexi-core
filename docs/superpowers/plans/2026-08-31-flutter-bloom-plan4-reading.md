# Flutter Bloom — Plan 4: Reading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the whole Reading area — the Reading hub, Đọc & gõ (setup → session → result), and the three TOEIC drills Part 5 / Part 6 / Part 7 (each home → session → result) — to the Bloom design system, and add the three shared Bloom widgets this area needs (`BloomExpansionTile`, `BloomGroupChips`, `BloomPassageSheet`).

**Architecture:** Three new widgets land first in `lib/core/theme/bloom/` (they have no dependency on the screens). Then screen-by-screen restyle, grouped so each task ends on an independently testable deliverable. Part 5 stays a plain scrolling question list. Part 6 and Part 7 get a real layout change: the passage(s) move into a draggable `BloomPassageSheet`, the questions become the main content, and a `BloomGroupChips` row navigates between passages/groups one at a time (Part 6 questions render as `BloomExpansionTile`; Part 7 questions as `BloomMcOption`). **Every provider, notifier, use-case, entity, and route is frozen** — only the presentation (`presentation/screens/*`) and the new widgets change. All Reading screens are already Vietnamese.

**Tech Stack:** Flutter 3.41 / Dart ≥3.4, `flutter_riverpod` (untouched providers), `go_router` (untouched), `flutter_test`. Bloom design system from Plans 1–3 (`lib/core/theme/bloom/`).

## Global Constraints

- **Bloom widgets** come from `import 'package:lexi_core/core/theme/bloom/bloom.dart';` — the barrel already exports `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomPillButton` (+`BloomButtonVariant`), `BloomChip` (+`BloomChipStyle`), `BloomCefrPill`, `BloomProgressBar`, `BloomSectionHeader` (in `bloom_labels.dart`), `BloomListRow`, `BloomTextField`, `BloomMcOption` (+`BloomMcState`), `BloomResultRing`. This plan adds `BloomExpansionTile`, `BloomGroupChips`, `BloomPassageSheet` (Tasks 1–3).
- **`FilterTile`** is `import 'package:lexi_core/core/widgets/filter_tile.dart';` — Bloom-styled since Plan 1, NOT in the barrel. `showSingleSelectSheet` / `showMultiSelectSheet` / `SelectOption` from `import 'package:lexi_core/core/widgets/selection_sheets.dart';` — Bloom-styled since Plan 1, keep using them as-is.
- **Colors** via `context.bloom` (a `BloomColors`; falls back to `BloomColors.light` in themeless test harnesses). Never a raw `Colors.*` or `Color(0x...)` in new/edited code. Map the existing hardcoded semantics: `Colors.green*` (correct) → `context.bloom.success` on `context.bloom.successBg`; `Colors.red*` / `theme.colorScheme.error` (wrong) → `context.bloom.danger` on `context.bloom.dangerBg`; the passage learned-word highlight → `context.bloom.sage` text on a `context.bloom.sageBg` ground.
- **Radii:** only `BloomRadii.sm=10 / md=16 / lg=20 / pill=999`. No new literal radii.
- **Spacing:** `BloomSpacing.xs=4 / sm=8 / md=12 / lg=16 / xl=22 / xxl=32` where you'd otherwise hardcode; existing literal `EdgeInsets.all(16)` page padding may stay.
- **No deprecated APIs that add `flutter analyze` issues.** This Flutter deprecates `withOpacity` → `.withValues(alpha:)`. The repo has exactly **21 pre-existing** `flutter analyze` infos (all `RadioListTile` / `Radio` `groupValue` deprecations). Replacing the Part 5/6/7 `RadioListTile<int>` with `BloomMcOption` **removes** some of those infos — that is allowed (the count may drop below 21); it must **never rise above 21**, and no new lint of any kind may appear. Record the new number in the task's commit body.
- **Tests:** the suite is at **678 passing** at the start of this plan (`flutter test`). It only goes up. When a widget swap breaks a finder, fix the finder — prefer `find.text` / `find.byKey` / `find.byType(BloomX)` / `find.widgetWithText(...)`. **Never weaken or delete a behavior assertion.** Where a test asserted "all N passages visible at once" and the redesign shows one at a time, the assertion is replaced by an equivalent that drives the new navigation (tap the chip, then assert) — not deleted.
- **Behavior is frozen.** No change to: `ReadingPracticeNotifier` (`generate` / `updateTypedText` / `_advance` / `reset`, and the "typed text == target → auto-advance, no Next button" rule), `Part5PracticeNotifier` / `Part6PracticeNotifier` / `Part7PracticeNotifier` (`generate` / `selectAnswer` / `submit` / `reset`, `canSubmit`, `flatIndex`, `isSubmitted`), any use-case or entity, `*ResultScreen`'s `initState` post-frame `statsServiceProvider.recordPracticeSession(...)` call, the `ref.listen(...)` → `WidgetsBinding.addPostFrameCallback` → `context.go(...result, extra:)` navigation in every session screen, and the `redirect` guards in `app_router.dart`. Restyle is view-only. Any UI-local state a redesign needs (e.g. "which passage chip is active", "is the passage sheet expanded") lives in the **screen's own `State`**, never in a provider.
- **`webScaled(...)`** (`lib/core/utils/web_text_scale.dart`) wrapping stays exactly where the current code has it — on passage text, question text, option text, explanation text, typed-area text. It is a no-op on mobile and out of scope to add or remove. `BloomMcOption` already `webScaled`s its own label (Plan 3 fix) — do **not** double-wrap when passing text to it.
- **`aiEnabled` stays.** Every Reading home screen keeps its `if (!settings.aiEnabled)` gate and the current message text. `ai_disabled_card.dart` is restyled internally (Task 4) but keeps its name `AiDisabledCard`, its `const AiDisabledCard({super.key, required this.message})` constructor, and every call-site string. The rename to `AiKeyMissingCard` + the `aiAvailable` switch is **Plan 6 (spec §C2)** — not here.
- **No route / `go_router` / IA changes.** Session and result screens are nested `GoRoute`s, so `Navigator.canPop` is true and a `BloomAppBar` would imply a back arrow — pass `automaticallyImplyLeading: false` on every session/result `BloomAppBar` and add `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go(<parent>); })` wrapping the scaffold, exactly as Plan 3 did for `practice_session_screen` / `session_result_screen`. Parent targets: Đọc & gõ → `/reading/bilingual`; Part 5/6/7 → `/reading/part5` `/reading/part6` `/reading/part7`.
- **`apps/web/` is never touched.** Package is `lexi_core`.
- **Spec:** `docs/superpowers/specs/2026-08-30-flutter-bloom-redesign-design.md` — §Phần B items 6–9, §A3 (the widget table rows for `BloomExpansionTile` / `BloomPassageSheet` / `BloomGroupChips`), §Testing.

---

## File Structure

**Created:**
- `lib/core/theme/bloom/bloom_expansion_tile.dart` — `BloomExpansionTile`
- `lib/core/theme/bloom/bloom_group_chips.dart` — `BloomGroupChips`
- `lib/core/theme/bloom/bloom_passage_sheet.dart` — `BloomPassageSheet`
- `test/core/theme/bloom/bloom_expansion_tile_test.dart`
- `test/core/theme/bloom/bloom_group_chips_test.dart`
- `test/core/theme/bloom/bloom_passage_sheet_test.dart`

**Modified:**
- `lib/core/theme/bloom/bloom.dart` — add the 3 exports
- `lib/core/widgets/ai_disabled_card.dart` — Bloom tokens (Task 4)
- `lib/features/reading/presentation/screens/reading_hub_screen.dart` (Task 4)
- `lib/features/reading/presentation/screens/reading_home_screen.dart` (Task 5)
- `lib/features/reading/presentation/screens/reading_session_screen.dart` (Task 6)
- `lib/features/reading/presentation/screens/reading_result_screen.dart` (Task 7)
- `lib/features/reading/presentation/screens/part5_home_screen.dart` + `part5_result_screen.dart` (Task 8)
- `lib/features/reading/presentation/screens/part5_session_screen.dart` (Task 9)
- `lib/features/reading/presentation/screens/part6_home_screen.dart` + `part6_result_screen.dart` (Task 10)
- `lib/features/reading/presentation/screens/part6_session_screen.dart` (Task 11)
- `lib/features/reading/presentation/screens/part7_home_screen.dart` + `part7_result_screen.dart` (Task 12)
- `lib/features/reading/presentation/screens/part7_session_screen.dart` (Task 13)
- The matching `test/features/reading/presentation/screens/*_test.dart` for every screen above — finder swaps only.

**Not in this plan:** `progress_screen.dart`, Listening, Word Radar, Settings, Sign-in (later plans); `aiEnabled` removal + `AiKeyMissingCard` rename (Plan 6); `README.md`; anything under `data/` or `domain/`.

---

## Task 1: BloomExpansionTile

**Files:**
- Create: `lib/core/theme/bloom/bloom_expansion_tile.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_expansion_tile_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomExpansionTile extends StatefulWidget {
    const BloomExpansionTile({
      super.key,
      required this.title,      // e.g. "Chỗ trống (1)"
      required this.summary,    // e.g. "Đã chọn: on" or "Chưa trả lời"
      required this.child,      // revealed body
      this.answered = false,    // colors the summary: sage when true, inkFaint when false
      this.initiallyExpanded = false,
    });
    final String title;
    final String summary;
    final Widget child;
    final bool answered;
    final bool initiallyExpanded;
  }
  ```
  Collapsed = a `surface` card (`border`, `BloomRadii.md`) whose header row is `[Text(title, w700 ink)] [Spacer] [Text(summary, 12.5 · answered ? sage : inkFaint)] [Icon(expand caret, inkFaint)]`. Tapping the header toggles; the caret rotates (`AnimatedRotation`, 0 → 0.5 turns) and the body reveals via `AnimatedSize` (`duration: Duration(milliseconds: 180)`, `curve: Curves.easeOut`). Header uses the Bloom interactive pattern (`Container(decoration:) > Material(color: transparent) > InkWell > Padding`) so the ripple shows above a `BloomScaffold` gradient.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_expansion_tile.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('collapsed by default: shows title + summary, hides child', (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'Chỗ trống (1)',
      summary: 'Chưa trả lời',
      child: Text('BODY'),
    )));
    expect(find.text('Chỗ trống (1)'), findsOneWidget);
    expect(find.text('Chưa trả lời'), findsOneWidget);
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('tapping the header reveals the child', (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'S', child: Text('BODY'),
    )));
    await tester.tap(find.text('T'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('initiallyExpanded: true shows the child immediately', (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'S', initiallyExpanded: true, child: Text('BODY'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('answered summary is drawn in sage, unanswered in inkFaint', (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'Đã chọn: on', answered: true, child: SizedBox(),
    )));
    final answered = tester.widget<Text>(find.text('Đã chọn: on'));
    expect(answered.style!.color, BloomColorsFor(tester).sage);
  });
}

// Helper: read the ambient BloomColors the same way context.bloom does.
BloomColorsAccess BloomColorsFor(WidgetTester tester) => BloomColorsAccess(tester);
class BloomColorsAccess {
  BloomColorsAccess(this.tester);
  final WidgetTester tester;
  get sage => const Color(0xFF6F9A87); // BloomColors.light.sage
}
```

> Note: keep the color assertion simple — compare against the literal `BloomColors.light.sage` (`Color(0xFF6F9A87)`), since `AppTheme.light` attaches `BloomColors.light`. If a cleaner import of `BloomColors` is available, use `BloomColors.light.sage` directly instead of the helper.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_expansion_tile_test.dart`
Expected: FAIL — `bloom_expansion_tile.dart` does not exist / `BloomExpansionTile` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A single collapsible row for a list of questions (Reading Part 6). Collapsed,
/// it shows a [title] and a one-line [summary] of the current answer; expanded,
/// it reveals [child]. Mark [answered] to tint the summary sage.
class BloomExpansionTile extends StatefulWidget {
  const BloomExpansionTile({
    super.key,
    required this.title,
    required this.summary,
    required this.child,
    this.answered = false,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final Widget child;
  final bool answered;
  final bool initiallyExpanded;

  @override
  State<BloomExpansionTile> createState() => _BloomExpansionTileState();
}

class _BloomExpansionTileState extends State<BloomExpansionTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final header = Row(
      children: [
        Expanded(
          child: Text(widget.title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
        ),
        const SizedBox(width: 8),
        Text(widget.summary,
            style: TextStyle(
                fontSize: 12.5,
                color: widget.answered ? c.sage : c.inkFaint)),
        const SizedBox(width: 6),
        AnimatedRotation(
          turns: _expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: Icon(Icons.expand_more, size: 20, color: c.inkFaint),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: BloomSpacing.lg, vertical: BloomSpacing.md),
                child: header,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(BloomSpacing.lg, 0,
                        BloomSpacing.lg, BloomSpacing.lg),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
```

Add to `lib/core/theme/bloom/bloom.dart`, alphabetically:
```dart
export 'bloom_expansion_tile.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_expansion_tile_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_expansion_tile.dart test/core/theme/bloom/bloom_expansion_tile_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_expansion_tile.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_expansion_tile_test.dart
git commit -m "feat(bloom): BloomExpansionTile for collapsible Part 6 questions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: BloomGroupChips

**Files:**
- Create: `lib/core/theme/bloom/bloom_group_chips.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_group_chips_test.dart`

**Interfaces:**
- Consumes: `BloomChip` + `BloomChipStyle` (from `bloom_chip.dart`), `BloomSpacing`.
- Produces:
  ```dart
  class BloomGroupChips extends StatelessWidget {
    const BloomGroupChips({
      super.key,
      required this.labels,       // e.g. ['Đoạn 1', 'Đoạn 2', 'Đoạn 3']
      required this.activeIndex,
      required this.onChanged,
    });
    final List<String> labels;
    final int activeIndex;
    final ValueChanged<int> onChanged;
  }
  ```
  A single horizontal, horizontally-scrollable row of `BloomChip`. Chip `i` is `BloomChipStyle.active` when `i == activeIndex`, else `BloomChipStyle.neutral`; `onTap: () => onChanged(i)`. `SizedBox(width: BloomSpacing.sm)` between chips.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_chip.dart';
import 'package:lexi_core/core/theme/bloom/bloom_group_chips.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('renders one chip per label', (tester) async {
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['Đoạn 1', 'Đoạn 2', 'Đoạn 3'],
      activeIndex: 0,
      onChanged: (_) {},
    )));
    expect(find.byType(BloomChip), findsNWidgets(3));
    expect(find.text('Đoạn 2'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['Đoạn 1', 'Đoạn 2', 'Đoạn 3'],
      activeIndex: 0,
      onChanged: (i) => tapped = i,
    )));
    await tester.tap(find.text('Đoạn 3'));
    expect(tapped, 2);
  });

  testWidgets('the active chip uses the active style', (tester) async {
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['A', 'B'],
      activeIndex: 1,
      onChanged: (_) {},
    )));
    final chips = tester.widgetList<BloomChip>(find.byType(BloomChip)).toList();
    expect(chips[0].style, BloomChipStyle.neutral);
    expect(chips[1].style, BloomChipStyle.active);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_group_chips_test.dart`
Expected: FAIL — `BloomGroupChips` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import 'bloom_chip.dart';

/// A horizontal, scrollable row of pills that navigates a set of groups
/// (Reading Part 6 passages / Part 7 passage groups) — exactly one active.
class BloomGroupChips extends StatelessWidget {
  const BloomGroupChips({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: BloomSpacing.sm),
            BloomChip(
              label: labels[i],
              style: i == activeIndex
                  ? BloomChipStyle.active
                  : BloomChipStyle.neutral,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}
```

Add `export 'bloom_group_chips.dart';` to `bloom.dart` (alphabetical order).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_group_chips_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_group_chips.dart test/core/theme/bloom/bloom_group_chips_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_group_chips.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_group_chips_test.dart
git commit -m "feat(bloom): BloomGroupChips passage-group navigator

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: BloomPassageSheet

**Files:**
- Create: `lib/core/theme/bloom/bloom_passage_sheet.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_passage_sheet_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`, `BloomShadows.warm`, `BloomChip` + `BloomChipStyle`, `webScaled` (`package:lexi_core/core/utils/web_text_scale.dart`).
- Produces:
  ```dart
  class BloomPassageSheet extends StatefulWidget {
    const BloomPassageSheet({
      super.key,
      required this.tabs,            // 1 or 2 labels, e.g. ['Văn bản 1', 'Văn bản 2']
      required this.passages,        // same length as tabs
      this.initialChildSize = 0.44,  // Part 6 = 0.44, Part 7 = 0.6
      this.minChildSize = 0.12,
      this.maxChildSize = 0.9,
      this.hint = 'Kéo lên để đọc đoạn văn',
    }) : assert(tabs.length == passages.length);
    final List<String> tabs;
    final List<String> passages;
    final double initialChildSize;
    final double minChildSize;
    final double maxChildSize;
    final String hint;
  }
  ```
  A `DraggableScrollableSheet` (`snap: true`, `expand: false`) whose panel is a `surface` card with a top `BloomRadii.lg` radius + `BloomShadows.warm`. Panel top → bottom: a centered 36×4 rounded `inkFaint` drag handle; the `hint` text (`12.5`, `inkFaint`, centered); when `tabs.length > 1`, a `Row` of `BloomChip` tab selectors (active = `BloomChipStyle.active`); then the passage body — a left-accent-bordered (`Border(left: BorderSide(color: c.accent, width: 3))`), `webScaled`-styled `Text` inside a `ListView` **driven by the sheet's `scrollController`** (so drag-to-expand and scroll-the-text compose). Internal state: `_tab` (int, default 0). Host it as the **last child of a `Stack`** that fills the screen body.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_passage_sheet.dart';

Widget _host(Widget sheet) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(children: [const SizedBox.expand(), sheet]),
      ),
    );

void main() {
  testWidgets('single tab: shows the passage text and the hint', (tester) async {
    await tester.pumpWidget(_host(const BloomPassageSheet(
      tabs: ['Văn bản'],
      passages: ['The quarterly report is attached.'],
      initialChildSize: 0.6,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Kéo lên để đọc đoạn văn'), findsOneWidget);
    expect(find.text('The quarterly report is attached.'), findsOneWidget);
  });

  testWidgets('two tabs: switching the tab swaps the passage text', (tester) async {
    await tester.pumpWidget(_host(const BloomPassageSheet(
      tabs: ['Văn bản 1', 'Văn bản 2'],
      passages: ['FIRST DOC', 'SECOND DOC'],
      initialChildSize: 0.6,
    )));
    await tester.pumpAndSettle();
    expect(find.text('FIRST DOC'), findsOneWidget);
    expect(find.text('SECOND DOC'), findsNothing);

    await tester.tap(find.text('Văn bản 2'));
    await tester.pumpAndSettle();
    expect(find.text('SECOND DOC'), findsOneWidget);
    expect(find.text('FIRST DOC'), findsNothing);
  });

  testWidgets('single tab: no tab selector chips are shown', (tester) async {
    await tester.pumpWidget(_host(const BloomPassageSheet(
      tabs: ['Văn bản'],
      passages: ['x'],
    )));
    await tester.pumpAndSettle();
    // The only tappable pill-like control would be a tab; there are none.
    expect(find.text('Văn bản'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_passage_sheet_test.dart`
Expected: FAIL — `BloomPassageSheet` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import '../../utils/web_text_scale.dart';
import 'bloom_chip.dart';

/// A draggable bottom sheet holding the reading passage(s) for Part 6 / Part 7,
/// so the questions get the main content area. One [tabs] entry per document
/// (Part 7 double-passage groups pass two).
class BloomPassageSheet extends StatefulWidget {
  const BloomPassageSheet({
    super.key,
    required this.tabs,
    required this.passages,
    this.initialChildSize = 0.44,
    this.minChildSize = 0.12,
    this.maxChildSize = 0.9,
    this.hint = 'Kéo lên để đọc đoạn văn',
  }) : assert(tabs.length == passages.length);

  final List<String> tabs;
  final List<String> passages;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final String hint;

  @override
  State<BloomPassageSheet> createState() => _BloomPassageSheetState();
}

class _BloomPassageSheetState extends State<BloomPassageSheet> {
  int _tab = 0;

  @override
  void didUpdateWidget(BloomPassageSheet old) {
    super.didUpdateWidget(old);
    if (_tab >= widget.tabs.length) _tab = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      snap: true,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(BloomRadii.lg)),
            border: Border.all(color: c.border),
            boxShadow: BloomShadows.warm(isDark),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: BloomSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.inkFaint,
                  borderRadius: BorderRadius.circular(BloomRadii.pill),
                ),
              ),
              const SizedBox(height: BloomSpacing.xs),
              Text(widget.hint,
                  style: TextStyle(fontSize: 12.5, color: c.inkFaint)),
              if (widget.tabs.length > 1) ...[
                const SizedBox(height: BloomSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: BloomSpacing.sm),
                      BloomChip(
                        label: widget.tabs[i],
                        style: i == _tab
                            ? BloomChipStyle.active
                            : BloomChipStyle.neutral,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: BloomSpacing.sm),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                      BloomSpacing.lg, 0, BloomSpacing.lg, BloomSpacing.xl),
                  children: [
                    Container(
                      padding: const EdgeInsets.only(left: BloomSpacing.md),
                      decoration: BoxDecoration(
                        border: Border(
                            left: BorderSide(color: c.accent, width: 3)),
                      ),
                      child: Text(
                        widget.passages[_tab],
                        style: webScaled(TextStyle(fontSize: 15, color: c.ink)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

Add `export 'bloom_passage_sheet.dart';` to `bloom.dart` (alphabetical order).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_passage_sheet_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_passage_sheet.dart test/core/theme/bloom/bloom_passage_sheet_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_passage_sheet.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_passage_sheet_test.dart
git commit -m "feat(bloom): BloomPassageSheet draggable passage panel for Part 6/7

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: AiDisabledCard tokens + Reading hub

**Files:**
- Modify: `lib/core/widgets/ai_disabled_card.dart`
- Modify: `lib/features/reading/presentation/screens/reading_hub_screen.dart`
- Test: `test/features/reading/presentation/screens/reading_hub_screen_test.dart` (finder swaps only)

**Interfaces:**
- `AiDisabledCard` keeps its public shape: `const AiDisabledCard({super.key, required String message})`. Only the visual changes.
- `ReadingHubScreen` keeps its 4 `context.go(...)` destinations (`/reading/bilingual`, `/reading/part5`, `/reading/part6`, `/reading/part7`) and its back target `/reading` → actually `/practice` (see current `leading`).

- [ ] **Step 1: Update `ai_disabled_card.dart`**

```dart
import 'package:flutter/material.dart';
import '../theme/bloom/bloom.dart';

/// A danger-tinted notice used across home screens to explain why a generate
/// action is unavailable (AI not configured, not enough saved words, ...).
class AiDisabledCard extends StatelessWidget {
  const AiDisabledCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BloomSpacing.lg),
      decoration: BoxDecoration(
        color: c.dangerBg,
        border: Border.all(color: c.danger),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      child: Text(message, style: TextStyle(color: c.danger)),
    );
  }
}
```

- [ ] **Step 2: Run the widgets that consume it, to catch regressions early**

Run: `flutter test test/features/reading/ test/features/word_radar/ test/features/listening/`
Expected: PASS or only finder mismatches you will fix in later tasks — but the AiDisabledCard message text is unchanged, so tests asserting `find.textContaining('Tính năng này yêu cầu AI')` and `find.byType(AiDisabledCard)` still pass. If a test asserted `find.byType(Card)` for this notice, change it to `find.byType(AiDisabledCard)`.

- [ ] **Step 3: Rewrite `reading_hub_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';

class ReadingHubScreen extends StatelessWidget {
  const ReadingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Luyện đọc',
        leading: BloomIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => context.go('/practice'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReadingCard(
            icon: Icons.menu_book_outlined,
            title: 'Đọc & gõ',
            subtitle:
                'Đọc đoạn văn song ngữ dùng từ vựng của bạn và luyện gõ.',
            onTap: () => context.go('/reading/bilingual'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            icon: Icons.rule_outlined,
            title: 'Part 5 — Điền câu',
            subtitle:
                '15 câu điền từ/ngữ pháp trắc nghiệm kiểu TOEIC Part 5.',
            onTap: () => context.go('/reading/part5'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            icon: Icons.article_outlined,
            title: 'Part 6 — Điền đoạn văn',
            subtitle:
                '3 đoạn văn ngắn, mỗi đoạn 4 chỗ trống, kiểu TOEIC Part 6.',
            onTap: () => context.go('/reading/part6'),
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            icon: Icons.dynamic_feed_outlined,
            title: 'Part 7 — Đọc hiểu',
            subtitle:
                '2 đoạn văn đơn + 1 bộ đoạn đôi, kèm câu hỏi trắc nghiệm kiểu TOEIC Part 7.',
            onTap: () => context.go('/reading/part7'),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.sageBg,
              borderRadius: BorderRadius.circular(BloomRadii.md),
            ),
            child: Icon(icon, size: 20, color: c.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.inkFaint),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update `reading_hub_screen_test.dart`**

Swap any `find.byType(Card)` / `find.byType(ListTile)` / `find.byType(AppBar)` finders to `find.byType(BloomCard)` / `find.text(<title>)` / `find.byType(BloomAppBar)`. Keep every navigation assertion: tapping "Đọc & gõ" still routes to `/reading/bilingual`, etc. If the test taps `find.text('Part 5 — Điền câu')` that still works.

- [ ] **Step 5: Run the reading hub + ai card tests**

Run: `flutter test test/features/reading/presentation/screens/reading_hub_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyzer + commit**

Run: `flutter analyze` → count must be ≤ 21, no new issues.
```bash
git add lib/core/widgets/ai_disabled_card.dart lib/features/reading/presentation/screens/reading_hub_screen.dart test/features/reading/presentation/screens/reading_hub_screen_test.dart
git commit -m "feat(reading): Bloom Reading hub + Bloom-token AiDisabledCard

analyze: N infos (was 21).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: Đọc & gõ home screen

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_home_screen.dart`
- Test: `test/features/reading/presentation/screens/reading_home_screen_test.dart` (finder swaps)

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomPillButton` (+`BloomButtonVariant`), `BloomProgressBar`, `FilterTile`, `AiDisabledCard`, `context.bloom`.
- Frozen: `_reload()`, `_generate(...)` (incl. the due/not-due shuffle + `_wordCount` take + `readingPracticeNotifierProvider.notifier.generate(words:, level:, context: AppContext.general, targetLanguage:)` call + the `context.go('/reading/bilingual/session')` on `!session.isComplete`), `_minVocabWords = 5`, all four `_pick*` sheets, `initState` reading `settings.targetLanguage` / `settings.targetCefrLevel`.

- [ ] **Step 1: Restyle `build()`**

Replace the `Scaffold`/`AppBar` with:
```dart
return BloomScaffold(
  appBar: BloomAppBar(
    title: 'Luyện đọc & gõ',
    leading: BloomIconButton(
      icon: Icons.arrow_back_ios_new,
      onPressed: () => context.go('/reading'),
    ),
  ),
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [ /* … */ ],
    ),
  ),
);
```
- The intro paragraph: `Text(..., style: TextStyle(fontSize: 14, color: context.bloom.inkSoft))`.
- The four `FilterTile`s stay verbatim (they are Bloom-styled).
- `BloomProgressBar({required double value})` has **no indeterminate mode** (confirmed). Leave the raw `LinearProgressIndicator()` in the `topicsAsync.when(loading: ...)` branch and in the generate `loading:` branch — it is not a Bloom focal element and Plan 3 set the same precedent in the practice screens. Do not invent a `value: null` call.
- The AI-gate / low-vocab branches use `AiDisabledCard(message: ...)` — unchanged strings.
- The `sessionAsync.when(data: ...)` generate button becomes:
  ```dart
  BloomPillButton(
    label: 'Tạo bài luyện',
    icon: Icons.auto_awesome,
    variant: BloomButtonVariant.primary,
    block: true,
    onPressed: () => _generate(context, ref, words),
  )
  ```
- The `loading:` branch: `Column(mainAxisSize: MainAxisSize.min, children: [BloomProgressBar(value: null) OR LinearProgressIndicator(), SizedBox(height: 12), Text('Đang tạo bài...', style: TextStyle(color: context.bloom.inkSoft))])`.
- The `error:` branch: `Text('Lỗi tạo bài: $e', style: TextStyle(color: context.bloom.danger))` + `BloomPillButton(label: 'Thử lại', variant: BloomButtonVariant.secondary, onPressed: () => _generate(context, ref, words))`.

- [ ] **Step 2: Update the test finders**

`reading_home_screen_test.dart` mostly uses `find.text(...)` — those pass unchanged (`'Ngôn ngữ'`, `'Chủ đề'`, `'Cấp độ'`, `'Số từ dùng để tạo bài'`, `'Tạo bài luyện'`, `find.textContaining('Tính năng này yêu cầu AI')`, `find.textContaining('5 từ')`). If any test does `find.byType(FilledButton)` or `find.widgetWithText(FilledButton, 'Tạo bài luyện')`, change it to `find.widgetWithText(BloomPillButton, 'Tạo bài luyện')`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/reading_home_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 21, no new.
```bash
git add lib/features/reading/presentation/screens/reading_home_screen.dart test/features/reading/presentation/screens/reading_home_screen_test.dart
git commit -m "feat(reading): Bloom Đọc & gõ setup screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Đọc & gõ session screen

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_session_screen.dart`
- Test: `test/features/reading/presentation/screens/reading_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomProgressBar`, `context.bloom`, `webScaled`.
- Frozen: the outer `ref.listen(...)` (sentence-change → clear+refocus; `isComplete` → post-frame `context.go('/reading/bilingual/session/result', extra: ReadingSessionResult(...))`), the null/`isComplete` guards, `_onTyped` → `updateTypedText`, the `_PassageDisplay._opacity(...)` fade curve, `_HighlightedText` span logic, `_TypingArea`'s `Stack` of `IgnorePointer(RichText)` + transparent `TextField` sharing `baseStyle` + `strutStyle`, `vocabListForLanguageProvider(session.passage.targetLanguage)` lookup.

- [ ] **Step 1: Restyle**

- `_SessionScaffold` returns `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/reading/bilingual'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Câu ${...} / ${...}', automaticallyImplyLeading: false, actions: [BloomIconButton(icon: Icons.copy, tooltip: 'Sao chép đoạn văn', onPressed: () => _copyPassage(context, session))]), body: ...))`.
- `_PassageDisplay`: wrap the scrolling `Column` of sentences in a `BloomCard` (`padding: EdgeInsets.all(16)`). `_HighlightedText`: the highlighted (learned-word) spans change from `fontWeight: bold + underline` to `fontWeight: w700, color: context.bloom.sage, backgroundColor: context.bloom.sageBg` (keep the plain spans at `context.bloom.ink`). Pass the base `style` as `webScaled(TextStyle(fontSize: 15, color: context.bloom.ink))`.
- `_VietnameseRow`: the `Container` decoration → `color: context.bloom.surface3, borderRadius: BorderRadius.circular(BloomRadii.md)`; text `color: context.bloom.inkSoft`.
- `_TypingArea`: the border `Container` → `Border.all(color: context.bloom.border)`, `borderRadius: BorderRadius.circular(BloomRadii.md)`. In `_buildSpans`: correct char → `color: context.bloom.success`; wrong char → `color: context.bloom.danger`, `backgroundColor: context.bloom.dangerBg`; untyped char → `color: context.bloom.inkFaint`. `cursorColor: context.bloom.accent`.
- Replace `const Divider(height: 24)` with `SizedBox(height: BloomSpacing.lg)`.
- Replace the bottom `LinearProgressIndicator(value: ...)` with `BloomProgressBar(value: session.currentSentenceIndex / session.passage.sentences.length)`.

- [ ] **Step 2: Update the test**

`reading_session_screen_test.dart` asserts `find.textContaining('Hello.')` (`findsWidgets`), `find.text('Xin chào.')`, `find.byType(TextField)` — all still hold (the typed area keeps its `TextField`; the passage/translation text is unchanged). Add one assertion: `expect(find.byType(BloomProgressBar), findsOneWidget);` and, if the test references `find.byType(AppBar)`, swap to `find.byType(BloomAppBar)`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/reading_session_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 21, no new.
```bash
git add lib/features/reading/presentation/screens/reading_session_screen.dart test/features/reading/presentation/screens/reading_session_screen_test.dart
git commit -m "feat(reading): Bloom Đọc & gõ session (sage learned-word highlight, mono typing)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Đọc & gõ result screen

**Files:**
- Modify: `lib/features/reading/presentation/screens/reading_result_screen.dart`
- Test: `test/features/reading/presentation/screens/reading_result_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomListRow`, `BloomPillButton` (+`BloomButtonVariant`), `context.bloom`, `webScaled`.
- Frozen: `initState` post-frame `statsServiceProvider.recordPracticeSession(result.passage.vocabIds.length)`, the `result.overallAccuracy` / `result.wpm` / `result.totalDuration` / `result.finalScore` math and their `toStringAsFixed`, `_formatDuration`, `_copyPassage`, `_regenerate` (`reset()` + `context.go('/reading/bilingual')`), `_goHome` (`reset()` + `context.go('/')`), `vocabListForLanguageProvider(result.passage.targetLanguage)` lookup, `ResultSuggestionsSection(...)` usage.

- [ ] **Step 1: Restyle**

- Wrap the body in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/reading/bilingual'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false, actions: [BloomIconButton(icon: Icons.copy, ...)]), body: ...))`.
- The stats row: four `_StatCard`s become a single `BloomCard` containing a `Row(mainAxisAlignment: spaceEvenly)` of four small `Column`s: `Text(value, style: TextStyle(fontSize: 18, fontWeight: w800, color: context.bloom.accent))` over `Text(label, style: TextStyle(fontSize: 11.5, color: context.bloom.inkSoft))`. Labels/values unchanged (`'Độ chính xác' '$accuracyPct%'`, `'Tốc độ' '$wpm WPM'`, `'Thời gian' elapsed`, `'Điểm' '$scorePct%'`).
- "Từ vựng đã luyện" section header → `Text('Từ vựng đã luyện', style: TextStyle(fontWeight: w700, color: context.bloom.ink))`. Replace the `ListView.separated` of `ListTile`s with a `Column` of `BloomListRow`s (or `BloomCard`s) — one per `usedRecords` entry: title = `record.headword`, subtitle = `record.meaning` (2-line ellipsis). Check `BloomListRow`'s constructor and match it; if it doesn't fit, use a plain `BloomCard(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Column(cross: start, [Text(headword, w700 ink), Text(meaning, inkSoft, maxLines: 2, ellipsis)]))`.
- Action buttons: `BloomPillButton(label: 'Sinh bài mới', variant: BloomButtonVariant.primary, block: true, onPressed: () => _regenerate(context, ref))` and `BloomPillButton(label: 'Về trang chính', variant: BloomButtonVariant.secondary, block: true, onPressed: () => _goHome(context, ref))`.

- [ ] **Step 2: Update the test**

Swap `find.byType(AppBar)` → `find.byType(BloomAppBar)`, `find.widgetWithText(FilledButton, 'Sinh bài mới')` → `find.widgetWithText(BloomPillButton, 'Sinh bài mới')`, `find.widgetWithText(OutlinedButton, 'Về trang chính')` → `find.widgetWithText(BloomPillButton, 'Về trang chính')`. Keep the value assertions (`find.textContaining('WPM')`, the accuracy %, the headword). Keep the "records `recordPracticeSession`" assertion.

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/reading_result_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 21, no new.
```bash
git add lib/features/reading/presentation/screens/reading_result_screen.dart test/features/reading/presentation/screens/reading_result_screen_test.dart
git commit -m "feat(reading): Bloom Đọc & gõ result screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Part 5 home + result screens

**Files:**
- Modify: `lib/features/reading/presentation/screens/part5_home_screen.dart`, `part5_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part5_home_screen_test.dart`, `part5_result_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomPillButton`, `BloomMcOption` (+`BloomMcState`), `FilterTile`, `AiDisabledCard`, `context.bloom`, `webScaled`.
- Frozen: `_generate(...)` (`part5PracticeNotifierProvider.notifier.generate(context: _context, targetLanguage: _language, volumes: _volumes)` + `context.go('/reading/part5/session')`), `initState` (`_context = AppContext.general`), `_pick*` sheets, result screen's `initState` `recordPracticeSession(result.set.questions.length)`, `_regenerate` / `_goHome`, `result.correctCount`, `ResultSuggestionsSection`.

- [ ] **Step 1: `part5_home_screen.dart`** — same restyle recipe as Task 5: `BloomScaffold` + `BloomAppBar(title: 'Part 5 — Điền câu', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/reading')))`; intro `Text` → `inkSoft`; three `FilterTile`s verbatim; `if (!settings.aiEnabled) AiDisabledCard(message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.')`; generate/loading/error branches → `BloomPillButton` + `inkSoft`/`danger` text, exactly like Task 5.

- [ ] **Step 2: `part5_result_screen.dart`**

- `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/reading/part5'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false), body: ...))`.
- The `${result.correctCount}/$total` headline: `Text(..., style: TextStyle(fontSize: 34, fontWeight: w800, color: result.correctCount == total ? context.bloom.success : context.bloom.accent))`.
- `_QuestionBreakdown`: outer `Card` → `BloomCard`. The correct/wrong `Icon` → `Icons.check_circle` in `context.bloom.success` / `Icons.cancel` in `context.bloom.danger`. Replace the per-option `Text` list with `BloomMcOption` tiles in **read-only** state: `BloomMcOption(label: option, onTap: null, state: i == question.correctIndex ? BloomMcState.correct : (i == selected ? BloomMcState.wrong : BloomMcState.neutral))`. Keep `Text('Giải thích: ${question.explanation}', style: webScaled((bodySmall).copyWith(fontStyle: italic, color: context.bloom.inkSoft)))`.
- Buttons: `BloomPillButton(label: 'Bài khác', variant: primary, block: true, onPressed: () => _regenerate(context, ref))`, `BloomPillButton(label: 'Về trang chính', variant: secondary, block: true, onPressed: () => _goHome(context, ref))`.

- [ ] **Step 3: Update tests**

- `part5_home_screen_test.dart`: `find.text` assertions for picker labels + `'Tạo bài luyện'` + AI message pass unchanged; swap any `FilledButton` finder → `BloomPillButton`.
- `part5_result_screen_test.dart`: swap `find.byType(Card)` → `find.byType(BloomCard)`; option-text assertions still pass (`BloomMcOption` renders its label as `Text`); explanation-text assertion unchanged; button finders → `BloomPillButton`. Keep the score assertion and the `recordPracticeSession` assertion.

- [ ] **Step 4: Run**

Run: `flutter test test/features/reading/presentation/screens/part5_home_screen_test.dart test/features/reading/presentation/screens/part5_result_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyzer + commit**

Run: `flutter analyze` → ≤ 21, no new.
```bash
git add lib/features/reading/presentation/screens/part5_home_screen.dart lib/features/reading/presentation/screens/part5_result_screen.dart test/features/reading/presentation/screens/part5_home_screen_test.dart test/features/reading/presentation/screens/part5_result_screen_test.dart
git commit -m "feat(reading): Bloom Part 5 home + result

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Part 5 session screen

**Files:**
- Modify: `lib/features/reading/presentation/screens/part5_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part5_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomPillButton`, `BloomMcOption` (+`BloomMcState`), `context.bloom`, `webScaled`.
- Frozen: the `ref.listen(...)` submit-navigation, null/`isSubmitted` guards, `notifier.selectAnswer(i, optionIndex)`, `notifier.submit`, `session.canSubmit`, `session.set.questions`, `session.selectedAnswers[i]`.

- [ ] **Step 1: Restyle**

- `_SessionScaffold` → `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/reading/part5'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Part 5 — Điền câu', automaticallyImplyLeading: false), body: Padding(padding: EdgeInsets.all(16), child: Column(children: [Expanded(SingleChildScrollView(...)), _SubmitBar(...)]))))`.
- `_QuestionCard` → `BloomCard`: header `Text('${index + 1}. ${question.sentenceWithBlank}', style: webScaled(TextStyle(fontSize: 14, fontWeight: w700, color: context.bloom.ink)))`, then a `Column` of `BloomMcOption` for each option:
  ```dart
  BloomMcOption(
    label: option,
    leading: String.fromCharCode(65 + i), // A, B, C, D
    onTap: () => onSelected(i),
    state: selected == i ? BloomMcState.selected : BloomMcState.neutral,
  )
  ```
  with `SizedBox(height: BloomSpacing.sm)` between options.
- Sticky submit: a bottom bar `Padding(padding: EdgeInsets.only(top: 8), child: BloomPillButton(label: 'Nộp bài', variant: BloomButtonVariant.primary, block: true, onPressed: session.canSubmit ? notifier.submit : null))`. (`BloomPillButton` with `onPressed: null` renders disabled — verify against its implementation; if it needs an explicit disabled style it already handles it.)

- [ ] **Step 2: Update the test**

`part5_session_screen_test.dart`:
- "shows all 3 question sentences" — `find.textContaining('Sentence 0 ___.')` etc. still pass.
- The two "Nộp bài disabled/enabled" tests use `tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'))` then check `.onPressed`. Change to:
  ```dart
  final button = tester.widget<BloomPillButton>(
      find.widgetWithText(BloomPillButton, 'Nộp bài'));
  expect(button.onPressed, isNull); // or isNotNull
  ```
  Confirm `BloomPillButton` exposes `onPressed` as a field (it does — Plan 1). If the label is rendered by an inner widget and `widgetWithText` fails, fall back to `find.byType(BloomPillButton)` (there is only one).
- "selecting an option and submitting navigates" — the pre-answered session path taps `find.widgetWithText(BloomPillButton, 'Nộp bài')` and expects `find.text('Result screen')`.
- Add: a test that taps `find.text('b')` under question 1 (index 1) and asserts `container.read(part5PracticeNotifierProvider).value!.selectedAnswers[1] == 1` — proving `BloomMcOption` wiring passes `(questionIndex, optionIndex)` correctly. (`find.text('b')` may match 3 tiles — use `find.descendant(of: find.byType(BloomCard).at(1), matching: find.text('b'))`.)

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/part5_session_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → the `RadioListTile<int>` deprecation infos for this file are now gone; total ≤ 21, no new.
```bash
git add lib/features/reading/presentation/screens/part5_session_screen.dart test/features/reading/presentation/screens/part5_session_screen_test.dart
git commit -m "feat(reading): Bloom Part 5 session (BloomMcOption list + sticky submit)

analyze: N infos (was 21).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Part 6 home + result screens

**Files:**
- Modify: `lib/features/reading/presentation/screens/part6_home_screen.dart`, `part6_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part6_home_screen_test.dart`, `part6_result_screen_test.dart`

**Interfaces:** identical recipe to Task 8, for Part 6.
- Frozen: `_generate(...)` (`part6PracticeNotifierProvider.notifier.generate(context: _context, targetLanguage: _language, volumes: _volumes)` + `context.go('/reading/part6/session')`), result `initState` `recordPracticeSession(_totalQuestions)` where `_totalQuestions = result.set.passages.fold(0, (s, p) => s + p.questions.length)`, `Part6SessionState.flatIndex(p, q)`, `result.correctCount`, `_passagesText`, `ResultSuggestionsSection`.

- [ ] **Step 1: `part6_home_screen.dart`** — Task 5 recipe. `BloomAppBar(title: 'Part 6 — Điền đoạn văn', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/reading')))`. Three `FilterTile`s verbatim. AI gate + generate/loading/error → Task 5 pattern.

- [ ] **Step 2: `part6_result_screen.dart`**

- `PopScope(canPop: false, → context.go('/reading/part6'))` + `BloomScaffold` + `BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false)`.
- Headline `${result.correctCount}/$total` → Task 8 style.
- `_PassageBreakdown` outer `Card` → `BloomCard`. Header `Text('Đoạn ${passageIndex + 1}', style: TextStyle(fontWeight: w700, color: context.bloom.ink))`. Passage text `Text(passage.passageText, style: webScaled(TextStyle(fontSize: 13.5, color: context.bloom.inkSoft)))`.
- `_QuestionBreakdown`: correct/wrong `Icon` → Bloom `success`/`danger`. Per-option list → read-only `BloomMcOption` tiles (`onTap: null`, `state: correct` for `question.correctIndex`, `wrong` for the wrong `selected`, else `neutral`). Explanation `Text` → `inkSoft` italic.
- Buttons → `BloomPillButton` ('Bài khác' primary block, 'Về trang chính' secondary block).

- [ ] **Step 3: Update tests** — same swaps as Task 8 (`Card`→`BloomCard`, button finders → `BloomPillButton`; `find.text` for passage/option/explanation still pass; keep score + `recordPracticeSession` assertions).

- [ ] **Step 4: Run**

Run: `flutter test test/features/reading/presentation/screens/part6_home_screen_test.dart test/features/reading/presentation/screens/part6_result_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyzer + commit**

```bash
git add lib/features/reading/presentation/screens/part6_home_screen.dart lib/features/reading/presentation/screens/part6_result_screen.dart test/features/reading/presentation/screens/part6_home_screen_test.dart test/features/reading/presentation/screens/part6_result_screen_test.dart
git commit -m "feat(reading): Bloom Part 6 home + result

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Part 6 session screen (layout redesign)

**Files:**
- Modify: `lib/features/reading/presentation/screens/part6_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part6_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomGroupChips`, `BloomExpansionTile`, `BloomPassageSheet`, `BloomMcOption` (+`BloomMcState`), `BloomPillButton`, `context.bloom`, `webScaled`.
- Frozen: `ref.listen(...)` → post-frame `context.go('/reading/part6/session/result', extra: Part6SessionResult(set:, selectedAnswers:))`, null/`isSubmitted` guards, `notifier.selectAnswer(passageIndex, questionIndex, optionIndex)`, `notifier.submit`, `session.canSubmit` (**all 12** answered), `Part6SessionState.flatIndex(p, q)`, `session.set.passages`, `session.selectedAnswers`.

**New layout (spec §Phần B item 8):** one passage at a time.
- `_SessionScaffold` becomes a `ConsumerStatefulWidget` (it needs `_activePassage` local state — `int _activePassage = 0`).
- Body = `Stack`:
  1. A `Column` (with `padding: EdgeInsets.fromLTRB(16, 16, 16, sheetInset)` where `sheetInset` ≈ `MediaQuery.sizeOf(context).height * 0.44 + 16` so the questions clear the collapsed sheet — simpler: `padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * 0.15)` on the scroll view and let the sheet float; pick whichever keeps the last question tappable above the collapsed handle):
     - `BloomGroupChips(labels: ['Đoạn 1', 'Đoạn 2', 'Đoạn 3'] up to session.set.passages.length, activeIndex: _activePassage, onChanged: (i) => setState(() => _activePassage = i))`
     - `SizedBox(height: BloomSpacing.md)`
     - `Expanded(child: ListView(children: [ for q in 0..3: BloomExpansionTile(...) ]))` for `session.set.passages[_activePassage]`:
       ```dart
       BloomExpansionTile(
         title: 'Chỗ trống (${q + 1})',
         answered: selected != null,
         summary: selected == null
             ? 'Chưa trả lời'
             : 'Đã chọn: ${question.options[selected]}',
         initiallyExpanded: selected == null && q == 0,
         child: Column(
           children: [
             for (var o = 0; o < question.options.length; o++) ...[
               if (o > 0) const SizedBox(height: BloomSpacing.sm),
               BloomMcOption(
                 label: question.options[o],
                 leading: String.fromCharCode(65 + o),
                 onTap: () => notifier.selectAnswer(_activePassage, q, o),
                 state: selected == o
                     ? BloomMcState.selected
                     : BloomMcState.neutral,
               ),
             ],
           ],
         ),
       )
       ```
       where `selected = session.selectedAnswers[Part6SessionState.flatIndex(_activePassage, q)]`.
     - Below the list, a `BloomPillButton(label: 'Nộp bài', variant: primary, block: true, onPressed: session.canSubmit ? notifier.submit : null)` — pinned (not inside the scroll).
  2. `BloomPassageSheet(tabs: const ['Đoạn văn'], passages: [session.set.passages[_activePassage].passageText], initialChildSize: 0.44)` — **keyed** `key: ValueKey(_activePassage)` so switching the chip rebuilds it with the new passage.
- App bar: `BloomAppBar(title: 'Part 6 — Điền đoạn văn', automaticallyImplyLeading: false)`, wrapped in `PopScope(canPop: false, → context.go('/reading/part6'))`.

- [ ] **Step 1: Rewrite `part6_session_screen.dart`** per the layout above. Keep the outer `Part6SessionScreen` `ConsumerWidget` (the `ref.listen` + `sessionAsync.when` shell) exactly as-is; only `_SessionScaffold` and its children change.

- [ ] **Step 2: Rewrite `part6_session_screen_test.dart`**

The old test asserted all 3 passages visible at once. New assertions:
```dart
testWidgets('shows passage 1 questions first; chips switch passages', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();

  // Đoạn 1 active: its blanks are listed.
  expect(find.text('Chỗ trống (1)'), findsOneWidget);
  expect(find.byType(BloomGroupChips), findsOneWidget);

  // Passage 1 text reachable via the sheet.
  expect(find.textContaining('Passage 0'), findsOneWidget);

  // Switch to Đoạn 2.
  await tester.tap(find.text('Đoạn 2'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Passage 1'), findsOneWidget);
  expect(find.textContaining('Passage 0'), findsNothing);
});

testWidgets('expanding a blank and picking an option writes only that flat slot', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();

  // Đoạn 1 / blank 2 -> option "b".
  await tester.tap(find.text('Chỗ trống (2)'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(
    of: find.byType(BloomExpansionTile),
    matching: find.text('b'),
  ).last);
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
    tester.element(find.byType(Part6SessionScreen)), listen: false);
  final answers =
      container.read(part6PracticeNotifierProvider).value!.selectedAnswers;
  expect(answers[Part6SessionState.flatIndex(0, 1)], 1);
  expect(answers[Part6SessionState.flatIndex(0, 0)], isNull);
});

testWidgets('Nộp bài disabled until all 12 answered, enabled when full', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();
  expect(
    tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed,
    isNull,
  );

  await tester.pumpWidget(_buildSession(
    session: Part6SessionState(
      set: _testSet,
      selectedAnswers: List<int?>.filled(12, 0),
      isSubmitted: false,
    ),
  ));
  await tester.pumpAndSettle();
  expect(
    tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed,
    isNotNull,
  );
});

testWidgets('submitting navigates to the result screen', (tester) async {
  await tester.pumpWidget(_buildSession(
    session: Part6SessionState(
      set: _testSet,
      selectedAnswers: List<int?>.filled(12, 0),
      isSubmitted: false,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BloomPillButton));
  await tester.pumpAndSettle();
  expect(find.text('Result screen'), findsOneWidget);
});
```
Keep the existing `_buildSession` / `_FakePart6Notifier` / `_testSet` scaffolding. Add the imports for `BloomGroupChips`, `BloomExpansionTile`, `BloomPillButton` from the barrel.

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/part6_session_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 4: Full reading suite + analyzer**

Run: `flutter test test/features/reading/`
Run: `flutter analyze`
Expected: all green; analyze ≤ 21, no new (Part 6 session's `RadioListTile` infos now gone).

- [ ] **Step 5: Commit**

```bash
git add lib/features/reading/presentation/screens/part6_session_screen.dart test/features/reading/presentation/screens/part6_session_screen_test.dart
git commit -m "feat(reading): Bloom Part 6 session — passage sheet + group chips + expansion tiles

One passage at a time: BloomGroupChips navigates the 3 passages, each blank is a
BloomExpansionTile summarising its answer, the passage text lives in a draggable
BloomPassageSheet. Submit still requires all 12 blanks. analyze: N (was 21).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: Part 7 home + result screens

**Files:**
- Modify: `lib/features/reading/presentation/screens/part7_home_screen.dart`, `part7_result_screen.dart`
- Test: `test/features/reading/presentation/screens/part7_home_screen_test.dart`, `part7_result_screen_test.dart`

**Interfaces:** Task 8 recipe, for Part 7.
- Frozen: `_generate(...)` (`part7PracticeNotifierProvider.notifier.generate(context: _context, targetLanguage: _language, volumes: _volumes)` + `context.go('/reading/part7/session')`), result `initState` `recordPracticeSession(...)`, `Part7SessionState.flatIndex(allGroups, g, q)`, `result.correctCount`, the `isDouble = group.documents.length == 2` label branch (`'Đoạn ${groupIndex + 1} (2 văn bản liên quan)'` vs `'Đoạn ${groupIndex + 1}'`), `ResultSuggestionsSection`.

- [ ] **Step 1: `part7_home_screen.dart`** — Task 5 recipe. `BloomAppBar(title: 'Part 7 — Đọc hiểu', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/reading')))`. Three `FilterTile`s verbatim. AI gate + branches → Task 5 pattern.

- [ ] **Step 2: `part7_result_screen.dart`**

- `PopScope(canPop: false, → context.go('/reading/part7'))` + `BloomScaffold` + `BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false)`.
- `_PassageGroupBreakdown` outer `Card` → `BloomCard`. Group header `Text(isDouble ? 'Đoạn ${groupIndex + 1} (2 văn bản liên quan)' : 'Đoạn ${groupIndex + 1}', style: TextStyle(fontWeight: w700, color: context.bloom.ink))`. Each `documents[d]` `Text(..., style: webScaled(TextStyle(fontSize: 13.5, color: context.bloom.inkSoft)))`.
- `_QuestionBreakdown`: `Text('$questionNumber. ${question.question}', ...)` stays; correct/wrong `Icon` → Bloom `success`/`danger`; per-option list → read-only `BloomMcOption` (`correct` / `wrong` / `neutral`); explanation → `inkSoft` italic.
- Buttons → `BloomPillButton` ('Bài khác' primary block, 'Về trang chính' secondary block).

- [ ] **Step 3: Update tests** — Task 8 swaps. Keep the double-passage label assertion, the score assertion, `recordPracticeSession`.

- [ ] **Step 4: Run**

Run: `flutter test test/features/reading/presentation/screens/part7_home_screen_test.dart test/features/reading/presentation/screens/part7_result_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyzer + commit**

```bash
git add lib/features/reading/presentation/screens/part7_home_screen.dart lib/features/reading/presentation/screens/part7_result_screen.dart test/features/reading/presentation/screens/part7_home_screen_test.dart test/features/reading/presentation/screens/part7_result_screen_test.dart
git commit -m "feat(reading): Bloom Part 7 home + result

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: Part 7 session screen (layout redesign)

**Files:**
- Modify: `lib/features/reading/presentation/screens/part7_session_screen.dart`
- Test: `test/features/reading/presentation/screens/part7_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomGroupChips`, `BloomPassageSheet`, `BloomMcOption` (+`BloomMcState`), `BloomPillButton`, `context.bloom`, `webScaled`.
- Frozen: `ref.listen(...)` → post-frame `context.go('/reading/part7/session/result', extra: Part7SessionResult(set:, selectedAnswers:))`, null/`isSubmitted` guards, `notifier.selectAnswer(groupIndex, questionIndex, optionIndex)`, `notifier.submit`, `session.canSubmit`, `Part7SessionState.flatIndex(session.set.passageGroups, g, q)`, `session.set.passageGroups`, `session.selectedAnswers`.

**New layout (spec §Phần B item 9):** one passage group at a time.
- `_SessionScaffold` → `ConsumerStatefulWidget` with `int _activeGroup = 0`.
- Body = `Stack`:
  1. `Column`:
     - `BloomGroupChips(labels: [for g in 0..<groups.length: 'Đoạn ${g + 1}'], activeIndex: _activeGroup, onChanged: (i) => setState(() => _activeGroup = i))`
     - `SizedBox(height: BloomSpacing.md)`
     - `Expanded(child: ListView(children: [ for q in group.questions: _QuestionCard ]))` where each question renders:
       ```dart
       Text('${q + 1}. ${question.question}',
           style: webScaled(TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.bloom.ink))),
       for (var o = 0; o < question.options.length; o++) ...[
         SizedBox(height: BloomSpacing.sm),
         BloomMcOption(
           label: question.options[o],
           leading: String.fromCharCode(65 + o),
           onTap: () => notifier.selectAnswer(_activeGroup, q, o),
           state: selected == o ? BloomMcState.selected : BloomMcState.neutral,
         ),
       ]
       ```
       with `selected = session.selectedAnswers[Part7SessionState.flatIndex(session.set.passageGroups, _activeGroup, q)]`. Wrap each question in a `BloomCard`.
     - Pinned `BloomPillButton(label: 'Nộp bài', variant: primary, block: true, onPressed: session.canSubmit ? notifier.submit : null)`.
  2. `BloomPassageSheet(key: ValueKey(_activeGroup), tabs: group.documents.length == 2 ? const ['Văn bản 1', 'Văn bản 2'] : const ['Văn bản'], passages: group.documents, initialChildSize: 0.6)` where `group = session.set.passageGroups[_activeGroup]`.
- `BloomAppBar(title: 'Part 7 — Đọc hiểu', automaticallyImplyLeading: false)` + `PopScope(canPop: false, → context.go('/reading/part7'))`.

- [ ] **Step 1: Rewrite `part7_session_screen.dart`** per the layout above. Outer `Part7SessionScreen` `ConsumerWidget` shell unchanged.

- [ ] **Step 2: Rewrite `part7_session_screen_test.dart`**

```dart
testWidgets('group 1 questions first; chips switch groups; sheet holds the docs', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();

  expect(find.byType(BloomGroupChips), findsOneWidget);
  // group 0 doc text visible in the sheet
  expect(find.textContaining(_group0DocSnippet), findsOneWidget);

  await tester.tap(find.text('Đoạn 3')); // the double-passage group
  await tester.pumpAndSettle();
  // two text tabs appear for the double passage
  expect(find.text('Văn bản 1'), findsOneWidget);
  expect(find.text('Văn bản 2'), findsOneWidget);
});

testWidgets('answering group 3 / question 1 writes the right flat slot', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đoạn 3'));
  await tester.pumpAndSettle();

  await tester.tap(find.descendant(
    of: find.byType(BloomCard),
    matching: find.text('b'),
  ).first);
  await tester.pumpAndSettle();

  final container = ProviderScope.containerOf(
      tester.element(find.byType(Part7SessionScreen)), listen: false);
  final answers =
      container.read(part7PracticeNotifierProvider).value!.selectedAnswers;
  final groups = _testSet.passageGroups;
  expect(answers[Part7SessionState.flatIndex(groups, 2, 0)], 1);
  expect(answers[Part7SessionState.flatIndex(groups, 0, 0)], isNull);
});

testWidgets('Nộp bài disabled until every question answered', (tester) async {
  await tester.pumpWidget(_buildSession());
  await tester.pumpAndSettle();
  expect(tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed, isNull);
});

testWidgets('submitting (all answered) navigates to the result screen', (tester) async {
  final total = _testSet.passageGroups.fold<int>(0, (s, g) => s + g.questions.length);
  await tester.pumpWidget(_buildSession(
    session: Part7SessionState(
      set: _testSet,
      selectedAnswers: List<int?>.filled(total, 0),
      isSubmitted: false,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BloomPillButton));
  await tester.pumpAndSettle();
  expect(find.text('Result screen'), findsOneWidget);
});
```
Build `_testSet` with three groups `[single(3 q), single(3 q), double(5 q)]` matching the real shape; expose a `_group0DocSnippet` constant from its first document. Keep `_buildSession` / `_FakePart7Notifier` scaffolding; add barrel imports.

- [ ] **Step 3: Run**

Run: `flutter test test/features/reading/presentation/screens/part7_session_screen_test.dart`
Expected: PASS.

- [ ] **Step 4: Full suite + analyzer**

Run: `flutter test`
Run: `flutter analyze`
Expected: suite green and strictly above 678; analyze ≤ 21, zero new issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reading/presentation/screens/part7_session_screen.dart test/features/reading/presentation/screens/part7_session_screen_test.dart
git commit -m "feat(reading): Bloom Part 7 session — passage sheet (double-doc tabs) + group chips

One group at a time: BloomGroupChips navigates the 3 groups, questions are
BloomMcOption lists, the passage(s) live in a BloomPassageSheet that shows
'Văn bản 1/2' tabs for the double-passage group. analyze: N (was 21).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (§Phần B items 6–9):**
- Item 6 (Reading hub + Đọc & gõ): hub = Task 4; home = Task 5; session (`BloomCard` + sage learned-word highlight + `surface-3` translation + mono green/red typing + `BloomProgressBar`) = Task 6; result = Task 7. ✓
- Item 7 (Part 5, list of `BloomMcOption`, sticky submit bar, NO sheet): home/result = Task 8; session = Task 9. ✓
- Item 8 (Part 6, `BloomPassageSheet` `initialChildSize: 0.44` 1 tab, `BloomGroupChips`, `BloomExpansionTile` questions with "đã chọn / chưa trả lời" summary): widgets = Tasks 1–3; home/result = Task 10; session = Task 11. ✓ — inline numbered blanks `(1)(2)(3)` are already how `passageText` is authored by the source; the sheet renders them verbatim.
- Item 9 (Part 7, `BloomPassageSheet` `initialChildSize: 0.6`, "Văn bản 1/2" tabs when double, `BloomGroupChips`, `BloomMcOption` questions): home/result = Task 12; session = Task 13. ✓
- Widget-table rows `BloomExpansionTile` / `BloomPassageSheet` / `BloomGroupChips` = Tasks 1–3. ✓
- `AiKeyMissingCard` (widget-table row): **deliberately deferred to Plan 6** with the rest of C2 — Task 4 restyles `AiDisabledCard` in place without the rename. Called out in Global Constraints.
- §Testing "BloomPassageSheet / BloomExpansionTile / BloomGroupChips need interaction tests (drag/open/tab/group switch)": Task 1 tests open, Task 2 tests group switch, Task 3 tests tab switch. Drag is exercised indirectly (the sheet renders and its text is reachable); a raw `DraggableScrollableSheet` drag test is flaky and out of scope.

**2. Placeholder scan:** every step names exact files, exact widget APIs, exact frozen call signatures, and gives full widget source for Tasks 1–3. Screen-restyle tasks (4–13) reference a shared recipe rather than repeating ~150 lines of near-identical `BloomScaffold`/`BloomAppBar`/`FilterTile`/`AiDisabledCard` boilerplate four times — the recipe (Task 5 Step 1) is spelled out in full once and the deltas per screen are explicit. This is intentional DRY, not a placeholder.

**3. Type consistency:**
- `BloomExpansionTile({title, summary, child, answered, initiallyExpanded})` — consumed identically in Task 11.
- `BloomGroupChips({labels, activeIndex, onChanged})` — consumed identically in Tasks 11, 13.
- `BloomPassageSheet({tabs, passages, initialChildSize, minChildSize, maxChildSize, hint})` — consumed in Tasks 11 (1 tab, 0.44) and 13 (1–2 tabs, 0.6).
- `BloomMcOption({label, onTap, state, leading})` and `BloomMcState.{neutral,selected,correct,wrong}` — from Plan 3, unchanged; used read-only (`onTap: null`) in result screens, interactive in session screens.
- `BloomPillButton({label, onPressed, variant, block, icon})` + `BloomButtonVariant.{primary,secondary,danger,link}` — from Plan 1; `.onPressed` is a public field (tests read it).
- `Part6SessionState.flatIndex(int passageIndex, int questionIndex)` / `Part7SessionState.flatIndex(List<Part7PassageGroup> groups, int groupIndex, int questionIndex)` — used with the exact arg order in session + result + tests.
- Every `context.go(...)` parent target matches `app_router.dart`: `/practice`, `/reading`, `/reading/bilingual`, `/reading/part5|6|7`.

**4. Risk notes for the implementer:**
- `BloomProgressBar` may not support an indeterminate (`value: null`) mode. If it doesn't, leave the one raw `LinearProgressIndicator` inside the `loading:`/topics-loading branches (Plan 3 set that precedent) rather than inventing an API.
- `BloomPillButton` disabled state: confirm `onPressed: null` renders a visually-disabled button; if Plan 1 built it to require a bool, adapt the call site, don't change the widget contract other tasks rely on.
- The `BloomPassageSheet` sizing inside the session `Stack`: make sure the pinned "Nộp bài" button and the last question are not hidden behind the collapsed sheet handle — give the questions `ListView` bottom padding ≈ `MediaQuery.sizeOf(context).height * (minChildSize + 0.04)`.
- Part 6/7 session: `_SessionScaffold` moves from `ConsumerWidget` to `ConsumerStatefulWidget`. The outer screen widget (`Part6SessionScreen` / `Part7SessionScreen`) stays a `ConsumerWidget` — keep the `ref.listen` + `sessionAsync.when` there.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-31-flutter-bloom-plan4-reading.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session with `executing-plans`, batched with checkpoints.

**Which approach?**
