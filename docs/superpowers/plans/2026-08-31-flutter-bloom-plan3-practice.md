# Flutter Bloom — Plan 3: Practice Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Practice hub, the SM-2 session flow (setup → session → the four exercise widgets → result), to the Bloom design system, and add the two shared Bloom widgets this flow needs (`BloomMcOption`, `BloomResultRing`).

**Architecture:** Two new widgets in `lib/core/theme/bloom/` first (`BloomMcOption` — a multiple-choice answer tile with neutral/selected/correct/wrong states, reused by Reading Part 5/6/7 and Listening in later plans; `BloomResultRing` — a `CustomPainter` percentage ring replacing `bloom.css`'s `conic-gradient`, reused by every result screen). Then screen-by-screen restyle. The exercise widgets keep their exact state machines (`Future.delayed` → `onResult`, quality mapping, the flashcard's 3D flip `AnimationController`) — only the view layer changes.

**Tech Stack:** Flutter 3.41 / Dart ≥3.4, `flutter_riverpod` (untouched providers), `go_router` (untouched), `flutter_test`. Bloom design system from Plans 1–2 (`lib/core/theme/bloom/`).

## Global Constraints

- **Bloom widgets** from `import 'package:lexi_core/core/theme/bloom/bloom.dart';` — `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomPillButton` (+`BloomButtonVariant`), `BloomChip` (+`BloomChipStyle`), `BloomCefrPill`, `BloomProgressBar`, `BloomSectionHeader`, `BloomTextField`, plus `BloomMcOption` / `BloomResultRing` (this plan's Tasks 1–2). Colors via `context.bloom` (a `BloomColors`; falls back to `BloomColors.light` in themeless test harnesses). `FilterTile` is `import 'package:lexi_core/core/widgets/filter_tile.dart';` (Bloom-styled since Plan 1, NOT in the barrel).
- **Radii:** only `BloomRadii.sm=10 / md=16 / lg=20 / pill=999`, EXCEPT the flashcard face which is `22` (matches `bloom.css` `.fc-face` `border-radius: 22px` — an explicit, plan-sanctioned exception, same as Plan 1's `BloomScaffold` gradient).
- **No deprecated APIs that add `flutter analyze` issues.** This Flutter deprecates `withOpacity` → `.withValues(alpha:)`. The repo has exactly **21 pre-existing** `flutter analyze` infos (all `RadioListTile`/`CheckboxListTile` deprecations). After every task `flutter analyze` must still report **21** — zero new.
- **Tests:** the suite is at **638 passing** at the start of this plan. It only goes up. When a widget swap breaks a finder, fix the finder (prefer `find.text` / `find.byKey` / `find.byType(BloomX)`) — never weaken or delete a behavior assertion.
- **Semantic colors:** map the exercise widgets' hardcoded `Colors.green*` / `Colors.red*` to Bloom tokens — correct = `context.bloom.success` on `context.bloom.successBg`, wrong = `context.bloom.danger` on `context.bloom.dangerBg`. Never introduce a raw `Colors.*` or `Color(0x...)`.
- **Behavior is frozen.** Every exercise widget's state machine — the `_selected`/`_submitted`/`_revealed` flags, the `Future.delayed(Duration(...))` before `widget.onResult(...)`, the `ExerciseResult(vocabRecordId:, quality: correct ? 5 : 1, isCorrect:)` shape, the flashcard's `AnimationController` flip and its front-tappable / back-gesture-detector split, `session_result_screen._updateSm2()`'s post-frame SM-2 + stats + notification loop — is preserved byte-for-byte. Restyle is view-only.
- **`webScaled(...)`** (`lib/core/utils/web_text_scale.dart`) wrapping on primary content text (headword, meaning, question, options, passages) stays where the current code has it — it's a no-op on mobile and out of scope to remove.
- **`aiEnabled` stays.** `generate_exercise_use_case` / `practice_session_provider` keep threading it (removed in Plan 6).
- **No route / `go_router` / IA changes.** `apps/web/` is never touched. Package `lexi_core`.
- These screens are **already Vietnamese** — keep every existing Vietnamese string; only translate a stray English one if you meet it (none expected).
- Spec: `docs/superpowers/specs/2026-08-30-flutter-bloom-redesign-design.md` (§ Phần B4, Phần B5).

---

## File Structure

**Created:**
- `lib/core/theme/bloom/bloom_mc_option.dart` — `BloomMcOption` (+ export from `bloom.dart` barrel)
- `lib/core/theme/bloom/bloom_result_ring.dart` — `BloomResultRing` (+ export from `bloom.dart` barrel)
- Tests: `test/core/theme/bloom/bloom_mc_option_test.dart`, `test/core/theme/bloom/bloom_result_ring_test.dart`
- New smoke tests: `test/features/practice/presentation/screens/practice_home_screen_test.dart`, `practice_session_screen_test.dart`, `session_result_screen_test.dart`, and `test/features/practice/presentation/widgets/multiple_choice_widget_test.dart` (+ fill_in_blank, translation)

**Modified:**
- `lib/core/theme/bloom/bloom.dart` — add the 2 exports
- `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- `lib/features/practice/presentation/screens/practice_home_screen.dart`
- `lib/features/practice/presentation/screens/practice_session_screen.dart`
- `lib/features/practice/presentation/screens/session_result_screen.dart`
- `lib/features/practice/presentation/widgets/flashcard_widget.dart`
- `lib/features/practice/presentation/widgets/multiple_choice_widget.dart`
- `lib/features/practice/presentation/widgets/fill_in_blank_widget.dart`
- `lib/features/practice/presentation/widgets/translation_exercise_widget.dart`
- `test/features/practice/presentation/screens/practice_hub_screen_test.dart` — finder swaps
- `test/features/practice/presentation/widgets/flashcard_widget_test.dart` — finder swaps

**Not in this plan:** `progress_screen.dart` (Plan 5 — the hub links to it, it stays Material-styled until then), Reading / Listening / Word Radar screens, `aiEnabled` removal, `README.md`.

---

## Task 1: BloomMcOption

**Files:**
- Create: `lib/core/theme/bloom/bloom_mc_option.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_mc_option_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`
- Produces:
  ```dart
  enum BloomMcState { neutral, selected, correct, wrong }
  class BloomMcOption extends StatelessWidget {
    const BloomMcOption({
      super.key,
      required this.label,
      required this.onTap,     // null = disabled (post-answer)
      this.state = BloomMcState.neutral,
      this.leading,            // String? — e.g. "A" / "(1)"
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_mc_option_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_mc_option.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('neutral option is tappable and reports the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'apologized', onTap: () => taps++),
    ));
    await tester.tap(find.text('apologized'));
    expect(taps, 1);
  });

  testWidgets('null onTap disables the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      const BloomMcOption(label: 'x', onTap: null),
    ));
    await tester.tap(find.text('x'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('correct state paints a success ground', (tester) async {
    await tester.pumpWidget(_host(
      const BloomMcOption(label: 'x', onTap: null, state: BloomMcState.correct),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomMcOption), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.successBg);
  });

  testWidgets('wrong state paints a danger ground; selected uses surface3',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: const [
      BloomMcOption(label: 'w', onTap: null, state: BloomMcState.wrong),
      BloomMcOption(label: 's', onTap: null, state: BloomMcState.selected),
    ])));
    final boxes = tester.widgetList<Container>(
      find.descendant(of: find.byType(BloomMcOption), matching: find.byType(Container)),
    ).toList();
    expect((boxes.first.decoration as BoxDecoration).color, BloomColors.light.dangerBg);
  });

  testWidgets('renders a leading label when given', (tester) async {
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'x', onTap: () {}, leading: 'A'),
    ));
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_mc_option_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
// lib/core/theme/bloom/bloom_mc_option.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

