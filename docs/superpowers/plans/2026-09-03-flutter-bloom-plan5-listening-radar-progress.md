# Flutter Bloom — Plan 5: Listening + Word Radar + Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Listening area (Luyện nghe hub, Nghe chép setup → session → result, Nghe hiểu setup → session → result), the Quét từ vựng (Word Radar) screen and its two suggestion sections, and the Tiến độ học (Progress) dashboard to the Bloom design system — and add the four shared Bloom widgets this area needs (`BloomStatCard`, `BloomBarChart`, `BloomAudioControls`, `BloomWordSeekBar`).

**Architecture:** Four new widgets land first in `lib/core/theme/bloom/` (no dependency on the screens). Then screen-by-screen restyle, grouped so each task ends on an independently testable deliverable. **Every provider, notifier, use-case, entity, and route is frozen** — only the presentation layer (`presentation/screens/*`, `presentation/widgets/*` under `word_radar`) and the new widgets change. All these screens are already Vietnamese. The Progress screen has **no widget test today** — its task creates one from scratch.

**Tech Stack:** Flutter 3.41 / Dart ≥3.4, `flutter_riverpod` (untouched providers), `go_router` (untouched), `flutter_test`. Bloom design system from Plans 1–4 (`lib/core/theme/bloom/`).

## Global Constraints

- **Bloom widgets** come from `import 'package:lexi_core/core/theme/bloom/bloom.dart';` — the barrel already exports `BloomScaffold`, `BloomAppBar` + `BloomIconButton`, `BloomCard`, `BloomPillButton` (+`BloomButtonVariant.{primary,secondary,sage,danger,link}`), `BloomChip` (+`BloomChipStyle.{neutral,active,topic,clear}`) + `BloomCefrPill`, `BloomProgressBar`, `BloomSectionHeader` + `BloomLeafMark` (in `bloom_labels.dart`), `BloomListRow`, `BloomTextField`, `BloomMcOption` (+`BloomMcState.{neutral,selected,correct,wrong}`), `BloomResultRing`, `BloomExpansionTile`, `BloomGroupChips`. This plan adds `BloomStatCard`, `BloomBarChart`, `BloomAudioControls`, `BloomWordSeekBar` (Tasks 1–4).
- **`FilterTile`** is `import 'package:lexi_core/core/widgets/filter_tile.dart';` — `const FilterTile({required IconData icon, required String label, required String value, required VoidCallback onTap})`. Bloom-styled since Plan 1, NOT in the barrel. `showSingleSelectSheet` / `showMultiSelectSheet` / `SelectOption` from `import 'package:lexi_core/core/widgets/selection_sheets.dart';` — Bloom-styled since Plan 1, keep using them as-is.
- **`AiDisabledCard`** is `import 'package:lexi_core/core/widgets/ai_disabled_card.dart';` — `const AiDisabledCard({required String message})`. **Already Bloom-styled** (dangerBg fill, danger border, `BloomRadii.md`, `BloomSpacing.lg` padding). Do not touch it. Every home screen keeps its existing `if (!settings.aiEnabled)` gate and its current message strings. **`aiEnabled` stays** for this plan. The rename to `AiKeyMissingCard` + the `settings.aiEnabled` → `settings.aiAvailable` switch (spec §C2) is **Plan 6** — not here. `word_radar_provider.dart` / `result_suggestions_section.dart` keep reading `aiEnabled` unchanged (they are not restyled — providers are frozen — and `result_suggestions_section.dart`'s `_load()` gate stays as-is).
- **Colors** via `context.bloom` (a `BloomColors`; falls back to `BloomColors.light` in the themeless test harnesses these features use — every listening/word_radar/progress test builds a raw `MaterialApp` with no `AppTheme`). Never a raw `Colors.*` or `Color(0x...)` in new/edited code. Map the existing hardcoded semantics:
  - `Colors.green*` / `Icons.check_circle` (correct) → `context.bloom.success`
  - `Colors.red*` / `theme.colorScheme.error` / `Icons.cancel` (wrong) → `context.bloom.danger`
  - the learned-word / vocab highlight → `context.bloom.sage` text on a `context.bloom.sageBg` ground
  - `theme.colorScheme.primary` / `primaryContainer` (streak banner, accents) → `context.bloom.accent` / a `context.bloom.surface3` or `sageBg` ground
  - the Word Radar amber AI hint (`.word-radar-ai-hint`: `amber-bg` ground, `amber` text, weight 600) → `context.bloom.amberBg` + `context.bloom.amber`
- **Radii:** only `BloomRadii.sm=10 / md=16 / lg=20 / pill=999`. No new literal radii.
- **Spacing:** `BloomSpacing.xs=4 / sm=8 / md=12 / lg=16 / xl=22 / xxl=32` where you'd otherwise hardcode; an existing literal `EdgeInsets.all(16)` / `.all(24)` page padding may stay.
- **`SegmentedButton<double>` speed selector stays raw Material.** `_SpeedSelector` in `dictation_session_screen.dart` and `comprehension_session_screen.dart` wraps a `SegmentedButton<double>` over `{0.75, 1.0, 1.25}`. Tests do `tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))`. `AppTheme` maps its `ColorScheme` onto Bloom tokens so it is not off-tone. Restyling it needs `BloomSegmented` which is **Plan 6** (spec §D theme picker). Leave `_SpeedSelector` exactly as-is (same precedent as Plan 4 keeping raw `LinearProgressIndicator` in loading branches). Do not change its tests.
- **`_SeekSlider` keeps its drag-preview `State`.** Both session screens have a private `_SeekSlider` `StatefulWidget` holding a local "preview index while dragging" value and calling `onSeek` on release. Keep that state machine; only swap the raw `Slider` it renders for `BloomWordSeekBar` (Task 4). `find.byType(Slider)` still resolves (BloomWordSeekBar contains one).
- **`BloomProgressBar({required double value, double height = 6})`** has **no indeterminate mode**. Leave any raw `LinearProgressIndicator()` / `CircularProgressIndicator()` that today has no `value:` (the `loading:` branches, the inline button spinner) exactly as raw Material — Plan 3/4 set that precedent. Only swap a `LinearProgressIndicator(value: x)` (the CEFR rows in Progress) for `BloomProgressBar(value: x)`.
- **No deprecated APIs that add `flutter analyze` issues.** This Flutter deprecates `withOpacity` → `.withValues(alpha:)`. The repo has **12 pre-existing** `flutter analyze` infos, all `RadioListTile`/`Radio` `groupValue`/`onChanged` deprecations: `lib/core/widgets/selection_sheets.dart:79,82`; `lib/features/listening/presentation/screens/comprehension_session_screen.dart:185,191`; `lib/features/settings/presentation/screens/settings_screen.dart:188,189,199,200,267,268,273,274`. Task 10 replaces comprehension's `RadioListTile<int>` with `BloomMcOption`, which **removes** infos `:185,191` — the count drops to **10**. That is allowed (the count may drop); it must **never rise above 12**, and no new lint of any kind may appear. Record the new number in that task's commit body.
- **Tests:** the suite is at **721 passing** at the start of this plan (`flutter test`). It only goes up (Task 12 adds a new Progress test file → the total rises). When a widget swap breaks a finder, fix the finder — prefer `find.text` / `find.byKey` / `find.byType(BloomX)` / `find.widgetWithText(BloomX, ...)`. **Never weaken or delete a behavior assertion.** `find.byIcon(Icons.check_circle)` / `find.byIcon(Icons.cancel)` in the two result-screen tests and the two word_radar suggestion tests are load-bearing — keep those exact icons in the Bloom versions (colour them `context.bloom.success` / `context.bloom.danger`, don't swap the `IconData`).
- **Behavior is frozen.** No change to: `DictationPracticeNotifier` (`generate` / `play` / `seekTo` / `setSpeed` / `updateTypedText` / `updateBlankAnswer` / `submit` / `reset`), `ListeningComprehensionNotifier` (`generate` / `playCurrentTurn` / `seekToWord` / `setSpeed` / `stopPlayback` / `previousTurn` / `nextTurn` / `replayFromStart` / `selectAnswer` / `submit` / `reset`), `WordRadarNotifier`, any use-case, source, or entity, the `TtsService` interface, every `*ResultScreen`'s `initState` post-frame (`_updateSm2()` / `_recordPracticeSession()` → `statsServiceProvider.recordPracticeSession(...)`), the `ref.listen(...)` → `WidgetsBinding.addPostFrameCallback` → `context.go(...result, extra:)` navigation in both session screens, the "session null → post-frame `context.go(<home>)`" redirect in both session screens, and the `redirect` guards in `app_router.dart`. Restyle is view-only. Any UI-local state a redesign needs lives in the **screen's own `State`**, never in a provider.
- **`webScaled(...)`** (`lib/core/utils/web_text_scale.dart`) wrapping stays exactly where the current code has it — on question text, option text, transcript/passage text, typed-area text. No-op on mobile, out of scope to add or remove. `BloomMcOption` already `webScaled`s its own label — do **not** double-wrap text passed to it.
- **Nested-route back handling (Plan 3/4 pattern).** go_router builds a page per segment, so on the deep listening routes `Navigator.canPop()` is true and a `BloomAppBar` would imply a back arrow. On **every session and result screen** pass `automaticallyImplyLeading: false` on the `BloomAppBar` AND wrap the scaffold in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go(<parent>); })`. Parents: Nghe chép session + result → `/listening/dictation`; Nghe hiểu session + result → `/listening/comprehension`. **Home screens** (`dictation_home`, `comprehension_home`) currently have `automaticallyImplyLeading: false` and no back affordance — keep that (parent hub is beneath); use `BloomAppBar(..., automaticallyImplyLeading: false)`, no leading, no `PopScope`. The **Luyện nghe hub** and **Word Radar** and **Progress** screens keep their explicit back: `BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice'))` as the `BloomAppBar.leading` (Progress currently relies on the auto back button → give it an explicit `BloomIconButton` to `/practice`).
- **C1 is already satisfied.** `comprehension_home_screen.dart:32` already hard-codes `_context = AppContext.general` (Plan 2 removed `activeContext` from `UserSettingsState`). No context work in this plan. Do not add a per-session context picker.
- **`apps/web/` is never touched.** Package is `lexi_core`. The web Listening/Dashboard pages have diverged (continuous speed slider, "Lưu bài", English-only) — they are a **visual** reference for Bloom tokens/proportions only, never a behavior reference. Flutter's frozen behavior wins.
- **Spec:** `docs/superpowers/specs/2026-08-30-flutter-bloom-redesign-design.md` — §Phần B items 10–13, §A3 (widget-table rows `BloomStatCard`, `BloomBarChart`, `BloomAudioControls`, `BloomWordSeekBar`), §Testing.