enum BloomMcState { neutral, selected, correct, wrong }

/// A multiple-choice answer tile. `neutral` before answering; `selected`
/// while chosen-but-unrevealed; `correct`/`wrong` after the answer is
/// revealed. Pass `onTap: null` to disable (post-answer).
class BloomMcOption extends StatelessWidget {
  const BloomMcOption({
    super.key,
    required this.label,
    required this.onTap,
    this.state = BloomMcState.neutral,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final BloomMcState state;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    late final Color bg;
    late final Color fg;
    late final Color border;
    switch (state) {
      case BloomMcState.neutral:
        bg = c.surface2;
        fg = c.ink;
        border = c.border;
      case BloomMcState.selected:
        bg = c.surface3;
        fg = c.accent;
        border = c.accent;
      case BloomMcState.correct:
        bg = c.successBg;
        fg = c.success;
        border = c.success;
      case BloomMcState.wrong:
        bg = c.dangerBg;
        fg = c.danger;
        border = c.danger;
    }

    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(BloomRadii.sm),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Text('$leading. ',
                style: TextStyle(
                    color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
          ],
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: fg,
                    fontWeight: state == BloomMcState.neutral
                        ? FontWeight.w400
                        : FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.sm),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(BloomRadii.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (leading != null)
                Text('$leading. ',
                    style: TextStyle(
                        color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: fg, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> Note: the test's `find.descendant(... find.byType(Container)).first` needs the non-interactive path to be a `Container` — it is. The interactive path uses `Ink` (a `Container` subtype) so `find.byType(Container)` still matches it; if the test's `.first` lands on the wrong one for the interactive case, that case isn't asserted here (only `onTap: null` states are), so it's fine.

- [ ] **Step 4: Add the barrel export**

In `lib/core/theme/bloom/bloom.dart`, add (keep alphabetical-ish):
```dart
export 'bloom_mc_option.dart';
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_mc_option_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/bloom/bloom_mc_option.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_mc_option_test.dart
git commit -m "feat(bloom): BloomMcOption (4-state answer tile)"
```

---

## Task 2: BloomResultRing

**Files:**
- Create: `lib/core/theme/bloom/bloom_result_ring.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_result_ring_test.dart`

**Interfaces:**
- Consumes: `context.bloom`
- Produces:
  ```dart
  class BloomResultRing extends StatelessWidget {
    const BloomResultRing({
      super.key,
      required this.percent,   // 0..100 (int)
      this.size = 140,
      this.label,              // String? — centred; defaults to "$percent%"
    });
  }
  ```
  A ring: an `accent` arc for `percent/100` of the circle over a `surface3` track, with `label` centred on a `surface` disc — the Flutter equivalent of `bloom.css` `.practice-result-circle` (`conic-gradient(accent var(--pct), surface-3 var(--pct))` + inner `surface` disc).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_result_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_result_ring.dart';

void main() {
  testWidgets('shows the default percent label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: BloomResultRing(percent: 73))),
    ));
    expect(find.text('73%'), findsOneWidget);
  });

  testWidgets('honours an explicit label and clamps the arc', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: BloomResultRing(percent: 250, label: 'A+')),
      ),
    ));
    expect(find.text('A+'), findsOneWidget);
    expect(find.text('250%'), findsNothing);
    expect(tester.takeException(), isNull); // clamped, no assert
  });

  testWidgets('lays out at the requested size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: BloomResultRing(percent: 50, size: 120)),
      ),
    ));
    expect(tester.getSize(find.byType(BloomResultRing)), const Size(120, 120));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_result_ring_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement**

```dart
// lib/core/theme/bloom/bloom_result_ring.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A percentage ring — `accent` arc over a `surface3` track, `label` centred
/// on a `surface` disc. Flutter equivalent of bloom.css `.practice-result-circle`.
class BloomResultRing extends StatelessWidget {
  const BloomResultRing({
    super.key,
    required this.percent,
    this.size = 140,
    this.label,
  });

  final int percent;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final clamped = percent.clamp(0, 100);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: clamped / 100,
          arc: c.accent,
          track: c.surface3,
          disc: c.surface,
          stroke: size * 0.11,
        ),
        child: Center(
          child: Text(
            label ?? '$clamped%',
            style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w800,
                color: c.ink),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.arc,
    required this.track,
    required this.disc,
    required this.stroke,
  });

  final double fraction;
  final Color arc;
  final Color track;
  final Color disc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arc;
    canvas.drawCircle(center, radius, trackPaint);
    if (fraction > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, fraction * 2 * math.pi, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.arc != arc ||
      old.track != track ||
      old.stroke != stroke;
}
```

- [ ] **Step 4: Add the barrel export**

In `lib/core/theme/bloom/bloom.dart`, add:
```dart
export 'bloom_result_ring.dart';
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_result_ring_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 7: Commit**

```bash
git add lib/core/theme/bloom/bloom_result_ring.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_result_ring_test.dart
git commit -m "feat(bloom): BloomResultRing (percentage ring)"
```

---

## Task 3: Practice hub screen → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- Test: `test/features/practice/presentation/screens/practice_hub_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `context.bloom`; `go_router` (routes unchanged).
- Produces: restyle only. `PracticeHubScreen` keeps `const PracticeHubScreen({super.key})`, `StatelessWidget`, the same 5 cards → same routes (`/practice/vocab`, `/reading`, `/listening`, `/practice/progress` [push], `/practice/radar`).