---

## File Structure

**Created:**
- `lib/core/theme/bloom/bloom_stat_card.dart` — `BloomStatCard`
- `lib/core/theme/bloom/bloom_bar_chart.dart` — `BloomBarChart`
- `lib/core/theme/bloom/bloom_audio_controls.dart` — `BloomAudioControls`
- `lib/core/theme/bloom/bloom_word_seek_bar.dart` — `BloomWordSeekBar`
- `test/core/theme/bloom/bloom_stat_card_test.dart`
- `test/core/theme/bloom/bloom_bar_chart_test.dart`
- `test/core/theme/bloom/bloom_audio_controls_test.dart`
- `test/core/theme/bloom/bloom_word_seek_bar_test.dart`
- `test/features/practice/presentation/screens/progress_screen_test.dart` (new — Task 12)

**Modified:**
- `lib/core/theme/bloom/bloom.dart` — add the 4 exports
- `lib/features/listening/presentation/screens/listening_home_screen.dart` (Task 5)
- `lib/features/listening/presentation/screens/dictation_home_screen.dart` (Task 6)
- `lib/features/listening/presentation/screens/dictation_session_screen.dart` (Task 7)
- `lib/features/listening/presentation/screens/dictation_result_screen.dart` (Task 8)
- `lib/features/listening/presentation/screens/comprehension_home_screen.dart` (Task 9)
- `lib/features/listening/presentation/screens/comprehension_session_screen.dart` (Task 10)
- `lib/features/listening/presentation/screens/comprehension_result_screen.dart` (Task 11)
- `lib/features/practice/presentation/screens/progress_screen.dart` (Task 12)
- `lib/features/word_radar/presentation/screens/word_radar_screen.dart` (Task 13)
- `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart` (Task 14)
- `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart` (Task 14)
- The matching `test/features/**/*_test.dart` for every screen above — finder swaps only (except Progress, new).

**Not in this plan:** Settings, Sign-in (Plan 6); `aiEnabled` removal + `AiKeyMissingCard` rename + `BloomSegmented`/`BloomSwitch` (Plan 6); `README.md` / `CLAUDE.md` doc updates (Plan 6 §E); anything under `data/` or `domain/`; the Reading area (Plan 4, done).

---

## Task 1: BloomStatCard