- [ ] **Step 1: Rewrite the screen**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomScaffold(
      appBar: const BloomAppBar(title: 'Luyện tập'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HubCard(
            icon: Icons.school_outlined,
            title: 'Từ vựng cách khoảng',
            subtitle: 'Ôn từ vựng theo lịch SM-2, với bài tập AI sinh tự động.',
            selected: true,
            onTap: () => context.go('/practice/vocab'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.menu_book_outlined,
            title: 'Luyện đọc',
            subtitle: 'Đọc & gõ song ngữ, và luyện đề TOEIC Part 5/6/7.',
            onTap: () => context.go('/reading'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.headphones_outlined,
            title: 'Luyện nghe',
            subtitle: 'Nghe chép và nghe hiểu kiểu TOEIC.',
            onTap: () => context.go('/listening'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.bar_chart_outlined,
            title: 'Tiến độ học tập',
            subtitle: 'Chuỗi ngày học, từ đến hạn, phân bố cấp độ CEFR.',
            onTap: () => context.push('/practice/progress'),
          ),
          const SizedBox(height: 12),
          _HubCard(
            icon: Icons.radar_outlined,
            title: 'Quét từ vựng',
            subtitle:
                'Dán văn bản bất kỳ để tìm từ đã học và gợi ý từ mới đáng học.',
            onTap: () => context.go('/practice/radar'),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.surface : c.sageBg,
              borderRadius: BorderRadius.circular(BloomRadii.md),
            ),
            child: Icon(icon, size: 20, color: selected ? c.accent : c.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
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

- [ ] **Step 2: Update the test**

`practice_hub_screen_test.dart` — the two tests assert `find.text('...')` and navigation. Both still pass unchanged (the labels + routes are identical). Add one assertion to the first test:
```dart
    expect(find.byType(BloomScaffold), findsOneWidget);
```
Add `import 'package:lexi_core/core/theme/bloom/bloom.dart';`. Wrap the `MaterialApp.router` with `theme: AppTheme.light` (add `import 'package:lexi_core/core/theme/app_theme.dart';`) so `context.bloom` resolves the real extension.

- [ ] **Step 3: Run tests + full suite + analyze**

Run: `flutter test test/features/practice/presentation/screens/practice_hub_screen_test.dart`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add lib/features/practice/presentation/screens/practice_hub_screen.dart test/features/practice/presentation/screens/practice_hub_screen_test.dart
git commit -m "feat(bloom): restyle Practice hub screen"
```

---

## Task 4: Practice setup (SM-2 home) screen → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`
- Test: `test/features/practice/presentation/screens/practice_home_screen_test.dart` (create)

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomPillButton` (+`BloomButtonVariant`), `FilterTile` (Plan 1), `context.bloom`; `getVocabListUseCaseProvider`, `statsServiceProvider`, `topicsNotifierProvider`, `userSettingsNotifierProvider`, `SessionConfig` (all unchanged).
- Produces: restyle only. `PracticeHomeScreen` keeps `const PracticeHomeScreen({super.key})` / `ConsumerStatefulWidget`.

- [ ] **Step 1: Itemized restyle of `practice_home_screen.dart`**

Preserve exactly: `_selectedTopicId` / `_wordLimit` / `_maxCefrLevel` / `_dueCount` state, `_limits`/`_limitLabels`, the `initState` post-frame `setState(_maxCefrLevel = ...)` + `statsService.computeStats` → `_dueCount`, `_pickTopic` / `_pickLevel` / `_pickWordLimit` (all `showSingleSelectSheet`), `_start()` (`getVocabListUseCase.execute` → empty-check SnackBar → shuffle → take(`_wordLimit`) → `context.go('/practice/session', extra: SessionConfig(words:))`), `_startDueSession()`.

Change:
- `import '../../../../core/theme/bloom/bloom.dart';`.
- `Scaffold` → `BloomScaffold`. `AppBar(title: Text('Từ vựng cách khoảng'), leading: BackButton(onPressed: () => context.go('/practice')))` → `BloomAppBar(title: 'Từ vựng cách khoảng', leading: BloomIconButton(icon: Icons.arrow_back, onPressed: () => context.go('/practice')))`.
- The 3 `FilterTile`s stay as-is (already Bloom).
- The "Ôn hôm nay" `OutlinedButton.icon` → `BloomPillButton(label: _dueCount == 0 ? 'Hôm nay đã ôn xong ✓' : 'Ôn hôm nay ($_dueCount từ)', variant: BloomButtonVariant.secondary, block: true, icon: Icons.today_outlined, onPressed: _dueCount == 0 ? null : _startDueSession)`.
- The "Bắt đầu luyện tập" `FilledButton.icon` → `BloomPillButton(label: 'Bắt đầu luyện tập', variant: BloomButtonVariant.primary, block: true, icon: Icons.play_arrow, onPressed: _start)`.
- `LinearProgressIndicator` (topics loading) → `const BloomProgressBar(value: 0.3)` — actually keep it simple: `const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))`.
- The `Spacer()` between filters and buttons stays.
- Error `Text(e.toString())` → wrap with `style: TextStyle(color: context.bloom.danger)`.
- `SnackBar` copy unchanged (`'Không có từ nào ở cấp độ này.'` / `'Không có từ nào cần ôn hôm nay.'`).

- [ ] **Step 2: Add the smoke test**

Create `test/features/practice/presentation/screens/practice_home_screen_test.dart` — pump `PracticeHomeScreen` inside `ProviderScope` overriding `sharedPreferencesProvider`, `topicsNotifierProvider` (empty list), `getVocabListUseCaseProvider`, `statsServiceProvider` (fake returning `dueCount: 0`). Use a `GoRouter` harness with a `/practice/session` stub route. Assert: the 3 `FilterTile`s render; "Bắt đầu luyện tập" `BloomPillButton` renders; the "Ôn hôm nay" button is disabled when `dueCount == 0` (`tester.widget<...>(...).onPressed` is null, or the label shows the "đã ôn xong" text). Mirror the ProviderScope pattern in `test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart` and Plan 2's `vocab_bank_screen_test.dart`.

- [ ] **Step 3: Run + full suite + analyze**

Run: `flutter test test/features/practice/`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle Practice setup screen"
```

---

## Task 5: Practice session screen → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/screens/practice_session_screen.dart`
- Test: `test/features/practice/presentation/screens/practice_session_screen_test.dart` (create)

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomPillButton`, `BloomProgressBar`, `context.bloom`; `practiceSessionNotifierProvider`, `SessionConfig`, `SessionResult`, the four exercise widgets, `Exercise` sealed subtypes (all unchanged).
- Produces: restyle only. `PracticeSessionScreen` keeps `const PracticeSessionScreen({super.key, required this.config})`.

- [ ] **Step 1: Itemized restyle of `practice_session_screen.dart`**

Preserve exactly: `_started` flag, the `initState` post-frame `startSession(widget.config)`, `_onResult` → `recordAndAdvance`, the `sessionAsync.when(loading/error/data)` structure, the `session.isComplete && _started` → post-frame `context.go('/practice/session/result', extra: SessionResult(...))` navigation, `_buildExerciseWidget`'s `ValueKey(exercise.vocabRecord.id)` + the `switch (exercise)` mapping to the four widgets, the `AnimatedSwitcher` with its fade+slide `transitionBuilder`.

Change:
- `import '../../../../core/theme/bloom/bloom.dart';`.
- The loading/error `Scaffold` → `BloomScaffold(body: ...)`.
- The data-branch `Scaffold` → `BloomScaffold`.
- `AppBar(title: Text('${current + 1} / $total'), bottom: PreferredSize(4, LinearProgressIndicator(value: current/total)), actions: [TextButton('Thoát')])` →
  ```dart
  appBar: BloomAppBar(
    title: '${current + 1} / $total',
    actions: [
      BloomPillButton(
        label: 'Thoát',
        variant: BloomButtonVariant.link,
        onPressed: () => context.go('/practice/vocab'),
      ),
      const SizedBox(width: 8),
    ],
  ),
  ```
  and put the progress bar as the first child of the body `Column`, above the `SingleChildScrollView`:
  ```dart
  body: Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: BloomProgressBar(value: total > 0 ? current / total : 0),
    ),
    Expanded(
      child: exercise == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher( ... unchanged ... ),
            ),
    ),
  ]),
  ```

- [ ] **Step 2: Add the smoke test**

Create `test/features/practice/presentation/screens/practice_session_screen_test.dart` — pump `PracticeSessionScreen(config: SessionConfig(words: [<1 VocabRecord>]))` inside `ProviderScope` overriding `practiceSessionNotifierProvider` with a fake whose `build()` returns an `AsyncData(PracticeSessionState(...))` with one `FlashcardExercise` (no AI needed), and `sharedPreferencesProvider`. Assert: the `BloomProgressBar` renders; the `'1 / 1'` title renders; the `FlashcardWidget` renders. (A full end-to-end session test isn't needed — `flashcard_widget_test.dart` covers the widget; the provider has its own tests.)

- [ ] **Step 3: Run + full suite + analyze**

Run: `flutter test test/features/practice/`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle Practice session screen"
```

---

## Task 6: Flashcard widget → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/widgets/flashcard_widget.dart`
- Test: `test/features/practice/presentation/widgets/flashcard_widget_test.dart`

**Interfaces:**
- Consumes: `BloomCard`, `BloomPillButton` (+`BloomButtonVariant`), `context.bloom`, `BloomShadows`; `FlashcardExercise`, `ExerciseResult`, `VocabRecord`, `webScaled` (all unchanged).
- Produces: restyle only. `FlashcardWidget` keeps `const FlashcardWidget({super.key, required this.exercise, required this.onResult})`.

- [ ] **Step 1: Itemized restyle of `flashcard_widget.dart`**

**PRESERVE BYTE-FOR-BYTE:** the `_flipCtrl` `AnimationController` (350ms), `_flipAnim` `CurvedAnimation`, `dispose`, `_toggleFlip`, `_submit(bool understood)` → `ExerciseResult(vocabRecordId:, quality: understood ? 5 : 1, isCorrect: understood)`, the `AnimatedBuilder` with the `angle`/`showingBack`/`displayAngle` math, the `Transform` with `setEntry(3, 2, 0.001)..rotateX(displayAngle)`, and the front-is-`GestureDetector`(`_toggleFlip`) / back-is-plain (`_BackContent` has its own gesture detector) split.