**Files:**
- Create: `lib/core/theme/bloom/bloom_stat_card.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_stat_card_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomStatCard extends StatelessWidget {
    const BloomStatCard({
      super.key,
      required this.label,     // small uppercase, e.g. "HÔM NAY"
      required this.value,     // big tabular, e.g. "12"
      this.foot,               // optional sub-line, e.g. "từ đến hạn ôn tập"
    });
    final String label;
    final String value;
    final String? foot;
  }
  ```
  A `surface` card (`border` 1px, `BloomRadii.md`, `EdgeInsets.all(BloomSpacing.lg)`) — `Column(crossAxisAlignment: start, [Text(label.toUpperCase(), 12.5 · w700 · letterSpacing 0.4 · inkFaint), SizedBox(height: 6), Text(value, 26 · w800 · ink · fontFeatures:[FontFeature.tabularFigures()]), if (foot != null) …[SizedBox(height: 4), Text(foot!, 12.5 · inkSoft)]])`. Ports `.dash-stat-card` + `.reading-stat-card`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_stat_card.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders the label uppercased, the value, and the foot', (tester) async {
    await tester.pumpWidget(_host(const BloomStatCard(
      label: 'Hôm nay', value: '12', foot: 'từ đến hạn ôn tập',
    )));
    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('từ đến hạn ôn tập'), findsOneWidget);
  });

  testWidgets('foot is omitted when null', (tester) async {
    await tester.pumpWidget(_host(const BloomStatCard(label: 'Đã thuộc', value: '5')));
    expect(find.text('ĐÃ THUỘC'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    // only 2 Text descendants (label + value)
    expect(find.descendant(of: find.byType(BloomStatCard), matching: find.byType(Text)), findsNWidgets(2));
  });

  testWidgets('value uses ink, label uses inkFaint', (tester) async {
    await tester.pumpWidget(_host(const BloomStatCard(label: 'L', value: 'V')));
    expect(tester.widget<Text>(find.text('V')).style!.color, BloomColors.light.ink);
    expect(tester.widget<Text>(find.text('L')).style!.color, BloomColors.light.inkFaint);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_stat_card_test.dart`
Expected: FAIL — `bloom_stat_card.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A labelled statistic: a small uppercase [label], a large tabular [value],
/// and an optional [foot] sub-line. Used on the Progress dashboard and the
/// dictation result screen. Ports web's `.dash-stat-card` / `.reading-stat-card`.
class BloomStatCard extends StatelessWidget {
  const BloomStatCard({
    super.key,
    required this.label,
    required this.value,
    this.foot,
  });

  final String label;
  final String value;
  final String? foot;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      padding: const EdgeInsets.all(BloomSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: c.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (foot != null) ...[
            const SizedBox(height: 4),
            Text(foot!, style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
          ],
        ],
      ),
    );
  }
}
```

Add to `lib/core/theme/bloom/bloom.dart`, alphabetically (after `bloom_scaffold.dart`? — no: alpha order is `bloom_bar_chart`, `bloom_audio_controls` … actually alphabetical: `audio` < `bar` < `stat` < `word`. Insert `bloom_audio_controls`, `bloom_bar_chart` near the top, `bloom_stat_card` after `bloom_scaffold`, `bloom_word_seek_bar` last). For this task add just:
```dart
export 'bloom_stat_card.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_stat_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_stat_card.dart test/core/theme/bloom/bloom_stat_card_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_stat_card.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_stat_card_test.dart
git commit -m "feat(bloom): BloomStatCard labelled-statistic tile

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: BloomBarChart

**Files:**
- Create: `lib/core/theme/bloom/bloom_bar_chart.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_bar_chart_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomBarChartBar {
    const BloomBarChartBar({required this.label, required this.value, this.highlight = false});
    final String label;   // e.g. "T2"
    final int value;      // words practiced that day
    final bool highlight; // the "today" column
  }

  class BloomBarChart extends StatelessWidget {
    const BloomBarChart({super.key, required this.bars, this.height = 120});
    final List<BloomBarChartBar> bars;
    final double height;
  }
  ```
  A `Row(crossAxisAlignment: end)` of equal-flex columns; overall box `height`. Each column: `Expanded(child: Column([Expanded(child: Align(alignment: bottomCenter, child: FractionallySizedBox(heightFactor: barFraction, widthFactor: 0.55, child: DecoratedBox(color: bar.highlight ? c.accent : c.surface3, borderRadius: vertical top BloomRadii.sm)))), SizedBox(height: 6), Text(bar.label, 11.5 · w600 · (bar.highlight ? c.accent : c.inkFaint))]))`. `barFraction = maxValue == 0 ? 0.04 : (bar.value == 0 ? 0.04 : max(0.10, bar.value / maxValue))` where `maxValue = bars.map((b) => b.value).fold(0, max)`. Render the per-bar value only when `bar.value > 0` — a tiny `Text('${bar.value}', 10.5 · w700 · inkSoft)` sitting above the bar (a `Column` child before the `Expanded` bar area, or a `Stack`; simplest: put `Text` above the bar inside the inner `Column` so tall bars don't overflow — a small `SizedBox(height: 14)` slot always present, holding the number or empty). Port `.dash-chart` / `.dash-chart-bar` / `.dash-chart-value` / `.dash-chart-day`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_bar_chart.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

const _bars = [
  BloomBarChartBar(label: 'T2', value: 0),
  BloomBarChartBar(label: 'T3', value: 4),
  BloomBarChartBar(label: 'T4', value: 10),
  BloomBarChartBar(label: 'T5', value: 2),
  BloomBarChartBar(label: 'T6', value: 0),
  BloomBarChartBar(label: 'T7', value: 6),
  BloomBarChartBar(label: 'CN', value: 3, highlight: true),
];

void main() {
  testWidgets('renders every day label', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    for (final l in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('shows the value above each non-zero bar, hides it for zero', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    expect(find.text('10'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // '0' days show no number
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the highlighted day label is drawn in accent', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    expect(tester.widget<Text>(find.text('CN')).style!.color, BloomColors.light.accent);
    expect(tester.widget<Text>(find.text('T2')).style!.color, BloomColors.light.inkFaint);
  });

  testWidgets('renders with an all-zero week without throwing', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: [
      BloomBarChartBar(label: 'T2', value: 0),
      BloomBarChartBar(label: 'T3', value: 0),
    ])));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_bar_chart_test.dart`
Expected: FAIL — `BloomBarChart` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// One column of a [BloomBarChart].
class BloomBarChartBar {
  const BloomBarChartBar({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final int value;
  final bool highlight;
}

/// A compact 7-ish-column activity chart — the "today" column tinted accent,
/// each non-zero bar captioned with its count. Ports web's `.dash-chart`.
class BloomBarChart extends StatelessWidget {
  const BloomBarChart({super.key, required this.bars, this.height = 120});

  final List<BloomBarChartBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final maxValue = bars.fold<int>(0, (m, b) => math.max(m, b.value));

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 14,
                    child: bar.value > 0
                        ? Text('${bar.value}',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: c.inkSoft))
                        : null,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: _fraction(bar.value, maxValue),
                        widthFactor: 0.55,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bar.highlight ? c.accent : c.surface3,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(BloomRadii.sm)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bar.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: bar.highlight ? c.accent : c.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _fraction(int value, int maxValue) {
    if (maxValue == 0 || value == 0) return 0.04;
    return math.max(0.10, value / maxValue);
  }
}
```

Add `export 'bloom_bar_chart.dart';` to `bloom.dart` (alphabetical).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_bar_chart_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_bar_chart.dart test/core/theme/bloom/bloom_bar_chart_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_bar_chart.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_bar_chart_test.dart
git commit -m "feat(bloom): BloomBarChart weekly-activity chart

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: BloomAudioControls

**Files:**
- Create: `lib/core/theme/bloom/bloom_audio_controls.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_audio_controls_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`, `BloomIconButton` (from `bloom_app_bar.dart`).
- Produces two named constructors on one widget:
  ```dart
  class BloomAudioControls extends StatelessWidget {
    /// Dictation: a single big Play / Nghe lại pill.
    const BloomAudioControls.playOnly({
      super.key,
      required this.isPlaying,
      required this.onPlayPause,   // nullable → disabled
      required this.playLabel,     // 'Phát' / 'Nghe lại (2)'
    })  : onPrevious = null, onNext = null, onReplay = null, _transport = false;

    /// Comprehension: ⏮  ▶/⏹  ⏭  ↺
    const BloomAudioControls.transport({
      super.key,
      required this.isPlaying,
      required this.onPlayPause,
      required this.onPrevious,    // nullable → shown but disabled (at first turn)
      required this.onNext,        // nullable → shown but disabled (at last turn)
      required this.onReplay,
      this.playLabel = 'Phát',
    }) : _transport = true;

    final bool isPlaying;
    final VoidCallback? onPlayPause;
    final VoidCallback? onPrevious;
    final VoidCallback? onNext;
    final VoidCallback? onReplay;
    final String playLabel;
    final bool _transport;
  }
  ```
  Layout: a centered `Row(mainAxisAlignment: center)` with `BloomSpacing.md` gaps.
  - `.transport`: `[BloomIconButton(icon: Icons.skip_previous, onPressed: onPrevious), _playPill(context), BloomIconButton(icon: Icons.skip_next, onPressed: onNext), BloomIconButton(icon: Icons.replay, onPressed: onReplay)]`.
  - `.playOnly`: just `_playPill(context)`.
  - `_playPill`: a pill (`BloomRadii.pill`, `c.accent` ground, `c.accentInk` content, `EdgeInsets.symmetric(horizontal: BloomSpacing.xl, vertical: BloomSpacing.md)`, `opacity 0.5` when `onPlayPause == null`) wrapping `Material(transparent) > InkWell(onTap: onPlayPause) > Row([Icon(isPlaying ? Icons.stop : Icons.play_arrow, size: 20), SizedBox(width: 8), Text(isPlaying ? 'Dừng' : playLabel, w700 15)])`. Use the Bloom interactive pattern (`Container(decoration:) > Material(color: transparent) > InkWell`) so the ripple shows above a `BloomScaffold` gradient.
  Show `isPlaying ? 'Dừng' : playLabel` — dictation passes `playLabel` = `'Phát'`/`'Nghe lại (N)'`; when the dictation button is pressed while speaking there is no separate stop path so `isPlaying` briefly true just shows 'Dừng', which is fine.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_audio_controls.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('playOnly: shows the play label and fires onPlayPause', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(BloomAudioControls.playOnly(
      isPlaying: false, playLabel: 'Phát', onPlayPause: () => taps++,
    )));
    expect(find.text('Phát'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous), findsNothing);
    await tester.tap(find.text('Phát'));
    expect(taps, 1);
  });

  testWidgets('playOnly: null onPlayPause disables it (no tap fires)', (tester) async {
    await tester.pumpWidget(_host(const BloomAudioControls.playOnly(
      isPlaying: false, playLabel: 'Phát', onPlayPause: null,
    )));
    await tester.tap(find.text('Phát'), warnIfMissed: false);
    // nothing to assert beyond "did not throw"; also the pill is at 0.5 opacity
    expect(tester.takeException(), isNull);
  });

  testWidgets('playOnly: isPlaying swaps the label to Dừng and the icon to stop', (tester) async {
    await tester.pumpWidget(_host(BloomAudioControls.playOnly(
      isPlaying: true, playLabel: 'Nghe lại (1)', onPlayPause: () {},
    )));
    expect(find.text('Dừng'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);
  });

  testWidgets('transport: renders all four controls and wires each callback', (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(_host(BloomAudioControls.transport(
      isPlaying: false,
      onPlayPause: () => hits.add('play'),
      onPrevious: () => hits.add('prev'),
      onNext: () => hits.add('next'),
      onReplay: () => hits.add('replay'),
    )));
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.byIcon(Icons.replay), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.replay));
    await tester.tap(find.text('Phát'));
    expect(hits, ['prev', 'next', 'replay', 'play']);
  });

  testWidgets('transport: null onPrevious renders the button disabled', (tester) async {
    await tester.pumpWidget(_host(BloomAudioControls.transport(
      isPlaying: false, onPlayPause: () {},
      onPrevious: null, onNext: () {}, onReplay: () {},
    )));
    expect(find.byIcon(Icons.skip_previous), findsOneWidget);
    // BloomIconButton with onPressed: null — tapping does nothing / no throw
    await tester.tap(find.byIcon(Icons.skip_previous), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_audio_controls_test.dart`
Expected: FAIL — `BloomAudioControls` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import 'bloom_app_bar.dart'; // BloomIconButton

/// The audio transport for the listening session screens. [BloomAudioControls.playOnly]
/// is the single Play/Nghe-lại pill (Nghe chép); [BloomAudioControls.transport] adds
/// ⏮ ⏭ ↺ around it (Nghe hiểu). Ports web's `.dictation-controls`.
class BloomAudioControls extends StatelessWidget {
  const BloomAudioControls.playOnly({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.playLabel,
  })  : onPrevious = null,
        onNext = null,
        onReplay = null,
        _transport = false;

  const BloomAudioControls.transport({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    this.playLabel = 'Phát',
  }) : _transport = true;

  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReplay;
  final String playLabel;
  final bool _transport;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_transport) ...[
          BloomIconButton(
              icon: Icons.skip_previous,
              onPressed: onPrevious,
              tooltip: 'Lượt trước'),
          const SizedBox(width: BloomSpacing.md),
        ],
        _PlayPill(
            isPlaying: isPlaying, label: playLabel, onTap: onPlayPause),
        if (_transport) ...[
          const SizedBox(width: BloomSpacing.md),
          BloomIconButton(
              icon: Icons.skip_next,
              onPressed: onNext,
              tooltip: 'Lượt sau'),
          const SizedBox(width: BloomSpacing.md),
          BloomIconButton(
              icon: Icons.replay,
              onPressed: onReplay,
              tooltip: 'Nghe lại từ đầu'),
        ],
      ],
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.isPlaying, required this.label, required this.onTap});
  final bool isPlaying;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(BloomRadii.pill),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BloomSpacing.xl, vertical: BloomSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                      size: 20, color: c.accentInk),
                  const SizedBox(width: 8),
                  Text(isPlaying ? 'Dừng' : label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.accentInk)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Add `export 'bloom_audio_controls.dart';` to `bloom.dart` (alphabetical — near the top).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_audio_controls_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyzer**

Run: `flutter analyze lib/core/theme/bloom/bloom_audio_controls.dart test/core/theme/bloom/bloom_audio_controls_test.dart`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_audio_controls.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_audio_controls_test.dart
git commit -m "feat(bloom): BloomAudioControls transport for listening sessions

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: BloomWordSeekBar

**Files:**
- Create: `lib/core/theme/bloom/bloom_word_seek_bar.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`
- Test: `test/core/theme/bloom/bloom_word_seek_bar_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomWordSeekBar extends StatelessWidget {
    const BloomWordSeekBar({
      super.key,
      required this.value,        // current word index, as double
      required this.max,          // (word count - 1), as double; must be > 0
      required this.onChanged,    // drag preview
      this.onChangeStart,
      this.onChangeEnd,           // commit: seek to value.round()
      this.label,                 // e.g. "Tua theo từ" or "Lượt 2/4"
      this.enabled = true,
    });
    final double value;
    final double max;
    final ValueChanged<double> onChanged;
    final ValueChanged<double>? onChangeStart;
    final ValueChanged<double>? onChangeEnd;
    final String? label;
    final bool enabled;
  }
  ```
  `Column(crossAxisAlignment: stretch, [ if (label != null) Padding(bottom: BloomSpacing.xs, Text(label!, 12.5 · inkSoft)), SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: c.accent, inactiveTrackColor: c.surface3, thumbColor: c.accent, overlayColor: c.accent.withValues(alpha: 0.12), trackHeight: 4), child: Slider(value: value.clamp(0, max), max: max, divisions: max.round().clamp(1, 1<<20), onChanged: enabled ? onChanged : null, onChangeStart: onChangeStart, onChangeEnd: onChangeEnd)) ])`. The wrapper is purely visual — the caller (`_SeekSlider` in each session screen) still owns the drag-preview state.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_word_seek_bar.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders a Slider with the given value and max, plus the label', (tester) async {
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 2, max: 5, label: 'Tua theo từ', onChanged: (_) {},
    )));
    expect(find.text('Tua theo từ'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 2);
    expect(slider.max, 5);
  });

  testWidgets('enabled: false gives the Slider a null onChanged', (tester) async {
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 0, max: 3, enabled: false, onChanged: (_) {},
    )));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('dragging reports onChanged and onChangeEnd', (tester) async {
    double? changed;
    double? ended;
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 0, max: 4,
      onChanged: (v) => changed = v,
      onChangeEnd: (v) => ended = v,
    )));
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    expect(changed, isNotNull);
    expect(ended, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_word_seek_bar_test.dart`
Expected: FAIL — `BloomWordSeekBar` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A thin Bloom skin over [Slider] for word-level audio seeking in the listening
/// sessions. Visual only — the drag-preview state stays with the caller.
class BloomWordSeekBar extends StatelessWidget {
  const BloomWordSeekBar({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.enabled = true,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: BloomSpacing.xs, left: BloomSpacing.sm),
            child: Text(label!, style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.accent,
            inactiveTrackColor: c.surface3,
            thumbColor: c.accent,
            overlayColor: c.accent.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            divisions: max.round().clamp(1, 1 << 20),
            onChanged: enabled ? onChanged : null,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
```

Add `export 'bloom_word_seek_bar.dart';` to `bloom.dart` (alphabetical — last).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_word_seek_bar_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Analyzer + full bloom suite**

Run: `flutter analyze lib/core/theme/bloom/ test/core/theme/bloom/`
Run: `flutter test test/core/theme/bloom/`
Expected: No issues; all bloom widget tests green.

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_word_seek_bar.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_word_seek_bar_test.dart
git commit -m "feat(bloom): BloomWordSeekBar slider skin for listening seek

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Shared restyle recipe (Tasks 5, 6, 9 — the three home/hub screens)

Each of these screens today is `Scaffold` + `AppBar` + a scrolling body of `Card`/`ListTile`/`FilterTile`/`AiDisabledCard`/`FilledButton`. Apply, per screen:

1. `Scaffold` → `BloomScaffold`. `AppBar(title: Text(T))` → `BloomAppBar(title: T, ...)`:
   - **Luyện nghe hub** (Task 5): `leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice'))`.
   - **dictation_home / comprehension_home** (Tasks 6, 9): `automaticallyImplyLeading: false`, no leading (unchanged from today).
2. Body stays a `SingleChildScrollView` / `ListView` with `padding: const EdgeInsets.all(16)`.
3. Intro paragraph `Text` → `style: TextStyle(fontSize: 14, color: context.bloom.inkSoft)`.
4. `FilterTile`s stay verbatim (already Bloom).
5. `AiDisabledCard(message: ...)` stays verbatim (already Bloom) behind the unchanged `if (!settings.aiEnabled)` gate.
6. `FilledButton`/`FilledButton.icon` "Tạo bài luyện" → `BloomPillButton(label: 'Tạo bài luyện', icon: Icons.auto_awesome, variant: BloomButtonVariant.primary, block: true, onPressed: <existing callback>)`.
7. `OutlinedButton` "Thử lại" → `BloomPillButton(label: 'Thử lại', variant: BloomButtonVariant.secondary, onPressed: <existing callback>)`.
8. error `Text` → `style: TextStyle(color: context.bloom.danger)`.
9. Raw `LinearProgressIndicator()` / `CircularProgressIndicator()` in `loading:` branches — **leave as raw Material** (no `value:` → `BloomProgressBar` can't express it).
10. `Card` + `ListTile` navigation rows (hub only) → `BloomCard(onTap: ..., child: Row([<icon in a sageBg rounded square>, SizedBox(width: 14), Expanded(Column([Text(title, w700 15 ink), Text(subtitle, 12.5 inkSoft)])), Icon(Icons.chevron_right, color: context.bloom.inkFaint)]))` — copy the `_ReadingCard` private widget from `reading_hub_screen.dart` as the pattern.

Test-finder swaps for these screens: they use `find.text(...)` almost exclusively (labels pass unchanged). Swap only `find.byType(FilledButton)` / `find.widgetWithText(FilledButton, 'Tạo bài luyện')` → `find.widgetWithText(BloomPillButton, 'Tạo bài luyện')` (or `find.byType(BloomPillButton)` when unambiguous), and `find.byType(AppBar)` → `find.byType(BloomAppBar)` if present.

---

## Task 5: Luyện nghe hub

**Files:**
- Modify: `lib/features/listening/presentation/screens/listening_home_screen.dart`
- Test: `test/features/listening/presentation/screens/listening_home_screen_test.dart`

**Interfaces:**
- `ListeningHomeScreen extends StatelessWidget`. Frozen: the two `context.go` targets `/listening/dictation` and `/listening/comprehension`, and the back target `/practice`.

- [ ] **Step 1: Rewrite the screen** with the shared recipe. `BloomAppBar(title: 'Luyện nghe', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice')))`. Body = `ListView(padding: EdgeInsets.all(16), children: [ _ListeningCard(icon: Icons.mic_none_outlined, title: 'Nghe chép', subtitle: 'Nghe câu và gõ lại — luyện chính tả và nghe chi tiết.', onTap: () => context.go('/listening/dictation')), SizedBox(height: 12), _ListeningCard(icon: Icons.headphones_outlined, title: 'Nghe hiểu', subtitle: 'Nghe hội thoại/bài nói và trả lời câu hỏi trắc nghiệm.', onTap: () => context.go('/listening/comprehension')) ])`. Keep whatever exact subtitle strings the screen currently shows if they differ — read the file first and preserve the copy, only restyle the container. Add a private `_ListeningCard` widget (copy `_ReadingCard` from `reading_hub_screen.dart`).

- [ ] **Step 2: Update the test.** `listening_home_screen_test.dart` uses only `find.text('Nghe chép')` / `find.text('Nghe hiểu')` and taps them, asserting navigation to the stub routes. Those pass unchanged. The harness builds a bare `MaterialApp.router` with **no `ProviderScope`** — `BloomScaffold`/`BloomAppBar`/`BloomCard` need none, and `context.bloom` falls back to `BloomColors.light`. If any assertion is `find.byType(Card)` or `find.byType(ListTile)`, swap to `find.byType(BloomCard)` / `find.text(<title>)`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/listening_home_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 12, no new.
```bash
git add lib/features/listening/presentation/screens/listening_home_screen.dart test/features/listening/presentation/screens/listening_home_screen_test.dart
git commit -m "feat(listening): Bloom Luyện nghe hub

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: Nghe chép home screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_home_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_home_screen_test.dart`

**Interfaces:**
- `DictationHomeScreen extends ConsumerStatefulWidget`. Frozen: `initState` (`_language`/`_level` from `settings`, `_reload()`), `_reload()`, the difficulty state `_difficulty`, all `_pick*` sheets, the `context.go('/listening/dictation/session')` after `dictationPracticeNotifierProvider.notifier.generate(words:, level:, context: <existing>, targetLanguage:, difficulty:)`, `_minVocabWords` gate, the "not enough words" / "language not supported" / AI-off branches.

- [ ] **Step 1: Restyle `build()`** with the shared recipe. `BloomAppBar(title: 'Nghe chép', automaticallyImplyLeading: false)`. The four `FilterTile`s (Ngôn ngữ / Chủ đề / Cấp độ / Mức độ) stay verbatim. The three `AiDisabledCard`s stay verbatim behind their unchanged gates (`if (!settings.aiEnabled)` at what is currently line 183, plus the not-enough-words and unsupported-language branches). `FilledButton.icon` "Tạo bài luyện" → `BloomPillButton(...)`. `OutlinedButton` "Thử lại" → `BloomPillButton(secondary)`. Both `LinearProgressIndicator` (currently lines 166, 211) and the `CircularProgressIndicator` (line 194) stay raw (loading states, no determinate value).

- [ ] **Step 2: Update the test.** `dictation_home_screen_test.dart` (10 tests) uses only `find.text(...)` / `find.textContaining(...)` / taps on `find.text('Tạo bài luyện')`. All pass unchanged. Swap a `FilledButton` finder only if present (grep the file). Harness overrides `userSettingsNotifierProvider` + `vocabRepositoryProvider`; no theme — fine.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 12, no new.
```bash
git add lib/features/listening/presentation/screens/dictation_home_screen.dart test/features/listening/presentation/screens/dictation_home_screen_test.dart
git commit -m "feat(listening): Bloom Nghe chép setup screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: Nghe chép session screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomAudioControls` (`.playOnly`), `BloomWordSeekBar`, `BloomPillButton`, `context.bloom`, `webScaled`. Keeps the raw `SegmentedButton<double>` `_SpeedSelector` and the per-blank `TextField`/free `TextField` (see below).
- Frozen: the `ref.listen` → `isComplete` → post-frame `context.go('/listening/dictation/session/result', extra: DictationSessionResult(...))`, the "session null → post-frame `context.go('/listening/dictation')`" redirect, `initState` (`_ctrl = TextEditingController()`), the notifier call sites — `notifier.play`, `notifier.seekTo`, `notifier.setSpeed`, `notifier.updateTypedText`, `notifier.updateBlankAnswer`, `notifier.submit`, `session.canSubmit`, `session.isClozeMode`, `session.speedMultiplier`, `session.isSpeaking`, `session.hasPlayedOnce`, `session.replayCount`, the `_ClozeInput` blank-key scheme (`ValueKey('blank-$blankIdx')`), the `_SeekSlider` drag-preview `State`.

- [ ] **Step 1: Restyle `_SessionScaffold`**

- Wrap in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/listening/dictation'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Nghe chép', automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(24), child: <content>)))`.
- The loading/error/empty bare `Scaffold`s (`const Scaffold(body: SizedBox.shrink())`, `Scaffold(body: Center(child: CircularProgressIndicator()))`, `Scaffold(body: Center(child: Text('Lỗi: $e')))`) → `BloomScaffold(body: ...)` with the same centre content (the `CircularProgressIndicator` stays raw; wrap the error `Text` colour with `context.bloom.danger`).
- The play `FilledButton.icon` → `BloomAudioControls.playOnly(isPlaying: session.isSpeaking, onPlayPause: notifier.play, playLabel: session.hasPlayedOnce ? 'Nghe lại (${session.replayCount})' : 'Phát')`.
- The `_SpeedSelector` (raw `SegmentedButton<double>`) is unchanged — but wrap its row in nothing new; if it currently sits in a `Row` with a label, keep that. It stays raw Material.
- The `_SeekSlider`: keep the `StatefulWidget` and its `_previewIndex` state. In its `build`, replace the raw `Slider` with `BloomWordSeekBar(value: _previewIndex.toDouble(), max: (widget.totalWords - 1).toDouble(), label: 'Tua theo từ', enabled: !session.isSpeaking /* keep whatever the current enable condition is */, onChanged: (v) => setState(() => _previewIndex = v.round()), onChangeEnd: (v) => widget.onSeek(v.round()))`. If `totalWords <= 1` the current code hides the slider — keep that guard.
- The container holding the controls → a `BloomCard(child: Column([...controls..., SizedBox(height: BloomSpacing.md), seekBar]))`.
- The free-input `TextField` → keep it a `TextField` but style it: `decoration: InputDecoration(filled: true, fillColor: context.bloom.surface2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomRadii.md), borderSide: BorderSide(color: context.bloom.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(BloomRadii.md), borderSide: BorderSide(color: context.bloom.accent)))`, `style: webScaled(TextStyle(fontFamily: null, fontFeatures: const [FontFeature.tabularFigures()], fontSize: 18, color: context.bloom.ink))` — mono-ish via tabular figures + a monospace `fontFamilyFallback: const ['ui-monospace', 'SF Mono', 'Menlo', 'monospace']` (matches the spec's "ô gõ mono"; do NOT bundle a mono font). `cursorColor: context.bloom.accent`. Keep `onChanged: notifier.updateTypedText`.
- The per-blank `TextField`s inside `_ClozeInput` → same treatment (surface2 fill, border/accent-focus, mono fallback, `cursorColor` accent); keep `IntrinsicWidth` + `ValueKey('blank-$blankIdx')` + `onChanged: (v) => notifier.updateBlankAnswer(idx, v)`.
- The submit `FilledButton` → `BloomPillButton(label: 'Nộp bài', variant: BloomButtonVariant.primary, block: true, onPressed: session.canSubmit ? notifier.submit : null)`.

- [ ] **Step 2: Update the test**

`dictation_session_screen_test.dart` (17 tests). Swaps (see survey §5 line list):
- `find.byType(TextField)` (line 113, 179, 403) — still resolves (free input stays a `TextField`). Unchanged.
- `find.byKey(const ValueKey('blank-0'))` / `blank-1` (lines 214–335) — unchanged (keys preserved).
- Every `tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'))` / `tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'))` (lines 119–346, ~7 sites) → `tester.widget<BloomPillButton>(find.widgetWithText(BloomPillButton, 'Nộp bài'))` / `tester.tap(find.widgetWithText(BloomPillButton, 'Nộp bài'))`. `BloomPillButton.onPressed` is a public field — the `.onPressed` null/non-null assertions carry over.
- `find.byType(Slider)` (lines 360, 367, 380, 395, 399) — still resolves (BloomWordSeekBar wraps one `Slider`). `tester.widget<Slider>(find.byType(Slider))` still works; keep the `.value` / `.max` / `.onChanged` assertions but re-derive expected `max` if the test hard-coded it (it should already be `wordCount - 1`).
- `find.byType(SegmentedButton<double>)` (lines 419, 432) — unchanged (`_SpeedSelector` stays raw).
- Add: `expect(find.byType(BloomAudioControls), findsOneWidget);` and (for the play-label tests) assert `find.text('Phát')` / `find.textContaining('Nghe lại')` against the pill instead of any old `FilledButton` icon-label finder.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart`
Expected: PASS (17 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 12, no new.
```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart test/features/listening/presentation/screens/dictation_session_screen_test.dart
git commit -m "feat(listening): Bloom Nghe chép session (BloomAudioControls + BloomWordSeekBar + mono input)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: Nghe chép result screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_result_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_result_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomStatCard`, `BloomPillButton`, `context.bloom`, `webScaled`.
- Frozen: `initState` post-frame `_updateSm2()` (SM-2 loop + `statsServiceProvider.recordPracticeSession(widget.result.item.vocabIds.length)`), `_regenerate` (`notifier.reset()` + `context.go('/listening/dictation')`), `_goHome` (`notifier.reset()` + `context.go('/')`), all `DictationSessionResult` getters (`finalScore`, `charAccuracy`, `blockAccuracy`, `isBlankCorrect`, `targetTextFor`, `seekCount`, `seekPenaltyTotal`, `replayCount`), the `_DiffText` / `_ClozeResult` span logic.

- [ ] **Step 1: Restyle**

- `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/listening/dictation'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(24), child: ListView(...))))`.
- The stats row — currently a `Row` of private `_StatCard` (`Column` of `Text`). Replace with a `GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics, mainAxisSpacing: BloomSpacing.md, crossAxisSpacing: BloomSpacing.md, childAspectRatio: 2.4, children: [...])` OR a `Column` of two `Row`s, of four `BloomStatCard`s. **Keep the exact label + value strings** the tests assert: the "Số lần tua" card's value text must still contain e.g. `'2 (−3%)'` / `'0 (−0%)'` (survey §5 lines 372–381) — build that string exactly as the current `_StatCard` does and pass it as `BloomStatCard(label: 'Số lần tua', value: '<n> (−<pct>%)')`. Match the other three labels/values verbatim from the current code (Điểm / Nghe lại / Thời gian or whatever they currently are — read the file). Delete the private `_StatCard`.
- "Bạn đã gõ" / "Câu đúng" / "Nghĩa" section headers → `Text(..., style: TextStyle(fontWeight: FontWeight.w700, color: context.bloom.ink))`. The `_DiffText` / `_ClozeResult` bodies: correct spans → `color: context.bloom.success`; wrong spans → `color: context.bloom.danger`, `backgroundColor: context.bloom.dangerBg`; "đúng: X" hint → `color: context.bloom.inkSoft`. Wrap the diff area in a `BloomCard`.
- `FilledButton` "Câu khác" → `BloomPillButton(label: 'Câu khác', variant: primary, block: true, onPressed: () => _regenerate(...))`. `OutlinedButton` "Về trang chính" → `BloomPillButton(label: 'Về trang chính', variant: secondary, block: true, onPressed: () => _goHome(...))`.

- [ ] **Step 2: Update the test**

`dictation_result_screen_test.dart` (15 tests). Finders are text-only (survey §5): `find.textContaining('100')`, `find.text('Câu khác')`, `find.text('Về trang chính')`, `find.textContaining('Số lần tua')`, `find.textContaining('2 (−3%)')`, `find.textContaining('0 (−0%)')`, diff text, `find.text('Hello world.')`. All pass **iff** the new `BloomStatCard` values reproduce the strings exactly — verify the "Số lần tua" string. No `find.byType` of a Material type to swap. Add `expect(find.byType(BloomStatCard), findsNWidgets(4));`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/dictation_result_screen_test.dart`
Expected: PASS (15 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 12, no new.
```bash
git add lib/features/listening/presentation/screens/dictation_result_screen.dart test/features/listening/presentation/screens/dictation_result_screen_test.dart
git commit -m "feat(listening): Bloom Nghe chép result screen (BloomStatCard stats)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Nghe hiểu home screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/comprehension_home_screen.dart`
- Test: `test/features/listening/presentation/screens/comprehension_home_screen_test.dart`

**Interfaces:**
- `ComprehensionHomeScreen extends ConsumerStatefulWidget`. Frozen: `initState` (`_language`/`_level` from settings, `_context = AppContext.general` — **unchanged, already correct**), all `_pick*` sheets, `context.go('/listening/comprehension/session')` after `listeningComprehensionNotifierProvider.notifier.generate(level:, context: _context, targetLanguage:)`, the AI-off branch (`if (!settings.aiEnabled)` at line 119), the unsupported-language branch.

- [ ] **Step 1: Restyle `build()`** with the shared recipe. `BloomAppBar(title: 'Nghe hiểu', automaticallyImplyLeading: false)`. Three `FilterTile`s (Ngôn ngữ / Chủ đề / Cấp độ) verbatim. Two `AiDisabledCard`s verbatim behind the unchanged gates. `FilledButton.icon` "Tạo bài luyện" → `BloomPillButton(primary, block, icon: Icons.auto_awesome)`. `OutlinedButton` "Thử lại" → `BloomPillButton(secondary)`. `LinearProgressIndicator` (line 139) stays raw.

- [ ] **Step 2: Update the test.** `comprehension_home_screen_test.dart` (4 tests) — all `find.text` / `find.textContaining`. Pass unchanged. Swap a `FilledButton` finder only if present.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/comprehension_home_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 12, no new.
```bash
git add lib/features/listening/presentation/screens/comprehension_home_screen.dart test/features/listening/presentation/screens/comprehension_home_screen_test.dart
git commit -m "feat(listening): Bloom Nghe hiểu setup screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Nghe hiểu session screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/comprehension_session_screen.dart`
- Test: `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomAudioControls` (`.transport`), `BloomWordSeekBar`, `BloomMcOption` (+`BloomMcState`), `BloomPillButton`, `context.bloom`, `webScaled`. Keeps raw `SegmentedButton<double>` `_SpeedSelector`.
- Frozen: the `ref.listen` → `isSubmitted` → post-frame `context.go('/listening/comprehension/session/result', extra: ComprehensionSessionResult(...))`, the "session null → post-frame `context.go('/listening/comprehension')`" redirect, notifier call sites — `notifier.previousTurn`, `notifier.nextTurn`, `notifier.playCurrentTurn`, `notifier.stopPlayback`, `notifier.replayFromStart`, `notifier.seekToWord`, `notifier.setSpeed`, `notifier.selectAnswer(i, optionIndex)`, `notifier.submit`, `session.canSubmit`, `session.currentTurnIndex`, `session.isSpeaking`, `session.speedMultiplier`, `session.passage`, `session.selectedAnswers`, the `isFirstTurn`/`isLastTurn` derivations, the `_SeekSlider` drag-preview `State`.

- [ ] **Step 1: Restyle `_SessionScaffold`**

- Wrap in `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/listening/comprehension'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Nghe hiểu', automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(16), child: <content>)))`. The bare loading/error/empty `Scaffold`s (lines 41–52) → `BloomScaffold` with the same centre content (`CircularProgressIndicator` raw; error `Text` colour `context.bloom.danger`).
- The controls `Card` (line 76) → `BloomCard`. Inside it replace the **four `IconButton`s** (`skip_previous` / `play_circle`|`stop_circle` iconSize 40 / `skip_next` / `replay`) with:
  ```dart
  BloomAudioControls.transport(
    isPlaying: session.isSpeaking,
    onPlayPause: session.isSpeaking ? notifier.stopPlayback : notifier.playCurrentTurn,
    onPrevious: isFirstTurn ? null : notifier.previousTurn,
    onNext: isLastTurn ? null : notifier.nextTurn,
    onReplay: notifier.replayFromStart,
  )
  ```
- Keep `_SpeedSelector` raw. Keep its position/label.
- `_SeekSlider`: keep the `State`; render `BloomWordSeekBar(value: _previewGlobalWordIndex.toDouble(), max: (totalWordsOf(session.passage) - 1).toDouble(), label: 'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}', onChanged: (v) => setState(() => _previewGlobalWordIndex = v.round()), onChangeEnd: (v) => widget.onSeek(v.round()))` — mirror the exact preview-state field name and enable condition the current `_SeekSlider` uses.
- `_QuestionCard` (line 153): outer `Card` → `BloomCard`. Header `Text(webScaled('${index + 1}. ${question.question}'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.bloom.ink))`. Replace the **`RadioListTile<int>` per option** (lines 183–191 — the 2 analyze infos) with a `Column` of `BloomMcOption`:
  ```dart
  for (var o = 0; o < question.options.length; o++) ...[
    if (o > 0) const SizedBox(height: BloomSpacing.sm),
    BloomMcOption(
      label: question.options[o],
      leading: String.fromCharCode(65 + o), // A B C D
      onTap: () => onSelected(o),          // onSelected = (optionIndex) => notifier.selectAnswer(i, optionIndex)
      state: selected == o ? BloomMcState.selected : BloomMcState.neutral,
    ),
  ]
  ```
- `FilledButton` "Nộp bài" (line 142) → `BloomPillButton(label: 'Nộp bài', variant: primary, block: true, onPressed: session.canSubmit ? notifier.submit : null)`.

- [ ] **Step 2: Update the test**

`comprehension_session_screen_test.dart` (12 tests). Swaps (survey §5 line list):
- `expect(find.byType(RadioListTile<int>), findsNWidgets(12));` (line 109) → `expect(find.byType(BloomMcOption), findsNWidgets(12));`.
- `tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'))` / `tester.tap(...)` (lines 115–130) → `BloomPillButton` equivalents; `.onPressed` field carries over.
- `tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_previous))` (lines 143–144) and `...skip_next` (156–157) — these read `.onPressed` to assert disabled-at-boundary. `BloomAudioControls.transport` renders `BloomIconButton` for prev/next. Swap to: `tester.widget<BloomIconButton>(find.widgetWithIcon(BloomIconButton, Icons.skip_previous)).onPressed` — `BloomIconButton.onPressed` is a public `VoidCallback?` field (survey §3). Assert `isNull` at first turn / `isNotNull` otherwise. `tester.tap(find.byIcon(Icons.skip_next))` (line 148) still works (the icon is inside the `BloomIconButton`).
- `find.byType(Slider)` (lines 166–187) — still resolves via `BloomWordSeekBar`. Keep assertions.
- `find.byType(SegmentedButton<double>)` (lines 200–214) — unchanged.
- Add: `expect(find.byType(BloomAudioControls), findsOneWidget);`.
- The play/stop toggle test: the button is now the `_PlayPill` inside `BloomAudioControls`. Assert against `find.text('Phát')` / `find.text('Dừng')` and `find.byIcon(Icons.play_arrow)` / `find.byIcon(Icons.stop)` instead of `Icons.play_circle` / `Icons.stop_circle`. Keep the "tapping play calls `playCurrentTurn` / tapping while speaking calls `stopPlayback`" behavior assertions (via the `_FakeListeningNotifier` spy).

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/comprehension_session_screen_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → count is now **10** (`comprehension_session_screen.dart:185,191` gone), no new issues.
```bash
git add lib/features/listening/presentation/screens/comprehension_session_screen.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(listening): Bloom Nghe hiểu session (BloomAudioControls transport + BloomMcOption)

RadioListTile<int> -> BloomMcOption removes 2 deprecation infos. analyze: 10 (was 12).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Nghe hiểu result screen

**Files:**
- Modify: `lib/features/listening/presentation/screens/comprehension_result_screen.dart`
- Test: `test/features/listening/presentation/screens/comprehension_result_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomMcOption` (+`BloomMcState`), `BloomPillButton`, `context.bloom`, `webScaled`. Embeds `ResultSuggestionsSection` (unchanged usage — Task 14 restyles that widget internally).
- Frozen: `initState` post-frame `_recordPracticeSession()` → `statsServiceProvider.recordPracticeSession(result.passage.questions.length)`, `_regenerate` (`notifier.reset()` + `context.go('/listening/comprehension')`), `_goHome` (`notifier.reset()` + `context.go('/')`), `result.correctCount`, the `ResultSuggestionsSection(text:, targetLanguage:, targetCefrLevel:)` call.

- [ ] **Step 1: Restyle**

- `PopScope(canPop: false, onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/listening/comprehension'); }, child: BloomScaffold(appBar: BloomAppBar(title: 'Kết quả', automaticallyImplyLeading: false), body: Padding(padding: const EdgeInsets.all(16), child: ListView(...))))`.
- The `${result.correctCount}/${total}` headline → `Text(..., style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: result.correctCount == total ? context.bloom.success : context.bloom.accent))` (ports `.mc-score`).
- `_QuestionBreakdown` (line 127): outer `Card` → `BloomCard`. **Keep `Icon(Icons.check_circle)` / `Icon(Icons.cancel)`** per question (test asserts `find.byIcon` counts) — recolour to `context.bloom.success` / `context.bloom.danger`. Question text `Text(webScaled('${n}. ${question.question}'), style: TextStyle(fontWeight: FontWeight.w700, color: context.bloom.ink))`. Replace the per-option `Text` list with read-only `BloomMcOption`:
  ```dart
  for (var o = 0; o < question.options.length; o++) ...[
    if (o > 0) const SizedBox(height: BloomSpacing.sm),
    BloomMcOption(
      label: question.options[o],
      leading: String.fromCharCode(65 + o),
      onTap: null,
      state: o == question.correctIndex
          ? BloomMcState.correct
          : (o == selected ? BloomMcState.wrong : BloomMcState.neutral),
    ),
  ]
  ```
  where `selected = result.selectedAnswers[questionIndex]`.
- The transcript / "Bản ghi âm" section: header `Text('Bản ghi âm', w700 ink)`, body — a `BloomCard` with the turns; each turn `Text(webScaled('${speakerLabel}: ${turn.text}'), style: TextStyle(color: context.bloom.inkSoft))` (keep whatever speaker-label scheme the screen currently renders — "A"/"B" or names — unchanged).
- Buttons: `BloomPillButton` "Bài khác" (primary block) / "Về trang chính" (secondary block).

- [ ] **Step 2: Update the test**

`comprehension_result_screen_test.dart` (7 tests). Swaps (survey §5):
- `find.text('2/3')` (line 94) unchanged.
- `find.byIcon(Icons.check_circle)` `findsNWidgets(2)` / `find.byIcon(Icons.cancel)` `findsNWidgets(1)` (lines 110–111) — **must still pass**: keep those icons in `_QuestionBreakdown`.
- `find.text('Bài khác')` / `find.text('Về trang chính')` (117–118) unchanged.
- `find.text('Gợi ý từ mới')` / `find.text('ubiquitous')` / `find.text('Gợi ý từ mới') findsNothing` (170–192) — driven by `ResultSuggestionsSection`; unchanged by this task (Task 14 keeps that section's header text).
- Add `expect(find.byType(BloomMcOption), findsWidgets);` and, if a `find.byType(Card)` is used for the breakdown, swap to `find.byType(BloomCard)`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/listening/presentation/screens/comprehension_result_screen_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 4: Full listening suite + analyzer + commit**

Run: `flutter test test/features/listening/`
Run: `flutter analyze` → ≤ 10, no new.
```bash
git add lib/features/listening/presentation/screens/comprehension_result_screen.dart test/features/listening/presentation/screens/comprehension_result_screen_test.dart
git commit -m "feat(listening): Bloom Nghe hiểu result screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: Progress / Tiến độ dashboard

**Files:**
- Modify: `lib/features/practice/presentation/screens/progress_screen.dart`
- Test: **Create** `test/features/practice/presentation/screens/progress_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar` + `BloomIconButton`, `BloomCard`, `BloomStatCard`, `BloomBarChart` (+`BloomBarChartBar`), `BloomProgressBar`, `BloomPillButton`, `BloomSectionHeader`, `context.bloom`.
- Frozen: `_ProgressScreenState` (`bool _loading`), `ref.watch(learningStatsProvider)`, `_startDueSession()` (shuffles due words, toggles `_loading` via `setState`, `context.push('/practice/session', extra: SessionConfig(words: shuffled))`), the `ScaffoldMessenger.of(context).showSnackBar(...)` on empty/error, the `statsAsync.when(loading/error/data)` structure, the `LearningStats` field reads (`dueCount`, `masteredCount`, `totalCount`, `cefrBreakdown` (`Map<CEFRLevel,int>`), `currentStreak`, `weeklyLog` (`Map<String,int>`, `"yyyy-MM-dd"` keys)), the 7-day derivation (`List.generate(7, (i) => today.subtract(Duration(days: 6 - i)))`) and weekday labels (`['T2','T3','T4','T5','T6','T7','CN'][d.weekday - 1]`).

- [ ] **Step 1: Read `progress_screen.dart` fully** and note the exact current strings: the streak banner copy (`"$streak ngày liên tiếp"` / the zero-streak message), the two stat labels ("Đến hạn" / "Đã thuộc" or similar — read them), the CTA label (`"Ôn $dueCount từ ngay"` — read it), the CEFR row layout, the chart section title (`"7 ngày gần đây"` / `"Hoạt động tuần này"` — read it), the AppBar title (`"Tiến độ học"`).

- [ ] **Step 2: Rewrite `build()` / `data:` branch**

- `loading:` → `BloomScaffold(body: Center(child: CircularProgressIndicator()))` (raw spinner OK).
- `error:` → `BloomScaffold(appBar: BloomAppBar(title: 'Tiến độ học', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice'))), body: Center(child: Text('Không tải được dữ liệu tiến độ.', style: TextStyle(color: context.bloom.inkSoft))))`. (Add `import 'package:go_router/go_router.dart';` if not present — `context.go`; the screen currently uses `context.push`.)
- `data:` → `BloomScaffold(appBar: BloomAppBar(title: 'Tiến độ học', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice'))), body: ListView(padding: const EdgeInsets.all(16), children: [...]))`.
- **Streak banner** → `BloomCard(child: Row([Text(streak > 0 ? '🔥' : '❄️', style: TextStyle(fontSize: 34)), SizedBox(width: 16), Expanded(Column(crossAxisAlignment: start, [ if (streak > 0) Text('$streak', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: context.bloom.ink, fontFeatures: const [FontFeature.tabularFigures()])), Text(streak > 0 ? 'ngày liên tiếp' : '<the current zero-streak copy>', style: TextStyle(fontSize: 13, color: context.bloom.inkSoft)) ]))]))`. Keep the exact zero-streak string from the current code.
- **Stat grid** → `Row(children: [Expanded(BloomStatCard(label: '<current label 1>', value: '${stats.dueCount}', foot: '<current foot if any>')), SizedBox(width: BloomSpacing.md), Expanded(BloomStatCard(label: '<current label 2>', value: '${stats.masteredCount}', foot: '/ ${stats.totalCount} từ'))])`. Preserve current labels/foot copy.
- **CTA** (only when `stats.dueCount > 0`) → `BloomPillButton(label: '<current CTA label, e.g. "Ôn ${stats.dueCount} từ ngay">', icon: Icons.play_arrow, variant: BloomButtonVariant.primary, block: true, onPressed: _loading ? null : _startDueSession)`. When `_loading` keep showing the inline spinner — either disable + swap label to a spinner row, or keep the current inline `CircularProgressIndicator(strokeWidth: 2)` treatment; simplest: `onPressed: _loading ? null : _startDueSession` and leave the label. Preserve the current behavior of the `_loading` flag.
- **CEFR breakdown** → `BloomCard(child: Column(crossAxisAlignment: stretch, [ BloomSectionHeader('Theo cấp độ CEFR'), for each level in CEFRLevel.values: Padding(vertical: 5, child: Row([SizedBox(width: 32, child: Text(level.name.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.bloom.inkSoft))), SizedBox(width: BloomSpacing.md), Expanded(BloomProgressBar(value: total == 0 ? 0 : count / total, height: 8)), SizedBox(width: BloomSpacing.md), SizedBox(width: 32, child: Text('$count', textAlign: TextAlign.end, style: TextStyle(fontSize: 12.5, color: context.bloom.inkSoft)))]))]))` where `count = stats.cefrBreakdown[level] ?? 0` and `total = stats.cefrBreakdown.values.fold(0, (a, b) => a + b)`. Use the same `total` basis the current `_CefrBreakdown` uses (read it — it may divide by `totalCount` or by the CEFR sum; match it).
- **Weekly chart** → `BloomCard(child: Column(crossAxisAlignment: stretch, [ BloomSectionHeader('<current chart title>'), SizedBox(height: BloomSpacing.sm), BloomBarChart(bars: [ for (final d in last7Days) BloomBarChartBar(label: weekdayLabel(d), value: stats.weeklyLog[dateKey(d)] ?? 0, highlight: dateKey(d) == dateKey(today)) ]) ]))`. Reuse the screen's existing `last7Days` / label / `dateKey` (`yyyy-MM-dd`) helpers — extract them from `_WeeklyChartPainter` if they were private to it. **Delete `_WeeklyChart` + `_WeeklyChartPainter`** (the `CustomPainter`) — `BloomBarChart` replaces both. **Delete the private `_StreakBanner` / `_StatCard` / `_CefrBreakdown`** widgets, folding their logic inline or into small local builders.
- Keep `dart:ui`'s `FontFeature` import if you use tabular figures.

- [ ] **Step 3: Write `progress_screen_test.dart` from scratch**

Model the harness on `test/features/practice/presentation/screens/session_result_screen_test.dart` (or any practice-screen test) — a `ProviderScope` overriding `learningStatsProvider` with an `AsyncData(<fixture LearningStats>)`, inside a `GoRouter` (`/` → `ProgressScreen`, `/practice` stub, `/practice/session` stub capturing `extra`), `MaterialApp.router`, no theme. Tests:

```dart
// fixture: dueCount 12, masteredCount 5, totalCount 40,
// cefrBreakdown {a1: 10, a2: 8, b1: 15, b2: 5, c1: 2, c2: 0},
// currentStreak 3, weeklyLog { <today>: 4, <today-1>: 2, <today-3>: 7 }

testWidgets('renders the streak, both stat cards, and the CEFR + chart sections', (tester) async {
  await tester.pumpWidget(_buildProgress(_stats));
  await tester.pumpAndSettle();
  expect(find.text('3'), findsWidgets);            // streak count
  expect(find.text('12'), findsOneWidget);          // due
  expect(find.text('5'), findsOneWidget);           // mastered
  expect(find.byType(BloomStatCard), findsNWidgets(2));
  expect(find.byType(BloomBarChart), findsOneWidget);
  expect(find.byType(BloomProgressBar), findsNWidgets(6)); // one per CEFR level
});

testWidgets('the "ôn ngay" CTA pushes a session with the due words', (tester) async {
  await tester.pumpWidget(_buildProgress(_stats));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BloomPillButton));
  await tester.pumpAndSettle();
  expect(find.text('Session stub'), findsOneWidget); // stub route content
});

testWidgets('zero-streak shows the ❄️ prompt, no CTA when nothing is due', (tester) async {
  await tester.pumpWidget(_buildProgress(_statsNothingDue)); // dueCount 0, currentStreak 0
  await tester.pumpAndSettle();
  expect(find.text('❄️'), findsOneWidget);
  expect(find.byType(BloomPillButton), findsNothing);
});

testWidgets('the back button routes to /practice', (tester) async {
  await tester.pumpWidget(_buildProgress(_stats));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BloomIconButton));
  await tester.pumpAndSettle();
  expect(find.text('Practice stub'), findsOneWidget);
});

testWidgets('loading state shows a spinner', (tester) async {
  await tester.pumpWidget(_buildProgress(null, loading: true));
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

Check `learningStatsProvider`'s actual type (`FutureProvider<LearningStats>` vs a `Notifier`) before writing the override — grep `learningStatsProvider` and match. If it's a `@riverpod` function provider, override with `learningStatsProvider.overrideWith((ref) async => _stats)`. Confirm `SessionConfig` / `CEFRLevel` fixture construction against their real constructors.

- [ ] **Step 4: Run**

Run: `flutter test test/features/practice/presentation/screens/progress_screen_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Analyzer + commit**

Run: `flutter analyze` → ≤ 10, no new.
```bash
git add lib/features/practice/presentation/screens/progress_screen.dart test/features/practice/presentation/screens/progress_screen_test.dart
git commit -m "feat(progress): Bloom Tiến độ dashboard (BloomStatCard + BloomBarChart + BloomProgressBar CEFR)

Replaces the _WeeklyChartPainter CustomPainter with BloomBarChart. Adds the first
widget test for this screen (5 tests).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: Quét từ vựng (Word Radar) screen

**Files:**
- Modify: `lib/features/word_radar/presentation/screens/word_radar_screen.dart`
- Test: `test/features/word_radar/presentation/screens/word_radar_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar` + `BloomIconButton`, `BloomCard`, `BloomTextField`, `BloomPillButton`, `context.bloom`. Embeds `VocabSuggestionsSection` (Task 14 restyles internally).
- Frozen: `_maxInputLength = 3000`, the `_controller` + `dispose`, `ref.watch(wordRadarNotifierProvider)`, `_openKnownWord` (`context.push('/vocab/${record.id}')`), the back target `context.go('/practice')`, the "scan" action wiring (`wordRadarNotifierProvider.notifier.<method>(text)` — read the exact call), the `_HighlightedText` span logic (highlighted known-word spans), the `radarState.aiResult == null` → `Text('Bật AI trong Cài đặt để nhận gợi ý từ mới.')` branch (string unchanged), the `radarState` loading/error branches.

- [ ] **Step 1: Restyle**

- `BloomScaffold(appBar: BloomAppBar(title: 'Quét từ vựng', leading: BloomIconButton(icon: Icons.arrow_back_ios_new, onPressed: () => context.go('/practice'))), body: ListView(padding: const EdgeInsets.all(16), children: [...]))`.
- Input area → `BloomCard(child: Column(crossAxisAlignment: stretch, [ BloomTextField(controller: _controller, hintText: 'Dán đoạn văn cần quét...', maxLines: 8, minLines: 6, keyboardType: TextInputType.multiline, onChanged: (_) => setState(() {})), SizedBox(height: BloomSpacing.sm), Row(mainAxisAlignment: spaceBetween, children: [ Text('${_controller.text.characters.length}/$_maxInputLength', style: TextStyle(fontSize: 12.5, color: context.bloom.inkFaint, fontFeatures: const [FontFeature.tabularFigures()])), // char counter ]) ]))`.
  - **`BloomTextField` has no `maxLength`.** Enforce the 3000-char cap with an `inputFormatters: [LengthLimitingTextInputFormatter(_maxInputLength)]` — but `BloomTextField` (survey §3) has no `inputFormatters` param either. Two options: (a) add an `inputFormatters` param to `BloomTextField` (small, additive, safe — do this, and add a one-line test to `test/core/theme/bloom/bloom_text_field_test.dart` if that file exists); or (b) keep a raw `TextField` here just for Word Radar with Bloom `InputDecoration` (surface2 fill, border/accent focus, `BorderRadius.circular(BloomRadii.sm)` for multiline). **Prefer (a)** — `inputFormatters` is a natural `BloomTextField` gap and other multiline uses will want it. If the reviewer prefers (b), that's acceptable.
- "Quét" button → `SizedBox(width: double.infinity, child: BloomPillButton(label: 'Quét', icon: Icons.radar, variant: BloomButtonVariant.primary, block: true, onPressed: _controller.text.trim().isEmpty ? null : <existing scan callback>))`. Keep the exact enable condition the current `FilledButton` uses.
- Results → `BloomCard`s. The AI-hint line (`radarState.aiResult == null` branch) → `Container(padding: EdgeInsets.all(BloomSpacing.md), decoration: BoxDecoration(color: context.bloom.amberBg, borderRadius: BorderRadius.circular(BloomRadii.md)), child: Text('Bật AI trong Cài đặt để nhận gợi ý từ mới.', style: TextStyle(color: context.bloom.amber, fontWeight: FontWeight.w600)))` (ports `.word-radar-ai-hint`; **string unchanged**).
- `_HighlightedText` (`Text.rich`): highlighted known-word spans → `TextStyle(fontWeight: FontWeight.w700, color: context.bloom.sage, backgroundColor: context.bloom.sageBg)`; plain spans → `color: context.bloom.ink`. Keep the tap-recognizer → `_openKnownWord`.
- Loading `CircularProgressIndicator` stays raw. `TextButton` "Thử lại" → `BloomPillButton(label: 'Thử lại', variant: secondary, onPressed: <existing>)`.

- [ ] **Step 2: Update the test**

`word_radar_screen_test.dart` (10 tests). Swaps (survey §5):
- `find.byType(TextField)` (lines 155, 171, 203, 237, 279, 304, 344, 367) — if you chose option (a), `BloomTextField` renders a `TextField` internally so `find.byType(TextField)` still resolves and `tester.enterText(find.byType(TextField), ...)` works. If option (b), also fine. **No change needed** either way — but if two `TextField`s ever coexist, disambiguate with `.first`.
- `tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Quét'))` (lines 316–317) → `tester.widget<BloomPillButton>(find.widgetWithText(BloomPillButton, 'Quét'))`; assert `.onPressed` null/non-null.
- `find.byIcon(Icons.close)` (line 243) / `find.byIcon(Icons.check_circle)` `findsNWidgets(2)` (line 288) — these live in `VocabSuggestionsSection` (Task 14); keep the icons there.
- `find.text('C1')` (line 349) — the CEFR chip. Task 14 renders it as `BloomCefrPill` (`Text` child) — `find.text('C1')` still resolves.
- Text finders (`'Quét'`, `'ubiquitous'`, `'Lưu tất cả'`, `'Bản dịch'`, `find.textContaining('Bật AI trong Cài đặt')`) unchanged.
- Add `expect(find.byType(BloomAppBar), findsOneWidget);`.

- [ ] **Step 3: Run**

Run: `flutter test test/features/word_radar/presentation/screens/word_radar_screen_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 4: Analyzer + commit**

Run: `flutter analyze` → ≤ 10, no new.
```bash
git add lib/features/word_radar/presentation/screens/word_radar_screen.dart lib/core/theme/bloom/bloom_text_field.dart test/features/word_radar/presentation/screens/word_radar_screen_test.dart test/core/theme/bloom/bloom_text_field_test.dart
git commit -m "feat(word-radar): Bloom Quét từ vựng screen

Adds an inputFormatters passthrough to BloomTextField for the 3000-char cap.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```
(Drop `bloom_text_field.dart` / its test from `git add` if you took option (b).)

---

## Task 14: Word Radar suggestion sections

**Files:**
- Modify: `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`
- Modify: `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`
- Test: `test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart`
- Test: `test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`

**Interfaces:**
- Consumes: `BloomCard`, `BloomPillButton`, `BloomCefrPill`, `context.bloom`.
- Frozen: `VocabSuggestionsSection` — `showModalBottomSheet<bool>(... SaveVocabSheet(result: suggestion))`, the `_savedHeadwords` / `_dismissedHeadwords` `Set<String>` state, the bulk "Lưu tất cả" loop (incl. `VocabRecord(... activeContext: AppContext.general ...)` — an entity field, leave it), `ScaffoldMessenger...showSnackBar`. `ResultSuggestionsSection` — `initState` post-frame `_load()`, the `if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;` gate (**unchanged** — `aiEnabled`, not `aiAvailable`, per Global Constraints), the `AsyncValue.guard(...)` call, the delegation to `VocabSuggestionsSection`.

- [ ] **Step 1: Restyle `vocab_suggestions_section.dart`**

- The "Gợi ý từ mới" header `Text` → `Text('Gợi ý từ mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: context.bloom.ink))` (**string unchanged** — test asserts it).
- `TextButton.icon` "Lưu tất cả" (`Icons.done_all`) → `BloomPillButton(label: 'Lưu tất cả', variant: BloomButtonVariant.link, onPressed: <existing>)` (string unchanged).
- Each suggestion `Card` + `ListTile` → `BloomCard(padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10), onTap: <existing: open SaveVocabSheet>, child: Row([ Expanded(Column(crossAxisAlignment: start, [ Text(suggestion.headword, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: context.bloom.ink)), if (ipa/meaning) Text('<ipa> • <meaning>', style: TextStyle(fontSize: 13.5, color: context.bloom.inkSoft)) ])), if (suggestion.cefrLevel != null) BloomCefrPill(suggestion.cefrLevel!.name.toUpperCase()), SizedBox(width: 8), <trailing> ]))` where `<trailing>` is either `Icon(Icons.check_circle, color: context.bloom.success)` (saved) or `IconButton(icon: Icon(Icons.close, size: 18, color: context.bloom.inkFaint), tooltip: 'Bỏ qua gợi ý này', onPressed: <existing dismiss>)`. **Keep `Icons.check_circle` and `Icons.close`** (tests: `find.byIcon`).
- The `SaveVocabSheet` open path, the "Lưu \"<word>\"" sheet title, "Không có gợi ý mới." empty text — all unchanged.

- [ ] **Step 2: Restyle `result_suggestions_section.dart`**

- `CircularProgressIndicator` (line 61) stays raw. `TextButton` "Thử lại" (line 67) → `BloomPillButton(label: 'Thử lại', variant: secondary, onPressed: <existing>)`. The "Không tải được gợi ý từ mới" error `Text` → `color: context.bloom.danger`. Everything else delegates to `VocabSuggestionsSection`.

- [ ] **Step 3: Update the tests**

- `vocab_suggestions_section_test.dart` (4 tests): `find.byIcon(Icons.close)` (line 116) / `find.byIcon(Icons.check_circle)` (line 131) — **keep passing** (icons preserved). Text finders (`'Không có gợi ý mới.'`, `'ubiquitous'`, `'Lưu "ubiquitous"'`, `'Lưu tất cả'`) unchanged. If a `find.byType(Card)` / `find.byType(ListTile)` is used, swap to `find.byType(BloomCard)`.
- `result_suggestions_section_test.dart` (4 tests): all text finders (`'Gợi ý từ mới'`, `'ubiquitous'`, `'Thử lại'`, `'Không có gợi ý mới.'`, `find.textContaining('Không tải được gợi ý từ mới')`). Unchanged. If `find.widgetWithText(TextButton, 'Thử lại')` is used, swap to `BloomPillButton`.

- [ ] **Step 4: Run**

Run: `flutter test test/features/word_radar/`
Expected: PASS (all word_radar tests).

- [ ] **Step 5: Full suite + analyzer**

Run: `flutter test`
Run: `flutter analyze`
Expected: suite green and strictly above 721 (Progress test file added ≈ +5); analyze ≤ 10, zero new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart lib/features/word_radar/presentation/widgets/result_suggestions_section.dart test/features/word_radar/presentation/widgets/vocab_suggestions_section_test.dart test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart
git commit -m "feat(word-radar): Bloom suggestion cards + result section

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage (§Phần B items 10–13, §A3):**
- Item 10 (Progress: streak → `BloomCard` + emoji, `BloomStatCard` ×2, CEFR `BloomProgressBar`, `BloomBarChart` 7 days) = Task 12. Widgets: `BloomStatCard` Task 1, `BloomBarChart` Task 2. ✓
- Item 11 (Listening hub + Nghe chép: `BloomAudioControls` + `BloomWordSeekBar` + cloze/free mono input, `AiDisabledCard`) = hub Task 5, home Task 6, session Task 7, result Task 8. Widgets: `BloomAudioControls` Task 3, `BloomWordSeekBar` Task 4. ✓
- Item 12 (Nghe hiểu: `_context = AppContext.general` [already done], `BloomAudioControls` + `BloomWordSeekBar` + "A"/"B" turn label + 3 `BloomMcOption`) = home Task 9, session Task 10, result Task 11. ✓ — the C1 `_context` change is already in the code (survey §2e), noted in Global Constraints.
- Item 13 (Word Radar: `BloomTextField` multiline + char count + "Quét", `word-radar-ai-hint` amber; `vocab_suggestions_section` / `result_suggestions_section` → `BloomCard` + sage highlight) = screen Task 13, sections Task 14. ✓
- §A3 widget-table rows `BloomStatCard` / `BloomBarChart` / `BloomAudioControls` / `BloomWordSeekBar` = Tasks 1–4. ✓
- `BloomSegmented` (widget-table row, used by the speed selector visually) — **deferred to Plan 6** with the theme picker; `_SpeedSelector` stays raw `SegmentedButton<double>`. Called out in Global Constraints. `BloomSwitch` — Plan 6 (Settings). `AiKeyMissingCard` — Plan 6 (C2).
- §Testing "BloomBarChart needs interaction/render tests; audio controls need callback tests": Task 2 tests value display + all-zero render; Task 3 tests every callback + disabled states; Task 4 tests drag → onChanged/onChangeEnd. ✓

**2. Placeholder scan:** Tasks 1–4 give full widget source. Screen tasks 5–14 reference the shared restyle recipe (spelled out once) plus explicit per-screen deltas, exact frozen call signatures (from the survey), and exact test-finder line swaps (from the survey's line-numbered lists). Task 12's "read the current strings first" step is deliberate — the Progress screen's exact copy wasn't captured verbatim and must be preserved, not invented. Task 8 and Task 12 both flag the specific asserted strings that constrain the new widgets ("Số lần tua … (−N%)", streak copy).

**3. Type consistency:**
- `BloomStatCard({label, value, foot})` — used identically in Tasks 8 (×4) and 12 (×2).
- `BloomBarChart({bars, height})` + `BloomBarChartBar({label, value, highlight})` — used in Task 12.
- `BloomAudioControls.playOnly({isPlaying, onPlayPause, playLabel})` — Task 7. `BloomAudioControls.transport({isPlaying, onPlayPause, onPrevious, onNext, onReplay, playLabel?})` — Task 10.
- `BloomWordSeekBar({value, max, onChanged, onChangeStart?, onChangeEnd?, label?, enabled})` — Tasks 7, 10.
- `BloomMcOption({label, onTap, state, leading})` + `BloomMcState.{neutral,selected,correct,wrong}` — from Plan 3; interactive in Task 10, read-only (`onTap: null`) in Task 11.
- `BloomPillButton({label, onPressed, variant, block, icon})` + `BloomButtonVariant.{primary,secondary,sage,danger,link}` — Plan 1; `.onPressed` is a public field (tests read it).
- `BloomIconButton({icon, onPressed, tooltip?})` — Plan 1; `.onPressed` public field (Task 10 test reads it for the skip-prev/next disabled assertions).
- Every `context.go(...)` parent target matches `app_router.dart`: `/practice`, `/listening/dictation`, `/listening/comprehension`, `/` (home).

**4. Risk notes for the implementer:**
- **Test harnesses have no `AppTheme`.** Bloom widgets resolve `context.bloom` via the `BloomColors.light` fallback (`bloom_tokens.dart:157`) — same as the reading-area tests. No `ProviderScope`/theme additions needed for the widget swaps themselves.
- **`_SeekSlider` preview-state field names differ** between dictation and comprehension — read each file and mirror the exact field name / enable condition; only swap the rendered `Slider` → `BloomWordSeekBar`.
- **`SegmentedButton<double>` stays raw** — do not try to Bloom-ify it this plan; its tests (`find.byType(SegmentedButton<double>)`) must keep passing untouched.
- **`Icons.check_circle` / `Icons.cancel` / `Icons.close`** are asserted by four test files (`find.byIcon`) — keep the exact `IconData`, only recolour.
- **Task 8 "Số lần tua" string** and **Task 12 streak / stat-label copy** must be reproduced byte-for-byte — read the current code, don't paraphrase.
- **`BloomProgressBar` has no indeterminate mode** — the CEFR rows have a real fraction (fine); every `loading:` spinner stays raw Material.
- **Task 13 `BloomTextField.inputFormatters`**: adding the param is the preferred path (additive, safe); if the reviewer objects, a raw Bloom-decorated `TextField` for Word Radar only is acceptable. Either way `find.byType(TextField)` must still resolve for the test.
- **Task 12 creates a new test file** — check `learningStatsProvider`'s real type and `SessionConfig` / `CEFRLevel` / `LearningStats` constructors before writing fixtures; model the harness on an existing `test/features/practice/presentation/screens/*_test.dart`.
- **`comprehension_session_screen.dart` analyze infos** `:185,191` disappear when `RadioListTile` → `BloomMcOption` — the count drops to 10. Fine. It must never rise.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-03-flutter-bloom-plan5-listening-radar-progress.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session with `executing-plans`, batched with checkpoints.

**Which approach?**