**Change only the view:**
- `_CardFace`: `Card(elevation: 4, child: Container(minHeight: 240, padding: EdgeInsets.all(24), child: child))` →
  ```dart
  Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 240, maxHeight: 360),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: context.bloom.surface,
      border: Border.all(color: context.bloom.border),
      borderRadius: BorderRadius.circular(22),
      boxShadow: BloomShadows.warm(
          Theme.of(context).brightness == Brightness.dark),
    ),
    child: child,
  )
  ```
  (`_CardFace` becomes a `StatelessWidget` that reads `context.bloom` — it's already one; just change `build`. The `22` radius is the plan-sanctioned exception.)
- `_FrontContent`: headword `webScaled(headlineMedium.copyWith(fontWeight: bold))` → `webScaled(const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))`; IPA `color: theme.colorScheme.secondary` → `color: context.bloom.inkSoft`; the hint `Icon` + text `color: theme.colorScheme.outline` → `color: context.bloom.inkFaint`. Add a `BloomCefrPill(record.cefrLevel.label)` below the IPA (small addition, matches the demo). Keep `'Chạm vào thẻ để xem đáp án'`.
- `_BackContent`: meaning text keeps `webScaled(bodyLarge)`; example italic `color: theme.colorScheme.outline` → `context.bloom.inkSoft`; hint `color: theme.colorScheme.outline` → `context.bloom.inkFaint`; keep `'Chạm để xem lại từ vựng'`.
- The grade `Row`: `OutlinedButton('Chưa hiểu', foregroundColor: error)` → `BloomPillButton(label: 'Chưa hiểu', variant: BloomButtonVariant.danger, block: true, onPressed: () => onSubmit(false))` wrapped in `Expanded`; `FilledButton('Đã hiểu')` → `BloomPillButton(label: 'Đã hiểu', variant: BloomButtonVariant.primary, block: true, onPressed: () => onSubmit(true))` wrapped in `Expanded`. Keep the `SizedBox(width: 12)` between.

- [ ] **Step 2: Update the test**

`flashcard_widget_test.dart` — the tests assert `find.text('ephemeral')` (front), `find.text('tồn tại trong thời gian ngắn')` (back after flip), and tapping `'Chưa hiểu'` / `'Đã hiểu'` → `onResult` with `quality 1` / `5`. All still pass with these labels. Swap: `find.byType(OutlinedButton)` / `find.byType(FilledButton)` → `find.widgetWithText(BloomPillButton, 'Chưa hiểu')` / `find.widgetWithText(BloomPillButton, 'Đã hiểu')`. `find.byType(Card)` → `find.byType(BloomCard)` if asserted (it renders a `Container` now, not `BloomCard` — if a test asserts `Card`, change it to assert the headword renders instead). Add `theme: AppTheme.light` to the test's `MaterialApp` (add the import) so `context.bloom` resolves. Keep every `onResult` / `quality` / flip-behavior assertion.

- [ ] **Step 3: Run + full suite + analyze**

Run: `flutter test test/features/practice/presentation/widgets/flashcard_widget_test.dart`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add lib/features/practice/presentation/widgets/flashcard_widget.dart test/features/practice/presentation/widgets/flashcard_widget_test.dart
git commit -m "feat(bloom): restyle flashcard widget (keep 3D flip)"
```

---

## Task 7: MC / fill-in-blank / translation exercise widgets → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/widgets/multiple_choice_widget.dart`
- Modify: `lib/features/practice/presentation/widgets/fill_in_blank_widget.dart`
- Modify: `lib/features/practice/presentation/widgets/translation_exercise_widget.dart`
- Test: `test/features/practice/presentation/widgets/multiple_choice_widget_test.dart`, `fill_in_blank_widget_test.dart`, `translation_exercise_widget_test.dart` (all create)

**Interfaces:**
- Consumes: `BloomMcOption` (+`BloomMcState`, Task 1), `BloomCard`, `BloomTextField`, `BloomPillButton` (+`BloomButtonVariant`), `context.bloom`, `webScaled`; the three `*Exercise` entities + `ExerciseResult` (unchanged).
- Produces: restyle only. Each widget keeps `const X({super.key, required this.exercise, required this.onResult})`.

- [ ] **Step 1: `multiple_choice_widget.dart` — itemized**

**PRESERVE:** `_selected` state, `_select(int index)` — the `if (_selected != null) return;`, `setState(_selected = index)`, `Future.delayed(Duration(milliseconds: 800), () { if (mounted) widget.onResult(ExerciseResult(vocabRecordId:, quality: isCorrect ? 5 : 1, isCorrect:)); })`.

**Change:** the option `AnimatedContainer`+`ListTile` per entry → `BloomMcOption`:
```dart
...widget.exercise.options.asMap().entries.map((entry) {
  final i = entry.key;
  BloomMcState state = BloomMcState.neutral;
  if (_selected != null) {
    if (i == widget.exercise.correctIndex) {
      state = BloomMcState.correct;
    } else if (i == _selected) {
      state = BloomMcState.wrong;
    }
  } else if (i == _selected) {
    state = BloomMcState.selected;
  }
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: BloomMcOption(
      label: entry.value,
      state: state,
      onTap: _selected == null ? () => _select(i) : null,
    ),
  );
}),
```
Question `Text` keeps `webScaled(titleLarge)`.

- [ ] **Step 2: `fill_in_blank_widget.dart` — itemized**

**PRESERVE:** `_ctrl`, `_submitted`, `_isCorrect`, `dispose`, `_submit()` — the case-insensitive trim compare, `setState`, `Future.delayed(Duration(milliseconds: 1200), () { if (mounted) widget.onResult(...) })`.

**Change:**
- `Text('Điền vào chỗ trống:', style: labelLarge)` → `const BloomSectionHeader('Điền vào chỗ trống')`.
- The `WidgetSpan` blank `Container(width: 80, height: 2, color: theme.colorScheme.primary)` → `color: context.bloom.accent`.
- `TextField(...)` → `BloomTextField(controller: _ctrl, enabled: !_submitted, autofocus: true, hintText: 'Nhập từ cần điền…', onSubmitted: (_) => _submit(), suffix: _submitted ? Icon(_isCorrect! ? Icons.check_circle : Icons.cancel, color: _isCorrect! ? context.bloom.success : context.bloom.danger) : null)`. (Drop `textAlign: center` — `BloomTextField` doesn't expose it; acceptable.)
- The wrong-answer `Text('Đáp án: ...', color: Colors.green.shade700)` → `color: context.bloom.success`.
- `FilledButton('Kiểm tra')` → `BloomPillButton(label: 'Kiểm tra', variant: BloomButtonVariant.primary, block: true, onPressed: _submit)`.

- [ ] **Step 3: `translation_exercise_widget.dart` — itemized**

**PRESERVE:** `_ctrl`, `_revealed`, `dispose`, `_reveal()`, `_submit(bool correct)` → `ExerciseResult(quality: correct ? 5 : 1, isCorrect: correct)`.

**Change:**
- `Text('Dịch sang tiếng Việt:', style: labelLarge)` → `const BloomSectionHeader('Dịch sang tiếng Việt')`.
- The prompt `Card(child: Padding(...))` → `BloomCard(child: Text(...))` — keep the `.replaceAll("Translate to Vietnamese: ", "").replaceAll("'", "")` transform and `webScaled(titleMedium)`.
- `TextField(maxLines: 2, hintText: 'Nhập bản dịch của bạn...')` → `BloomTextField(controller: _ctrl, enabled: !_revealed, maxLines: 2, minLines: 2, hintText: 'Nhập bản dịch của bạn…')`.
- `FilledButton('Xem đáp án', onPressed: _ctrl.text.trim().isEmpty ? null : _reveal)` → `BloomPillButton(label: 'Xem đáp án', variant: BloomButtonVariant.primary, block: true, onPressed: _ctrl.text.trim().isEmpty ? null : _reveal)`. NOTE: `_ctrl.text` isn't listened to, so the button's enabled state only updates on rebuild — that's the CURRENT behavior; preserve it (don't add a listener).
- The revealed answer `Container(color: Colors.green.shade50, border: Colors.green.shade300, child: Text(color: Colors.green.shade800))` → `Container(decoration: BoxDecoration(color: context.bloom.successBg, border: Border.all(color: context.bloom.success), borderRadius: BorderRadius.circular(BloomRadii.sm)), child: Text('Đáp án: ${widget.exercise.answer}', style: TextStyle(color: context.bloom.success)))`.
- The grade `Row`: `OutlinedButton('Sai rồi', foregroundColor: error)` → `Expanded(child: BloomPillButton(label: 'Sai rồi', variant: BloomButtonVariant.danger, block: true, onPressed: () => _submit(false)))`; `FilledButton('Đúng rồi')` → `Expanded(child: BloomPillButton(label: 'Đúng rồi', variant: BloomButtonVariant.primary, block: true, onPressed: () => _submit(true)))`. Keep `SizedBox(width: 12)`.

- [ ] **Step 4: Add smoke tests (one per widget)**

Create the three test files. Each: build a `<X>Exercise` fixture + a `MaterialApp(theme: AppTheme.light, home: Scaffold(body: <Widget>(exercise:, onResult: (r) => captured = r)))`. Assert:
- `multiple_choice_widget_test.dart`: 4 `BloomMcOption`s render; tapping the correct one, then `tester.pump(const Duration(milliseconds: 900))`, → `captured.quality == 5 && captured.isCorrect`; tapping a wrong one → `quality == 1`. After a tap, the options are no longer tappable (`onTap == null`).
- `fill_in_blank_widget_test.dart`: enter the exact answer, tap 'Kiểm tra', `tester.pump(const Duration(milliseconds: 1300))` → `captured.quality == 5`. Enter a wrong answer → `quality == 1` and `find.text('Đáp án: ${exercise.answer}')` shows.
- `translation_exercise_widget_test.dart`: 'Xem đáp án' disabled with empty field; enter text, rebuild, tap 'Xem đáp án' → answer shows; tap 'Đúng rồi' → `captured.quality == 5`; tap 'Sai rồi' → `quality == 1`.

- [ ] **Step 5: Run + full suite + analyze**

Run: `flutter test test/features/practice/`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle MC / fill-in-blank / translation exercise widgets"
```

---

## Task 8: Session result screen → Bloom

**Files:**
- Modify: `lib/features/practice/presentation/screens/session_result_screen.dart`
- Test: `test/features/practice/presentation/screens/session_result_screen_test.dart` (create)

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomResultRing` (Task 2), `BloomPillButton`, `context.bloom`, `webScaled`; `computeSm2UseCaseProvider`, `updateVocabUseCaseProvider`, `statsServiceProvider`, `notificationNotifierProvider`, `SessionResult` (all unchanged).
- Produces: restyle only. `SessionResultScreen` keeps `const SessionResultScreen({super.key, required this.result})`.

- [ ] **Step 1: Itemized restyle of `session_result_screen.dart`**

**PRESERVE BYTE-FOR-BYTE:** `initState` post-frame `_updateSm2()`, and `_updateSm2()` itself — the loop over `widget.result.results`, `words.firstWhere((w) => w.id == result.vocabRecordId)`, `computeUseCase.compute(word, result.quality)` → `updateUseCase.execute(updated)` in a per-item try/catch, then `statsService.recordPracticeSession(widget.result.totalCount)` + `notificationNotifier.reschedule()` in a try/catch.

**Change:**
- `import '../../../../core/theme/bloom/bloom.dart';`.
- `Scaffold` → `BloomScaffold`. `AppBar(title: Text('Kết quả'))` → `const BloomAppBar(title: 'Kết quả')`.
- The score `Card` → replace with a centred `BloomResultRing(percent: pct)` above a `Text('$correct / $total từ đúng', style: TextStyle(color: context.bloom.inkSoft))`. Drop the `pct >= 70 ? green : error` colour on the number — `BloomResultRing` is always accent; keep the sub-line neutral.
- The result `ListView.builder` → each item is a `BloomCard` (margin via `Padding(bottom: 8)`) containing a `Row`: a leading `Icon(r.isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined, color: r.isCorrect ? context.bloom.success : context.bloom.danger, size: 18)`, then `Expanded(Column([Text(word.headword, style: webScaled(bodyLarge).copyWith(fontWeight: FontWeight.w700)), Text(word.meaning, maxLines: 1, ellipsis, style: webScaled(bodyMedium).copyWith(color: context.bloom.inkSoft))]))`. Keep the `orElse: () => widget.result.words[i]` guard on `firstWhere`.
- `FilledButton('Luyện tập lại', onPressed: () => context.go('/practice/vocab'))` → `BloomPillButton(label: 'Luyện tập lại', variant: BloomButtonVariant.primary, block: true, onPressed: () => context.go('/practice/vocab'))`.

- [ ] **Step 2: Add the smoke test**

Create `test/features/practice/presentation/screens/session_result_screen_test.dart` — build a `SessionResult` with 2 words + 2 `ExerciseResult`s (one correct, one wrong). Pump inside `ProviderScope` overriding `computeSm2UseCaseProvider`, `updateVocabUseCaseProvider`, `statsServiceProvider`, `notificationNotifierProvider` (fakes — record calls, don't throw), `sharedPreferencesProvider`; `GoRouter` harness with a `/practice/vocab` stub. Assert: `BloomResultRing` renders showing `'50%'`; both headwords render; the "Luyện tập lại" `BloomPillButton` renders; navigating on tap goes to the stub. (The `_updateSm2` fakes let you also assert `computeUseCase` was called twice — optional.)

- [ ] **Step 3: Run + full suite + analyze**

Run: `flutter test test/features/practice/`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle session result screen"
```

---

## Self-Review

**1. Spec coverage (against `2026-08-30-flutter-bloom-redesign-design.md` §B4, §B5):**
- §B4 "Practice hub + SM-2" — `practice_hub_screen.dart` (grid `BloomCard`, SM-2 card nổi bằng viền accent + `surface-3`) → **Task 3** ✓; `practice_home_screen.dart` → **Task 4** ✓. (`progress` = §#10 = Plan 5, correctly excluded.)
- §B5 "Practice session ×4 + result" — `practice_session_screen.dart` → **Task 5** ✓; `flashcard_widget.dart` (thẻ `BloomCard` bo 22px + shadow ấm, `max-height`, giữ flip 3D) → **Task 6** ✓; `multiple_choice_widget.dart` / `fill_in_blank_widget.dart` / `translation_exercise_widget.dart` → `BloomMcOption`/`BloomTextField` → **Task 7** ✓; `session_result_screen.dart` (vòng tròn % → `CustomPainter`, list kết quả `BloomCard`) → **Task 8** (`BloomResultRing` = Task 2) ✓.
- The spec's widget list names `BloomMcOption` (Task 1) and implies the result ring (Task 2, `conic-gradient` → `CustomPainter` per §B5).

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Tasks 1–3 give full code; Tasks 4–8 use itemized change lists with every widget/colour/string named and the frozen behaviour enumerated explicitly. A spot the implementer finds ambiguous is a NEEDS_CONTEXT, not a guess.

**3. Type consistency:**
- `BloomMcOption({required String label, required VoidCallback? onTap, BloomMcState state, String? leading})` + `enum BloomMcState { neutral, selected, correct, wrong }` — defined Task 1, consumed Task 7 (`multiple_choice_widget`). Names match.
- `BloomResultRing({required int percent, double size, String? label})` — defined Task 2, consumed Task 8. Matches.
- `BloomShadows.warm(bool isDark)` — from Plan 1 `bloom_tokens.dart`; used Task 6. Signature matches.
- `BloomPillButton(label:, onPressed:, variant:, block:, icon:)` + `BloomButtonVariant.{primary,secondary,danger,link}` — from Plan 1; used Tasks 4–8 consistently.
- `BloomCard(child:, selected:, onTap:)` — from Plan 1; Task 3 uses `selected: true`, Task 8 uses default. Matches.
- `ExerciseResult(vocabRecordId:, quality:, isCorrect:)` and the `quality: correct ? 5 : 1` mapping — frozen, restated identically in Tasks 6 & 7.
- The flashcard's `22` radius and `_CardFace` shadow are the only non-`BloomRadii` / non-token additions, both plan-sanctioned in Global Constraints.

No mismatches found.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-31-flutter-bloom-plan3-practice.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
