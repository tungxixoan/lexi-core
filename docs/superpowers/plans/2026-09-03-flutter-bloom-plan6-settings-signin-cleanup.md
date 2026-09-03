# Flutter Bloom — Plan 6 (final): Settings + Sign-in + AI-toggle removal + theme picker + cleanup

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the Flutter Bloom redesign — restyle the Settings and Sign-in screens, retire the global "Bật AI" toggle (spec §C2: infer AI availability from a stored API key, like the web), add the first Sáng/Tối/Hệ thống theme picker UI (spec §D), retire every raw `SegmentedButton`/`Switch`/`RadioListTile` the design system now has a replacement for, fold in the carried Minor cleanups from Plans 2–5, and update the docs (spec §E).

**Architecture:** New Bloom widgets land first (`BloomSwitch`, `BloomSegmented`, `BloomNavCard`). Then C2 is done area-by-area — each area's runtime reads flip from `settings.aiEnabled` to `settings.aiAvailable` (a getter that already exists), keeping the `aiEnabled` field alive until every reader is gone, then one task deletes the field. Then the two screens, the speed-selector swap, the carried minors, `RadioListTile` modernization, and docs. **Every provider/notifier/use-case/entity behavior is preserved** except the deliberate C2 signature changes (drop the `aiEnabled` param / flag); no route or `go_router` change.

**Tech Stack:** Flutter 3.41 / Dart ≥3.4, `flutter_riverpod` (`@riverpod` codegen), `go_router`, `flutter_test`, `mockito` (regen for `lookup_use_case`), `mocktail`. Bloom design system from Plans 1–5 (`lib/core/theme/bloom/`).

## Global Constraints

- **Bloom widgets** from `import 'package:lexi_core/core/theme/bloom/bloom.dart';` — the barrel exports `BloomScaffold`, `BloomAppBar` + `BloomIconButton`, `BloomCard`, `BloomPillButton` (+`BloomButtonVariant.{primary,secondary,sage,danger,link}`), `BloomChip` (+`BloomChipStyle`) + `BloomCefrPill`, `BloomProgressBar`, `BloomSectionHeader` + `BloomLeafMark` (in `bloom_labels.dart`), `BloomListRow`, `BloomTextField` (has `inputFormatters`), `BloomMcOption` (+`BloomMcState`), `BloomResultRing`, `BloomStatCard`, `BloomBarChart`, `BloomAudioControls`, `BloomWordSeekBar`, `BloomExpansionTile`, `BloomGroupChips`. This plan adds `BloomSwitch` (Task 1), `BloomSegmented` (Task 2), `BloomNavCard` (Task 3).
- **`FilterTile`** is `import 'package:lexi_core/core/widgets/filter_tile.dart';` — `const FilterTile({required IconData icon, required String label, required String value, required VoidCallback onTap})`, already Bloom-styled, NOT in the barrel. `showSingleSelectSheet` / `showMultiSelectSheet` / `SelectOption` from `import 'package:lexi_core/core/widgets/selection_sheets.dart';` — already Bloom-styled.
- **Colors** via `context.bloom` (a `BloomColors`; falls back to `BloomColors.light` in themeless test harnesses). Never a raw `Colors.*` (except `Colors.transparent`) or `Color(0x...)` in new/edited code. Map: `Colors.red` (errors) → `context.bloom.danger`; `theme.colorScheme.primary` (section labels) → handled by `BloomSectionHeader`; `theme.colorScheme.onSurfaceVariant` → `context.bloom.inkSoft`.
- **Radii** only `BloomRadii.sm=10 / md=16 / lg=20 / pill=999`. **Spacing** `BloomSpacing.xs=4 / sm=8 / md=12 / lg=16 / xl=22 / xxl=32`.
- **`flutter analyze` baseline is 10 infos** — all `RadioListTile`/`Radio` `groupValue`/`onChanged` deprecations: `lib/core/widgets/selection_sheets.dart:79,82` (2) and `lib/features/settings/presentation/screens/settings_screen.dart:188,189,199,200,267,268,273,274` (8, two CEFR pickers + two model pickers). Task 9 removes the 8 in `settings_screen.dart` (replacing the inline `_showCefrPicker` / `_showModelPicker` `RadioListTile` lists with `showSingleSelectSheet`). Task 12 removes the last 2 (migrating `selection_sheets.dart` to a `RadioGroup` ancestor). **End state: 0 analyze issues.** The count only goes down; no new lint of any kind, ever.
- **Tests:** the suite is at **743 passing** at plan start (`flutter test`). It only goes up (Tasks 9 & 10 add `settings_screen_test.dart` + `sign_in_screen_test.dart` — the first coverage for either screen). When a widget swap breaks a finder, fix the finder (`find.text` / `find.byKey` / `find.byType(BloomX)` / `find.widgetWithText(BloomX, ...)`). **Never weaken or delete a behavior assertion.**
- **C2 test-harness pattern.** Many test harnesses today take `required bool aiEnabled` and either `SharedPreferences.setMockInitialValues({'ai_enabled': aiEnabled})` or `UserSettingsState.defaults.copyWith(aiEnabled: aiEnabled)`. After a C2 area task, "AI available" ⇔ the **active provider's `ProviderConfig` has a non-empty `apiKeyCiphertext`**. Convert each harness like this: rename its param `aiEnabled` → `aiAvailable`, and where it built the settings/prefs, make `aiAvailable` choose the config:
  ```dart
  providerConfigs: {
    AiProvider.gemini: ProviderConfig(
      apiKeyCiphertext: aiAvailable ? 'ck' : null,
      model: 'gemini-2.5-flash',
    ),
  },
  ```
  (drop the `'ai_enabled'` mock-prefs key). Test bodies keep calling `_build(aiAvailable: false)` / `true`. Do NOT invent a new abstraction — this literal `providerConfigs` map is the conversion.
- **Behavior frozen** except the explicit C2 changes. No change to: `AiSettingsSyncService` / `bootstrapSync`, the `_pushBestEffort` sync (it never carried `aiEnabled`), `HiveMigrationService`, `authNotifierProvider` / `signInWithGoogle` / `signOut`, `setThemePreference` (already exists, local-only — Task 9 only adds a UI that calls it), `setReminderEnabled` / `setActiveProvider` / `setModelForActiveProvider` / `setTargetCefrLevel` / `setTargetLanguage`, the `redirect` guards in `app_router.dart`, every route string. Restyle + the C2 signature edits only.
- **C2 scope (spec §C2):** remove `UserSettingsState.aiEnabled` (field, ctor param, `copyWith` param + body, `defaults`), remove `UserSettingsNotifier.setAiEnabled` and its `'ai_enabled'` SharedPreferences load (`build()` line ~117) + save. Flip every runtime reader to `settings.aiAvailable`. `generate_exercise_use_case.execute` **drops** its `{required bool aiEnabled}` param (always tries `_source.generate`, `catch` → `FlashcardExercise`). `lookup_use_case.execute` / `DictionaryRepository.lookup` / `dictionary_repository_impl` **rename** the `aiEnabled` param → `aiAvailable` (same branch: `aiAvailable` → Gemini source, else Free Dictionary). `README.md` "Cấu hình AI" loses the "Bật AI toggle" step. The `AppContext` / `activeContext` removal (spec §C1) is **already done** (Plan 2) — not in this plan.
- **`AiDisabledCard` → two widgets (Task 7).** `lib/core/widgets/ai_disabled_card.dart` currently serves both the AI-off gate AND "not enough words" / "unsupported language" notices. Split: rename the file/class to **`HomeNoticeCard`** (same `const HomeNoticeCard({required String message})`, same Bloom-danger `Container` style, unchanged behavior) for the non-AI cases; add a new **`AiKeyMissingCard`** (`const AiKeyMissingCard({super.key})` — no `message` param) for the 6 AI-gate sites, rendering the fixed copy `'Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.'` plus a `BloomPillButton(label: 'Mở Cài đặt', variant: BloomButtonVariant.secondary, onPressed: () => context.go('/settings'))`.
- **`apps/web/` is never touched.** Package is `lexi_core`.
- **Spec:** `docs/superpowers/specs/2026-08-30-flutter-bloom-redesign-design.md` — §Phần B items 14–15, §C2, §D, §E, §A3 (rows `BloomSegmented`, `BloomSwitch`, `AiKeyMissingCard`).

---

## File Structure

**Created:**
- `lib/core/theme/bloom/bloom_switch.dart` — `BloomSwitch`
- `lib/core/theme/bloom/bloom_segmented.dart` — `BloomSegmented<T>`
- `lib/core/theme/bloom/bloom_nav_card.dart` — `BloomNavCard`
- `lib/core/widgets/ai_key_missing_card.dart` — `AiKeyMissingCard`
- `test/core/theme/bloom/bloom_switch_test.dart`
- `test/core/theme/bloom/bloom_segmented_test.dart`
- `test/core/theme/bloom/bloom_nav_card_test.dart`
- `test/core/widgets/ai_key_missing_card_test.dart`
- `test/features/settings/presentation/screens/settings_screen_test.dart` (Task 9)
- `test/features/settings/presentation/screens/sign_in_screen_test.dart` (Task 10)

**Renamed:**
- `lib/core/widgets/ai_disabled_card.dart` → `lib/core/widgets/home_notice_card.dart` (class `AiDisabledCard` → `HomeNoticeCard`)
- `test/core/widgets/ai_disabled_card_test.dart` → `test/core/widgets/home_notice_card_test.dart`

**Modified (grouped by task):**
- Barrel: `lib/core/theme/bloom/bloom.dart` — add 3 exports (Tasks 1–3)
- Task 3: `reading_hub_screen.dart`, `listening_home_screen.dart`, `practice_hub_screen.dart` (+ their tests) — `_ReadingCard`/`_ListeningCard`/`_HubCard` → `BloomNavCard`
- Task 4: `generate_exercise_use_case.dart`, `practice_session_provider.dart`, `generate_exercise_use_case_test.dart`, `practice_session_provider_test.dart` (if it asserts on `aiEnabled` — check)
- Task 5: `search_bar_widget.dart`, `lookup_provider.dart`, `lookup_use_case.dart`, `dictionary_repository.dart`, `dictionary_repository_impl.dart`, `lookup_use_case_test.dart` (+ `.mocks.dart` regen), `dictionary_repository_impl_test.dart`, `search_bar_widget_test.dart`
- Task 6: `word_radar_provider.dart`, `result_suggestions_section.dart`, `word_radar_provider_test.dart`, `result_suggestions_section_test.dart`, `word_radar_screen_test.dart` (the `'Bật AI trong Cài đặt'` finder)
- Task 7: `home_notice_card.dart` (renamed), `ai_key_missing_card.dart` (new), `reading_home_screen.dart`, `part5_home_screen.dart`, `part6_home_screen.dart`, `part7_home_screen.dart`, `comprehension_home_screen.dart`, `dictation_home_screen.dart` (+ their 6 test files), `home_notice_card_test.dart` (renamed), `ai_key_missing_card_test.dart` (new)
- Task 8: `user_settings_state.dart`, `user_settings_provider.dart`, `user_settings_state_test.dart`, `user_settings_notifier_test.dart`, `vocab_bank_provider_test.dart`
- Task 9: `settings_screen.dart` (+ new test)
- Task 10: `sign_in_screen.dart` (+ new test)
- Task 11: `dictation_session_screen.dart`, `comprehension_session_screen.dart` (+ their 2 test files) — `_SpeedSelector` → `BloomSegmented<double>`
- Task 12: `selection_sheets.dart` (`RadioListTile` → `RadioGroup`), `bloom_bar_chart.dart` (value caption), `word_radar_screen.dart` (2 `textTheme` headers → `BloomSectionHeader`) + `word_radar_screen_test.dart` (`'Bản dịch'` → `'BẢN DỊCH'` ×2)
- Task 13: `README.md`, `CLAUDE.md`

**Not in this plan:** any `apps/web/` file; the font-size / `web_text_scale.dart` port (spec §D explicitly excludes it); `AppContext`/`activeContext` (already removed, Plan 2).

---

## Task 1: BloomSwitch

**Files:**
- Create: `lib/core/theme/bloom/bloom_switch.dart`, `test/core/theme/bloom/bloom_switch_test.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomSwitch extends StatelessWidget {
    const BloomSwitch({
      super.key,
      required this.title,
      required this.value,
      required this.onChanged,
      this.subtitle,
    });
    final String title;
    final String? subtitle;
    final bool value;
    final ValueChanged<bool> onChanged;
  }
  ```
  A full-width row: `Expanded(Column(crossAxisAlignment: start, [Text(title, 15.5 · w600 · ink), if (subtitle != null) Text(subtitle!, 12.5 · inkSoft)]))` then a Material `Switch(value: value, onChanged: onChanged, activeTrackColor: context.bloom.accent, activeThumbColor: context.bloom.accentInk, inactiveTrackColor: context.bloom.surface3, inactiveThumbColor: context.bloom.inkFaint)`. Wrap the whole row in an `InkWell(onTap: () => onChanged(!value))` using the Bloom ripple pattern (`Container(decoration: color surface, border, BloomRadii.md) > Material(transparent) > InkWell > Padding(all BloomSpacing.lg) > Row`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_switch.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders title + subtitle and reflects value', (tester) async {
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'Nhắc nhở hàng ngày', subtitle: 'Thông báo khi có từ cần ôn',
      value: true, onChanged: (_) {},
    )));
    expect(find.text('Nhắc nhở hàng ngày'), findsOneWidget);
    expect(find.text('Thông báo khi có từ cần ôn'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('tapping the row toggles the value', (tester) async {
    bool? got;
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'X', value: false, onChanged: (v) => got = v,
    )));
    await tester.tap(find.text('X'));
    expect(got, isTrue);
  });

  testWidgets('flipping the Switch reports the new value', (tester) async {
    bool? got;
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'X', value: true, onChanged: (v) => got = v,
    )));
    await tester.tap(find.byType(Switch));
    expect(got, isFalse);
  });

  testWidgets('subtitle omitted when null', (tester) async {
    await tester.pumpWidget(_host(BloomSwitch(title: 'Only', value: false, onChanged: (_) {})));
    expect(find.byType(Text), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — FAIL** (`BloomSwitch` undefined). `flutter test test/core/theme/bloom/bloom_switch_test.dart`

- [ ] **Step 3: Implement** per the interface above. Add `export 'bloom_switch.dart';` to `bloom.dart` (alphabetical — after `bloom_stat_card.dart`, before `bloom_text_field.dart`).

- [ ] **Step 4: Run — PASS (4).** Then `flutter analyze lib/core/theme/bloom/bloom_switch.dart test/core/theme/bloom/bloom_switch_test.dart` — clean.

- [ ] **Step 5: `dart format`** the two new files.

- [ ] **Step 6: Commit**
```bash
git add lib/core/theme/bloom/bloom_switch.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_switch_test.dart
git commit -m "feat(bloom): BloomSwitch toggle row

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 2: BloomSegmented

**Files:**
- Create: `lib/core/theme/bloom/bloom_segmented.dart`, `test/core/theme/bloom/bloom_segmented_test.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`, `BloomSpacing`.
- Produces:
  ```dart
  class BloomSegment<T> {
    const BloomSegment({required this.value, required this.label});
    final T value;
    final String label;
  }

  class BloomSegmented<T> extends StatelessWidget {
    const BloomSegmented({
      super.key,
      required this.segments,   // 2+ entries
      required this.selected,
      required this.onChanged,
    });
    final List<BloomSegment<T>> segments;
    final T selected;
    final ValueChanged<T> onChanged;
  }
  ```
  A pill container (`c.surface2`, `border`, `BloomRadii.pill`, `padding: EdgeInsets.all(3)`) holding a `Row` of equal-flex segments. Each segment = `Expanded(child: <interactive>)` where the interactive is `Container(decoration: BoxDecoration(color: isSelected ? c.accent : Colors.transparent, borderRadius: BorderRadius.circular(BloomRadii.pill))) > Material(transparent) > InkWell(onTap: () => onChanged(seg.value), borderRadius: pill) > Padding(vertical: BloomSpacing.sm, horizontal: BloomSpacing.md) > Center(Text(seg.label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? c.accentInk : c.inkSoft)))`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_segmented.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

const _segs = [
  BloomSegment(value: 1, label: 'Một'),
  BloomSegment(value: 2, label: 'Hai'),
  BloomSegment(value: 3, label: 'Ba'),
];

void main() {
  testWidgets('renders one label per segment', (tester) async {
    await tester.pumpWidget(_host(BloomSegmented<int>(segments: _segs, selected: 2, onChanged: (_) {})));
    for (final l in ['Một', 'Hai', 'Ba']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('the selected segment label is drawn in accentInk, others in inkSoft', (tester) async {
    await tester.pumpWidget(_host(BloomSegmented<int>(segments: _segs, selected: 2, onChanged: (_) {})));
    expect(tester.widget<Text>(find.text('Hai')).style!.color, BloomColors.light.accentInk);
    expect(tester.widget<Text>(find.text('Một')).style!.color, BloomColors.light.inkSoft);
  });

  testWidgets('tapping a segment reports its value', (tester) async {
    int? got;
    await tester.pumpWidget(_host(BloomSegmented<int>(segments: _segs, selected: 1, onChanged: (v) => got = v)));
    await tester.tap(find.text('Ba'));
    expect(got, 3);
  });

  testWidgets('works with an enum value type', (tester) async {
    await tester.pumpWidget(_host(BloomSegmented<ThemeMode>(
      segments: const [
        BloomSegment(value: ThemeMode.light, label: 'Sáng'),
        BloomSegment(value: ThemeMode.dark, label: 'Tối'),
        BloomSegment(value: ThemeMode.system, label: 'Hệ thống'),
      ],
      selected: ThemeMode.system,
      onChanged: (_) {},
    )));
    expect(find.text('Hệ thống'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — FAIL.** `flutter test test/core/theme/bloom/bloom_segmented_test.dart`

- [ ] **Step 3: Implement.** Add `export 'bloom_segmented.dart';` to `bloom.dart` (alphabetical — after `bloom_scaffold.dart`, before `bloom_stat_card.dart`).

- [ ] **Step 4: Run — PASS (4).** `flutter analyze` on the two files — clean.

- [ ] **Step 5: `dart format`.**

- [ ] **Step 6: Commit**
```bash
git add lib/core/theme/bloom/bloom_segmented.dart lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_segmented_test.dart
git commit -m "feat(bloom): BloomSegmented<T> pill segmented control

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 3: BloomNavCard (extract the duplicated hub cards)

**Files:**
- Create: `lib/core/theme/bloom/bloom_nav_card.dart`, `test/core/theme/bloom/bloom_nav_card_test.dart`
- Modify: `lib/core/theme/bloom/bloom.dart`; `lib/features/reading/presentation/screens/reading_hub_screen.dart`; `lib/features/listening/presentation/screens/listening_home_screen.dart`; `lib/features/practice/presentation/screens/practice_hub_screen.dart`
- Test: `reading_hub_screen_test.dart`, `listening_home_screen_test.dart`, `practice_hub_screen_test.dart` (finder swaps only)

**Interfaces:**
- Consumes: `context.bloom`, `BloomCard`, `BloomRadii`.
- Produces (the byte-identical body of the current `_ReadingCard` / `_ListeningCard`, plus `_HubCard`'s optional `selected`):
  ```dart
  class BloomNavCard extends StatelessWidget {
    const BloomNavCard({
      super.key,
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
  }
  ```
  `BloomCard(selected: selected, onTap: onTap, child: Row([<40×40 icon tile: color selected ? c.surface : c.sageBg, BloomRadii.md, Icon(icon, size 20, color selected ? c.accent : c.sage)>, SizedBox(width: 14), Expanded(Column(crossAxisAlignment: start, [Text(title, 15 · w700 · ink), SizedBox(height: 2), Text(subtitle, 12.5 · inkSoft)])), Icon(Icons.chevron_right, color: c.inkFaint)]))` — copy verbatim from `practice_hub_screen.dart:57-111` `_HubCard` (it is the superset).

- [ ] **Step 1: Write the failing test** — 3 tests: renders title/subtitle/icon; `onTap` fires on tap; `selected: true` sets the `BloomCard.selected` flag (`tester.widget<BloomCard>(find.byType(BloomCard)).selected` is `true`).

- [ ] **Step 2: Run — FAIL.**

- [ ] **Step 3: Implement.** Add `export 'bloom_nav_card.dart';` to `bloom.dart` (after `bloom_mc_option.dart`, before `bloom_passage_sheet.dart`).

- [ ] **Step 4: Migrate the 3 call sites.**
  - `reading_hub_screen.dart` — delete `_ReadingCard` (lines ~58–109), replace every `_ReadingCard(...)` with `BloomNavCard(...)` (same args). Add the barrel import if not already present.
  - `listening_home_screen.dart` — delete `_ListeningCard`, replace `_ListeningCard(...)` → `BloomNavCard(...)`.
  - `practice_hub_screen.dart` — delete `_HubCard`, replace `_HubCard(...)` → `BloomNavCard(...)` (keep the `selected:` arg on the SM-2 card).

- [ ] **Step 5: Update the 3 screen tests** — `find.byType(_ReadingCard)` etc. aren't referenceable (private); the tests use `find.text(<title>)` / navigation assertions, which pass unchanged. If any asserts `find.byType(BloomCard)` counts, that still holds (`BloomNavCard` renders one `BloomCard`). Add nothing.

- [ ] **Step 6: Run** `flutter test test/features/reading/presentation/screens/reading_hub_screen_test.dart test/features/listening/presentation/screens/listening_home_screen_test.dart test/features/practice/presentation/screens/practice_hub_screen_test.dart test/core/theme/bloom/bloom_nav_card_test.dart` — all pass. `flutter analyze` — 10, no new. `dart format` the touched files.

- [ ] **Step 7: Commit**
```bash
git add lib/core/theme/bloom/bloom_nav_card.dart lib/core/theme/bloom/bloom.dart lib/features/reading/presentation/screens/reading_hub_screen.dart lib/features/listening/presentation/screens/listening_home_screen.dart lib/features/practice/presentation/screens/practice_hub_screen.dart test/core/theme/bloom/bloom_nav_card_test.dart
git commit -m "refactor(bloom): extract BloomNavCard from the 3 duplicated hub cards

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 4: C2 — practice area

**Files:**
- Modify: `lib/features/practice/domain/use_cases/generate_exercise_use_case.dart`; `lib/features/practice/presentation/providers/practice_session_provider.dart`
- Test: `test/features/practice/domain/use_cases/generate_exercise_use_case_test.dart`; `test/features/practice/presentation/providers/practice_session_provider_test.dart` (only if it references `aiEnabled` — grep first)

**Interfaces:**
- `GenerateExerciseUseCase.execute` drops its `{required bool aiEnabled}` param → `Future<Exercise> execute(VocabRecord record) async { try { return await _source.generate(record); } catch (_) { return FlashcardExercise(vocabRecord: record); } }`.
- `practice_session_provider._generateAt` — replace `final aiEnabled = ref.read(userSettingsNotifierProvider).aiEnabled;` with `final aiAvailable = ref.read(userSettingsNotifierProvider).aiAvailable;`. `_pickExercise(VocabRecord word, bool aiEnabled)` → `_pickExercise(VocabRecord word, bool aiAvailable)`; its `if (word.sm2Repetitions == 0 || !aiEnabled)` → `|| !aiAvailable`; the `.execute(word, aiEnabled: aiEnabled)` call → `.execute(word)`.

- [ ] **Step 1: Edit `generate_exercise_use_case.dart`** — drop the param + the `if (!aiEnabled) return ...` line (the `try/catch` fallback already covers the no-key case: `_source.generate` on a keyless provider throws → `FlashcardExercise`).

- [ ] **Step 2: Edit `practice_session_provider.dart`** per the interface above.

- [ ] **Step 3: Update `generate_exercise_use_case_test.dart`.** Spec §Testing: delete `test('returns FlashcardExercise immediately when aiEnabled=false')`; from the other two drop the `aiEnabled: true` arg (`useCase.execute(testRecord)`). The "source throws → FlashcardExercise" test stays as the fallback coverage. Add one test: `test('returns FlashcardExercise when the source returns a Flashcard (keyless provider path)')` OR keep it at 2 tests — the fallback test already proves the keyless behavior since a keyless `generate` throws. 2 tests is fine.

- [ ] **Step 4: Check `practice_session_provider_test.dart`** — grep for `aiEnabled`. If a test sets `aiEnabled: false` to force the flashcard path, convert it to the C2 harness pattern (no `apiKeyCiphertext`). If it doesn't touch the flag, leave it.

- [ ] **Step 5: Run** `flutter test test/features/practice/` — all pass. `flutter analyze` — 10, no new. `dart format`.

- [ ] **Step 6: Commit**
```bash
git add lib/features/practice/domain/use_cases/generate_exercise_use_case.dart lib/features/practice/presentation/providers/practice_session_provider.dart test/features/practice/
git commit -m "refactor(practice): drop aiEnabled from exercise generation (infer from key)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 5: C2 — dictionary area

**Files:**
- Modify: `lib/features/dictionary/presentation/widgets/search_bar_widget.dart`; `lib/features/dictionary/presentation/providers/lookup_provider.dart`; `lib/features/dictionary/domain/use_cases/lookup_use_case.dart`; `lib/features/dictionary/domain/repositories/dictionary_repository.dart`; `lib/features/dictionary/data/repositories/dictionary_repository_impl.dart`
- Test: `test/features/dictionary/domain/use_cases/lookup_use_case_test.dart` (+ regen `lookup_use_case_test.mocks.dart`); `test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart`; `test/features/dictionary/presentation/widgets/search_bar_widget_test.dart`

**Interfaces:**
- `search_bar_widget.dart` — `final aiEnabled = ref.watch(userSettingsNotifierProvider.select((s) => s.aiEnabled));` → `final aiAvailable = ref.watch(userSettingsNotifierProvider.select((s) => s.aiAvailable));`; `if (aiEnabled) ...[` (gates the "Khám phá" button) → `if (aiAvailable) ...[`.
- `lookup_provider.dart` — `aiEnabled: settings.aiEnabled,` (arg to `useCase.execute`) → `aiAvailable: settings.aiAvailable,`; `if (!settings.aiEnabled) return;` (start of `discover()`) → `if (!settings.aiAvailable) return;`; the hard-coded `aiEnabled: true,` in `discover()`'s `useCase.execute` → `aiAvailable: true,`.
- `lookup_use_case.dart` — `execute({..., required bool aiEnabled})` → `required bool aiAvailable`; body `aiEnabled: aiEnabled` (to `_repository.lookup`) → `aiAvailable: aiAvailable`.
- `dictionary_repository.dart` (abstract) — `lookup({..., required bool aiEnabled})` → `required bool aiAvailable`.
- `dictionary_repository_impl.dart` — `required bool aiEnabled` → `required bool aiAvailable`; `if (aiEnabled) { return geminiSource.lookup(...` → `if (aiAvailable) {`.

- [ ] **Step 1: Edit the 5 lib files** — pure `aiEnabled` → `aiAvailable` rename (param names, the `.select`, the two gates). No logic change.

- [ ] **Step 2: Regenerate the mockito mock** — `dart run build_runner build --delete-conflicting-outputs` (the repo's codegen command; check `pubspec.yaml` / an existing `.g.dart` header for the exact invocation). The `MockDictionaryRepository` / `MockLookupUseCase` in `lookup_use_case_test.mocks.dart` pick up the renamed param.

- [ ] **Step 3: Update the tests** — `lookup_use_case_test.dart` (`:36,:42,:48,:57,:70`) and `dictionary_repository_impl_test.dart` (`:64,:81,:97,:114`): rename the named arg `aiEnabled:` → `aiAvailable:` at every call. `search_bar_widget_test.dart` — its `_build({required bool aiEnabled})` + `SharedPreferences.setMockInitialValues({'ai_enabled': aiEnabled})` → the C2 harness pattern (`aiAvailable`, `providerConfigs` with/without `apiKeyCiphertext`), test bodies keep `aiAvailable: true/false`.

- [ ] **Step 4: Run** `flutter test test/features/dictionary/` — all pass. `flutter analyze` — 10, no new. `dart format`.

- [ ] **Step 5: Commit** (include the regenerated `.mocks.dart`)
```bash
git add lib/features/dictionary/ test/features/dictionary/
git commit -m "refactor(dictionary): rename aiEnabled -> aiAvailable through the lookup chain

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 6: C2 — word_radar area

**Files:**
- Modify: `lib/features/word_radar/presentation/providers/word_radar_provider.dart`; `lib/features/word_radar/presentation/widgets/result_suggestions_section.dart`
- Test: `test/features/word_radar/presentation/providers/word_radar_provider_test.dart`; `test/features/word_radar/presentation/widgets/result_suggestions_section_test.dart`; `test/features/word_radar/presentation/screens/word_radar_screen_test.dart`

**Interfaces:**
- `word_radar_provider.dart:36` — `if (!settings.aiEnabled) { state = WordRadarState(knownRecords: knownRecords, aiResult: null); return; }` → `if (!settings.aiAvailable) {`.
- `word_radar_provider.dart:61` — `if (!settings.aiEnabled) return;` (in `retrySuggestions`) → `if (!settings.aiAvailable) return;`.
- `result_suggestions_section.dart:43` — `if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;` → `.aiAvailable`.

- [ ] **Step 1: Edit the 3 gates** — pure `aiEnabled` → `aiAvailable`.

- [ ] **Step 2: Update the 3 test files** — `word_radar_provider_test.dart` (`:116` param, `:128` `.copyWith`, `:146…` `false`, `:190…` `true`) → C2 harness pattern. `result_suggestions_section_test.dart` (`:28,:37,:62,:97,:120,:143`) → same. `word_radar_screen_test.dart` — the `_build({required bool aiEnabled})` harness (`:112,:139`, all the `aiEnabled: true/false` call sites) → C2 harness pattern; **keep** `word_radar_screen_test.dart:168` `expect(find.textContaining('Bật AI trong Cài đặt'), findsOneWidget)` — that assertion is on `word_radar_screen.dart`'s own `radarState.aiResult == null` branch text `'Bật AI trong Cài đặt để nhận gợi ý từ mới.'`, which is **frozen** (not an `AiKeyMissingCard`, not touched by C2). It still shows when `aiAvailable` is false, so the test still passes once the harness sets no key.

- [ ] **Step 3: Run** `flutter test test/features/word_radar/` — all pass. `flutter analyze` — 10, no new. `dart format`.

- [ ] **Step 4: Commit**
```bash
git add lib/features/word_radar/ test/features/word_radar/
git commit -m "refactor(word-radar): gate suggestions on aiAvailable

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 7: HomeNoticeCard rename + AiKeyMissingCard + the 6 AI-gate home screens

**Files:**
- Rename: `lib/core/widgets/ai_disabled_card.dart` → `lib/core/widgets/home_notice_card.dart` (`AiDisabledCard` → `HomeNoticeCard`); `test/core/widgets/ai_disabled_card_test.dart` → `test/core/widgets/home_notice_card_test.dart`
- Create: `lib/core/widgets/ai_key_missing_card.dart`, `test/core/widgets/ai_key_missing_card_test.dart`
- Modify: `reading_home_screen.dart`, `part5_home_screen.dart`, `part6_home_screen.dart`, `part7_home_screen.dart`, `comprehension_home_screen.dart`, `dictation_home_screen.dart`
- Test: `reading_home_screen_test.dart`, `part5_home_screen_test.dart`, `part6_home_screen_test.dart`, `part7_home_screen_test.dart`, `comprehension_home_screen_test.dart`, `dictation_home_screen_test.dart`

**Interfaces:**
- `HomeNoticeCard` — identical to the current `AiDisabledCard`: `const HomeNoticeCard({super.key, required this.message})`, same `Container` (dangerBg / danger border / `BloomRadii.md` / `BloomSpacing.lg` padding / `Text(message, color: c.danger)`). Pure rename.
- `AiKeyMissingCard` — `const AiKeyMissingCard({super.key})`. Renders (uses `context.go`, so import `go_router`):
  ```dart
  final c = context.bloom;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BloomSpacing.lg),
    decoration: BoxDecoration(
      color: c.dangerBg,
      border: Border.all(color: c.danger),
      borderRadius: BorderRadius.circular(BloomRadii.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.',
            style: TextStyle(color: c.danger)),
        const SizedBox(height: BloomSpacing.md),
        BloomPillButton(
          label: 'Mở Cài đặt',
          variant: BloomButtonVariant.secondary,
          onPressed: () => context.go('/settings'),
        ),
      ],
    ),
  );
  ```

- [ ] **Step 1: Rename `ai_disabled_card.dart` → `home_notice_card.dart`** (`git mv`), rename the class `AiDisabledCard` → `HomeNoticeCard`, update its doc comment ("A danger-tinted notice for home screens — not-enough-words, unsupported-language, …"). `git mv` the test file, rename all `AiDisabledCard` → `HomeNoticeCard` in it.

- [ ] **Step 2: Create `ai_key_missing_card.dart`** per the interface. Create `ai_key_missing_card_test.dart` — 2 tests: renders the exact message string; tapping "Mở Cài đặt" routes to `/settings` (host it in a tiny `GoRouter` with a `/settings` stub).

- [ ] **Step 3: The 6 home screens.** For EACH:
  - The AI-off branch: change `if (!settings.aiEnabled)` → `if (!settings.aiAvailable)` and swap `AiDisabledCard(message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.')` → `const AiKeyMissingCard()`.
  - The **other** branches (`reading_home_screen.dart:194` "Hãy lưu ít nhất 5 từ…"; `comprehension_home_screen.dart:120` / `dictation_home_screen.dart:186` unsupported-language; `dictation_home_screen.dart:193` "Hãy lưu ít nhất 2 từ…") → `AiDisabledCard(message: ...)` becomes `HomeNoticeCard(message: ...)` — **same strings**.

- [ ] **Step 4: The 6 home-screen tests.** Each has a "shows AI disabled message when aiEnabled is false" test (e.g. `comprehension_home_screen_test.dart:39`). Convert the harness to the C2 pattern (`aiAvailable`, `providerConfigs`). The assertion — currently `find.textContaining('Tính năng này yêu cầu AI')` or similar — must change to the new copy: `find.textContaining('Chưa có API key cho nhà cung cấp AI')` and/or `find.byType(AiKeyMissingCard)`. Rename the test to "shows the missing-API-key card when no key is set". The "not enough words" / "unsupported language" assertions stay (they now find `HomeNoticeCard` — if a test does `find.byType(AiDisabledCard)`, swap to `find.byType(HomeNoticeCard)`; the `find.textContaining(<message>)` ones are unchanged).

- [ ] **Step 5: Run** `flutter test test/features/reading/ test/features/listening/ test/core/widgets/` — all pass. `flutter analyze` — 10, no new. `dart format` all touched files.

- [ ] **Step 6: Commit**
```bash
git add lib/core/widgets/ lib/features/reading/presentation/screens/ lib/features/listening/presentation/screens/ test/core/widgets/ test/features/reading/ test/features/listening/
git commit -m "feat(ai): AiKeyMissingCard with a Settings link; rename AiDisabledCard -> HomeNoticeCard

Home AI gates now read settings.aiAvailable.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 8: C2 finalize — delete the `aiEnabled` field

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`; `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Test: `test/features/dictionary/domain/entities/user_settings_state_test.dart`; `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`; `test/features/vocabulary/presentation/providers/vocab_bank_provider_test.dart`

**Interfaces:**
- `user_settings_state.dart` — remove: ctor `required this.aiEnabled,` (line 11); field `final bool aiEnabled;` (22); `copyWith` param `bool? aiEnabled,` (45); `copyWith` body `aiEnabled: aiEnabled ?? this.aiEnabled,` (56); `defaults` `aiEnabled: false,` (70). **Keep** the `aiAvailable` getter and update its doc comment (drop the "being retired in a later plan" clause → "AI is usable iff the active provider has a stored key ciphertext — mirrors the web.").
- `user_settings_provider.dart` — remove `build()`'s `aiEnabled: prefs.getBool('ai_enabled') ?? false,` (line ~117); remove the whole `setAiEnabled` method (137–140).

- [ ] **Step 1: Confirm nothing reads `aiEnabled` any more.** `grep -rn "aiEnabled\|'ai_enabled'\|setAiEnabled" lib/` — MUST return zero hits before editing (Tasks 4–7 removed them all). If any remain, STOP and report — a prior task missed one.

- [ ] **Step 2: Delete the field + method + prefs load** per the interface.

- [ ] **Step 3: Update the tests.**
  - `user_settings_state_test.dart:21` — `start.copyWith(aiEnabled: true)` (used as "some other field" to prove `themePreference` survives) → `start.copyWith(reminderEnabled: true)`.
  - `user_settings_notifier_test.dart:83` — `expect(state.aiEnabled, false);` → delete that line. `:94` initial-value `'ai_enabled': true` → delete the key. `:102` `expect(state.aiEnabled, true);` → delete. (Keep the rest of both tests — they still assert `activeProvider` / config loading.)
  - `vocab_bank_provider_test.dart:26` — the full `UserSettingsState(... aiEnabled: false, ...)` ctor → drop the `aiEnabled: false,` line.

- [ ] **Step 4: Run** `flutter test` (full suite — every `.copyWith(aiEnabled:)` in any test would now be a compile error, so a green full run is the proof C2 is complete). `flutter analyze` — 10, no new. `dart format`.

- [ ] **Step 5: Commit**
```bash
git add lib/features/dictionary/domain/entities/user_settings_state.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart test/
git commit -m "refactor(settings): remove the aiEnabled field and its persistence (C2 complete)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 9: Settings screen → Bloom (+ delete AI toggle, + Giao diện section)

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Create: `test/features/settings/presentation/screens/settings_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomSectionHeader`, `BloomSwitch`, `BloomSegmented` (+`BloomSegment`), `BloomPillButton` (+`BloomButtonVariant`), `BloomTextField`, `FilterTile`, `showSingleSelectSheet` + `SelectOption`, `context.bloom`. Import `go_router` only if a nav is added (none needed — Settings is a bottom-nav tab).
- Frozen: every `notifier.set*` call, `authNotifierProvider` reads + `signOut()`, `_showApiKeyDialog` / `_showTimePicker` flow, `ApiKeyEncryptor` usage in `_ApiKeyDialog._save`, `settings.activeConfig` / `activeProvider` / `providerConfigs` reads, `_ModelTile`'s preset/custom logic.

- [ ] **Step 1: Restyle `SettingsScreen.build`.**
  - `Scaffold` → `BloomScaffold`; `AppBar(title: Text('Cài đặt'), automaticallyImplyLeading: false)` → `BloomAppBar(title: 'Cài đặt', automaticallyImplyLeading: false)`.
  - Body: `ListView(padding: const EdgeInsets.all(16))` of **`BloomCard`-per-section**. Each section: `BloomCard(child: Column(crossAxisAlignment: stretch, [BloomSectionHeader('<name>'), <rows>]))`.
  - `_SectionHeader` (the private widget) → delete; use `BloomSectionHeader` (it uppercases — sections become "TÀI KHOẢN" / "AI" / "HỌC TẬP" / "THÔNG BÁO" / "GIAO DIỆN").
  - **"AI" section:** DELETE the `SwitchListTile('Bật AI')` (lines 48–53) AND the `if (settings.aiEnabled) ...[` wrapper (line 54, closes ~100) — the Provider picker, `_ModelTile`, and API Key row now render **unconditionally**.
    - Provider `SegmentedButton<AiProvider>` → `BloomSegmented<AiProvider>(segments: AiProvider.values.map((p) => BloomSegment(value: p, label: p.label)).toList(), selected: settings.activeProvider, onChanged: notifier.setActiveProvider)`.
    - `_ModelTile`'s `ListTile` → a `FilterTile(icon: Icons.psychology_outlined, label: 'Model', value: currentModel, onTap: () => _showModelPicker(...))`.
    - API Key `ListTile` → `FilterTile(icon: Icons.key_outlined, label: 'API Key', value: <'Đã cài đặt' / 'Chưa cài đặt'>, onTap: () => _showApiKeyDialog(...))`.
  - **"Học tập" section:** the two `ListTile`s → `FilterTile(icon:, label:, value:, onTap:)` (Ngôn ngữ mục tiêu → `_pickLanguage`; Cấp độ mục tiêu → `_showCefrPicker`).
  - **"Thông báo" section:** `SwitchListTile('Nhắc nhở hàng ngày')` → `BloomSwitch(title: 'Nhắc nhở hàng ngày', subtitle: 'Thông báo khi có từ cần ôn', value: settings.reminderEnabled, onChanged: (v) => notifier.setReminderEnabled(enabled: v))`. The `if (settings.reminderEnabled)` "Giờ nhắc cố định" `ListTile` → `FilterTile(icon: Icons.schedule, label: 'Giờ nhắc cố định', value: '<HH:MM>', onTap: () => _showTimePicker(...))`.
  - **NEW "Giao diện" section** (add after "Học tập", before "Thông báo"): `BloomCard(child: Column(crossAxisAlignment: stretch, [BloomSectionHeader('Giao diện'), Text('Chủ đề', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.bloom.inkSoft)), SizedBox(height: BloomSpacing.sm), BloomSegmented<ThemeMode>(segments: const [BloomSegment(value: ThemeMode.light, label: 'Sáng'), BloomSegment(value: ThemeMode.dark, label: 'Tối'), BloomSegment(value: ThemeMode.system, label: 'Hệ thống')], selected: settings.themePreference, onChanged: notifier.setThemePreference)]))`.

- [ ] **Step 2: `_SignedInSection`** — `ListTile` → a `Row` inside the "Tài khoản" `BloomCard`: a 44px gradient `CircleAvatar` (keep `NetworkImage(user.photoURL)` when present; fallback = `Container(decoration: BoxDecoration(gradient: BloomGradients.leafMark(context.bloom), shape: BoxShape.circle), child: Center(Text(<initial>, color: context.bloom.accentInk, w800)))`), then `Expanded(Column(crossAxisAlignment: start, [Text(displayName, w700 ink), Text(email, inkSoft)]))`, then `BloomPillButton(label: 'Đăng xuất', variant: BloomButtonVariant.danger, onPressed: onSignOut)`. The `loading:` `LinearProgressIndicator` stays raw; `error:` → `Text('Lỗi xác thực', style: TextStyle(color: context.bloom.danger))`.

- [ ] **Step 3: `_showCefrPicker` + `_ModelTile._showModelPicker`** — replace the hand-rolled `showModalBottomSheet` + `RadioListTile` lists with `showSingleSelectSheet<T>`:
  - CEFR: `final picked = await showSingleSelectSheet<CEFRLevel?>(context: context, title: 'Cấp độ mục tiêu', options: [const SelectOption(value: null, label: 'Tất cả'), ...CEFRLevel.values.map((l) => SelectOption(value: l, label: l.label))], selected: current); if (picked != null) notifier.setTargetCefrLevel(picked.value);` — note `showSingleSelectSheet` returns the `SelectOption?` (null on dismiss); `picked.value` can itself be `null` for "Tất cả", which is the intended `setTargetCefrLevel(null)`.
  - Model: `showSingleSelectSheet<String>(context: context, title: 'Model', options: presets.map((m) => SelectOption(value: m, label: m)).toList(), selected: currentModel)` → on a non-null pick call `onModelChanged(picked.value)`. Keep a separate trailing "Khác…" affordance that opens `_showCustomModelDialog` — either a `BloomPillButton(variant: link, label: 'Nhập model khác…')` shown under the FilterTile, or append a `SelectOption(value: '__custom__', label: 'Khác…')` and branch on it. Pick the `BloomPillButton` approach (cleaner, no sentinel).
  - **This removes all 8 `RadioListTile` analyze infos in this file.**

- [ ] **Step 4: `_ApiKeyDialog` + `_CustomModelDialog`** — keep them `AlertDialog` (`showDialog`), but the inner `TextField` → `BloomTextField(controller: _ctrl, obscureText: <true for api key>, hintText: <same>, enabled: !_saving)`. `_ApiKeyDialog`'s inline `_error` stays a sibling `Text(_error!, style: TextStyle(color: context.bloom.danger))` (BloomTextField has no error slot). The `FilledButton`/`TextButton` actions → keep as Material `TextButton`/`FilledButton` (they're inside an `AlertDialog` whose theme is Bloom-mapped) OR `BloomPillButton` — use `BloomPillButton(label: 'Lưu', ...)` + `BloomPillButton(label: 'Huỷ', variant: link, ...)` for consistency; keep the in-button `CircularProgressIndicator` for `_saving`.

- [ ] **Step 5: Write `settings_screen_test.dart`** — new harness: `ProviderScope` overriding `userSettingsNotifierProvider` (a fake notifier or `sharedPreferencesProvider` + real notifier), `authNotifierProvider` (an `AsyncData(null)` / `AsyncData(fakeUser)`), inside `MaterialApp` (no router needed — no nav). Model on `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`'s container setup + any existing screen test for the `MaterialApp` wrap. Tests:
  1. renders all 5 section headers (`TÀI KHOẢN`, `AI`, `HỌC TẬP`, `GIAO DIỆN`, `THÔNG BÁO`).
  2. **no "Bật AI" toggle** — `expect(find.text('Bật AI'), findsNothing)`; the Provider `BloomSegmented`, Model `FilterTile`, API Key `FilterTile` are **always** visible (even with no key set).
  3. the Giao diện `BloomSegmented<ThemeMode>` shows the current `themePreference` selected; tapping "Tối" calls `setThemePreference(ThemeMode.dark)` (verify via a fake notifier spy or by reading the container's settings state after).
  4. tapping the Provider segment for a different provider calls `setActiveProvider`.
  5. signed-in: shows the display name + email + an "Đăng xuất" `BloomPillButton`; tapping it calls `signOut()`.
  6. signed-out (`authAsync` data null): the "Tài khoản" card shows nothing / a placeholder (match current `SizedBox.shrink()` behavior).

- [ ] **Step 6: Run** `flutter test test/features/settings/ test/features/dictionary/` — all pass. `flutter analyze` — **must be 2** (only `selection_sheets.dart:79,82` left). `dart format`.

- [ ] **Step 7: Commit**
```bash
git add lib/features/settings/presentation/screens/settings_screen.dart test/features/settings/presentation/screens/settings_screen_test.dart
git commit -m "feat(settings): Bloom settings screen; drop the Bật AI toggle; add the Giao diện theme picker

Provider/Model/API-key rows always visible. CEFR + model pickers use showSingleSelectSheet
(removes 8 RadioListTile deprecation infos). analyze: 2 (was 10).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 10: Sign-in screen → Bloom

**Files:**
- Modify: `lib/features/settings/presentation/screens/sign_in_screen.dart`
- Create: `test/features/settings/presentation/screens/sign_in_screen_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomLeafMark`, `BloomPillButton` (+`BloomButtonVariant`), `context.bloom`.
- Frozen: `_SignInScreenState` — `_Step` enum, `_signIn()` (the whole `signInWithGoogle` → `HiveMigrationService.migrateIfNeeded` → `aiSettingsSyncServiceProvider.bootstrapSync` → `context.go('/')` sequence), `_signInError` / `_migrationError` strings, `authNotifierProvider` / `FirebaseAuth.instance.currentUser` reads.

- [ ] **Step 1: Restyle `build`.**
  - `Scaffold` → `BloomScaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [...]))))`.
  - Branding: `Row(mainAxisSize: MainAxisSize.min, children: [const BloomLeafMark(size: 40), const SizedBox(width: 12), Text('LexiCore', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: context.bloom.ink))])` — replaces the bare `Text('LexiCore', fontSize: 28, bold)`.
  - Subtitle `Text` → `style: TextStyle(color: context.bloom.inkSoft)`.
  - `FilledButton.icon(onPressed: _signIn, icon: Icon(Icons.login), label: Text('Đăng nhập với Google'))` → `BloomPillButton(label: 'Đăng nhập với Google', icon: Icons.login, variant: BloomButtonVariant.primary, onPressed: _signIn)`.
  - `OutlinedButton('Thử lại')` → `BloomPillButton(label: 'Thử lại', variant: BloomButtonVariant.secondary, onPressed: _signIn)`.
  - `CircularProgressIndicator` (loading) stays raw.
  - The two error `Text(... color: Colors.red)` → `color: context.bloom.danger`.

- [ ] **Step 2: Write `sign_in_screen_test.dart`** — harness: `ProviderScope` overriding `authNotifierProvider` with a fake whose `signInWithGoogle` is a spy, inside a `GoRouter` (`/sign-in` → `SignInScreen`, `/` stub) + `MaterialApp.router`. (Check what other deps `_signIn` touches: `aiSettingsSyncServiceProvider`, `userSettingsNotifierProvider`, and `HiveMigrationService` is `new`'d directly — that's the hard one. If `HiveMigrationService.migrateIfNeeded` can't be faked without a seam, keep the tests to the **pre-signin UI only**: (1) renders `BloomLeafMark` + "LexiCore" + "Đăng nhập để tiếp tục" + the Google `BloomPillButton`; (2) tapping the button calls `signInWithGoogle` (spy) and shows the `CircularProgressIndicator`. Do NOT try to drive the full migration flow — report it as a known coverage gap.) Tests:
  1. renders the leaf mark, title, subtitle, and the "Đăng nhập với Google" `BloomPillButton`.
  2. tapping the button invokes `authNotifierProvider.notifier.signInWithGoogle` and swaps to the loading spinner.
  3. a `_signInError` (simulate by making the spy throw) shows `'Đăng nhập thất bại. Thử lại.'` in `context.bloom.danger` and a "Thử lại" button.

- [ ] **Step 3: Run** `flutter test test/features/settings/` — all pass. `flutter analyze` — 2, no new. `dart format`.

- [ ] **Step 4: Commit**
```bash
git add lib/features/settings/presentation/screens/sign_in_screen.dart test/features/settings/presentation/screens/sign_in_screen_test.dart
git commit -m "feat(auth): Bloom sign-in screen (leaf mark + pill button + gradient ground)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 11: Speed selectors → BloomSegmented

**Files:**
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`; `lib/features/listening/presentation/screens/comprehension_session_screen.dart`
- Test: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`; `test/features/listening/presentation/screens/comprehension_session_screen_test.dart`

**Interfaces:**
- Both files have a private `_SpeedSelector` wrapping `SegmentedButton<double>` over `{0.75, 1.0, 1.25}` (`dictation_session_screen.dart:~369`, `comprehension_session_screen.dart:~267`). Frozen: the `speed: session.speedMultiplier` read and the `onChanged: notifier.setSpeed` wiring.

- [ ] **Step 1: Replace `SegmentedButton<double>` in `_SpeedSelector`** (both files, same change) with:
  ```dart
  BloomSegmented<double>(
    segments: const [
      BloomSegment(value: 0.75, label: '0.75×'),
      BloomSegment(value: 1.0, label: '1×'),
      BloomSegment(value: 1.25, label: '1.25×'),
    ],
    selected: speed,   // the widget's existing `speed` field
    onChanged: onChanged, // the existing `onChanged` (== notifier.setSpeed)
  )
  ```
  Keep whatever label / `Row` wraps `_SpeedSelector` today. Match the segment labels to the current `SegmentedButton` labels — read them (they may be `'0.75x'` lowercase-x or `'0,75'`); reproduce exactly so any `find.text` in the tests still matches.

- [ ] **Step 2: Update the 2 test files.** Both have a `group('speed selector')` with `tester.widget<SegmentedButton<double>>(find.byType(SegmentedButton<double>))` (dictation `:419,:432`; comprehension `:200,:214`). Change to `find.byType(BloomSegmented<double>)` and re-express the assertion: the old tests read `.selected` (a `Set<double>`) and/or tap a segment then check `notifier.setSpeed` was called. New: `tester.widget<BloomSegmented<double>>(find.byType(BloomSegmented<double>)).selected` is a bare `double`; to drive a change, `await tester.tap(find.text('1.25×'))` and assert the fake notifier's `setSpeed` spy saw `1.25`. **Keep the behavior assertion** (a speed tap calls `setSpeed` with the right value).

- [ ] **Step 3: Run** `flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart` — all pass. `flutter analyze` — 2, no new (no `SegmentedButton` left in these files). `dart format`.

- [ ] **Step 4: Commit**
```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart lib/features/listening/presentation/screens/comprehension_session_screen.dart test/features/listening/presentation/screens/dictation_session_screen_test.dart test/features/listening/presentation/screens/comprehension_session_screen_test.dart
git commit -m "feat(listening): speed selectors use BloomSegmented

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 12: RadioGroup migration + carried Minor cleanups

**Files:**
- Modify: `lib/core/widgets/selection_sheets.dart`; `lib/core/theme/bloom/bloom_bar_chart.dart`; `lib/features/word_radar/presentation/screens/word_radar_screen.dart`
- Test: `test/core/widgets/selection_sheets_test.dart` (if it exists — check); `test/core/theme/bloom/bloom_bar_chart_test.dart`; `test/features/word_radar/presentation/screens/word_radar_screen_test.dart`

- [ ] **Step 1: `selection_sheets.dart` — kill the last 2 analyze infos.** The single-select sheet builds `RadioListTile<T>(value:, groupValue: selected, onChanged: (_) => Navigator.pop(ctx, o))`. Migrate to the Flutter-sanctioned `RadioGroup` ancestor: wrap the options `ListView`/`Column` in `RadioGroup<T>(groupValue: selected, onChanged: (v) { … }, child: …)` and change each `RadioListTile<T>` to the non-deprecated form (drop `groupValue`/`onChanged` from the tile, they move to the ancestor). Read the current Flutter docs for `RadioGroup` (`node_modules`? no — it's Flutter SDK; check `flutter doctor` version 3.41 API). If `RadioGroup` isn't available in this Flutter, the fallback is to replace `RadioListTile` with a `BloomMcOption`-style tappable row + a leading `Icon(selected == o.value ? Icons.radio_button_checked : Icons.radio_button_off, color: c.accent)`. Either way: **the multi-select sheet's `CheckboxListTile` is not deprecated — leave it.** Keep the sheet's return contract (`Future<SelectOption<T>?>`) and its Bloom styling identical.

- [ ] **Step 2: `bloom_bar_chart.dart` — center the value caption + tidy the magic px.** The per-bar value `Text` sits in a bare `SizedBox(height: 14)`. Wrap it in `Center(child: ...)` (or `Align(alignment: Alignment.bottomCenter)`) so the number sits centered above the bar (web `.dash-chart-value` is `left: 50%; translateX(-50%)`). Give the caption `TextStyle` a `height: 1.0` so it can't clip in the 14px slot. Replace the two literals with named consts at the top of the file: `const _captionSlot = 14.0; const _labelGap = 6.0;` (they're chart-internal geometry, not `BloomSpacing` — a short comment says so). Re-run `bloom_bar_chart_test.dart` — the 4 tests are text/color assertions, unaffected; add one: `expect(find.byType(Center), findsWidgets)` is weak — instead assert the caption `Text`'s `style.height == 1.0`.

- [ ] **Step 3: `word_radar_screen.dart` — 2 headers → `BloomSectionHeader`.** Line ~111 `Text('Văn bản', style: theme.textTheme.labelLarge)` → `const BloomSectionHeader('Văn bản')`. Line ~194 `Text('Bản dịch', style: theme.textTheme.labelLarge)` → `const BloomSectionHeader('Bản dịch')`. `BloomSectionHeader` uppercases → rendered text is `VĂN BẢN` / `BẢN DỊCH`.

- [ ] **Step 4: `word_radar_screen_test.dart`** — line ~385 `expect(find.text('Bản dịch'), findsOneWidget)` → `find.text('BẢN DỊCH')`; line ~410 `expect(find.text('Bản dịch'), findsNothing)` → `find.text('BẢN DỊCH')`. No other `'Bản dịch'` / `'Văn bản'` finders.

- [ ] **Step 5: Run** `flutter test test/core/ test/features/word_radar/` — all pass. **`flutter analyze` — must be 0.** `dart format` the touched files.

- [ ] **Step 6: Commit**
```bash
git add lib/core/widgets/selection_sheets.dart lib/core/theme/bloom/bloom_bar_chart.dart lib/features/word_radar/presentation/screens/word_radar_screen.dart test/
git commit -m "chore(bloom): RadioGroup migration (analyze 0), centered bar-chart caption, Bloom headers in Word Radar

analyze: 0 (was 2).

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Task 13: Docs (spec §E)

**Files:**
- Modify: `README.md`, `CLAUDE.md`

- [ ] **Step 1: `README.md`.**
  - "Cấu hình AI" section (lines ~345–354): remove step 1 (`**Bật AI** toggle`); renumber the rest (Provider / Model / API Key).
  - Feature list: line ~34 `**Flashcard** (fallback khi AI tắt hoặc lỗi)` → `**Flashcard** (fallback khi AI lỗi hoặc chưa có key)`. Add a line under the theme/UI features: `**Chủ đề Sáng / Tối / Hệ thống** (Cài đặt → Giao diện, lưu cục bộ)`.
  - Line ~384 `> Tiếng Anh dùng Free Dictionary API, không cần AI key. Các ngôn ngữ khác yêu cầu AI bật.` → `… Các ngôn ngữ khác cần một API key AI.`
  - Line ~412 `Hiện tại: **474 tests**` → the real count after this plan (run `flutter test`, use that number).
  - Line ~462 Firestore-sync field list — remove `aiEnabled` (and `activeContext` if still listed — it was removed in Plan 2). Line ~499 Firestore schema block — remove the `aiEnabled: boolean` line.
  - Line ~108 / ~122 (security notes about AI keys) — reword only if they name the toggle; the "keys in SharedPreferences, not synced" statement is still true, leave it.
  - The stack / architecture note: spec §E wants "UI: Material 3 mặc định" → "Bloom design system (port từ bản web)". That exact string isn't present; instead update the architecture-tree comment (line ~162) `│   ├── theme/               # AppTheme (light + dark)` → `│   ├── theme/               # Bloom design system (bloom_tokens + bloom/ widgets), ported from apps/web`.

- [ ] **Step 2: `CLAUDE.md`.** The "## Theme (Flutter)" section already exists and already says the Bloom colors are ported from `bloom.css` and both files must stay in sync — verify that's still accurate; add one bullet: `- Raw Material \`SegmentedButton\` / \`Switch\` / \`RadioListTile\` are fully retired — use \`BloomSegmented\` / \`BloomSwitch\`, and \`showSingleSelectSheet\` / \`BloomMcOption\` for single-choice.` Also update the "Sáng/Tối/Hệ thống picker UI lands in a later plan" clause (it's now shipped): `- Light/dark follows \`UserSettingsState.themePreference\` (Sáng/Tối/Hệ thống), stored locally in SharedPreferences (\`theme_preference\`), not synced. The picker lives in Cài đặt → Giao diện (\`BloomSegmented\`).`

- [ ] **Step 3: No test.** `flutter analyze` (still 0), `flutter test` (unchanged count) — sanity only, no code changed.

- [ ] **Step 4: Commit**
```bash
git add README.md CLAUDE.md
git commit -m "docs: drop the Bật AI toggle; document the theme picker and retired Material widgets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- §B14 (Settings restyle + `BloomSectionHeader`/`BloomCard` per group + delete AI toggle + Giao diện `BloomSegmented` + dialogs use `BloomTextField` + `_SignedInSection` gradient avatar + danger sign-out) = Task 9. `BloomSwitch` (§A3) = Task 1; `BloomSegmented` (§A3) = Task 2. ✓
- §B15 (Sign-in: Bloom gradient, big `BloomLeafMark`, Google button as `BloomPillButton`) = Task 10. ✓
- §C2 (remove `aiEnabled`; `aiAvailable` inference; `generate_exercise_use_case` drops the param; `lookup_use_case`/`dictionary_repository*` rename; `AiDisabledCard`→`AiKeyMissingCard` + `!aiEnabled`→`!aiAvailable` on the home gates; README loses the toggle step) = Tasks 4–8 (area by area, then field deletion), Task 7 (the card + gates), Task 13 (README). ✓
- §D (theme picker UI; local-only; not synced; font-size explicitly out) = Task 9's Giao diện section. The whole `themePreference` chain already existed (Plan 1) — this plan only adds the UI. ✓
- §E (`CLAUDE.md` Theme note; `README.md` updates) = Task 13. ✓
- §A3 rows `BloomSegmented` / `BloomSwitch` / `AiKeyMissingCard` = Tasks 2 / 1 / 7. ✓
- Carried Minors from Plans 2–5 (`BloomNavCard` extraction; `BloomBarChart` caption; Word Radar `textTheme` headers; retire raw `SegmentedButton`; `RadioGroup` migration → analyze 0) = Tasks 3, 11, 12. ✓

**2. Placeholder scan:** Tasks 1–3 give full widget source. C2 tasks (4–8) list every file + every line to change, from the survey's line-numbered grep. Tasks 9–13 give explicit per-section deltas and the exact new-test list. The one soft spot is Task 10's sign-in test (the `HiveMigrationService` is `new`'d, hard to fake) — the plan explicitly caps that test's scope to the pre-signin UI and flags the migration-flow coverage gap rather than pretending it's covered.

**3. Type consistency:**
- `BloomSwitch({title, subtitle?, value, onChanged})` — used in Task 9 (reminder toggle).
- `BloomSegmented<T>({segments: List<BloomSegment<T>>, selected: T, onChanged: ValueChanged<T>})` + `BloomSegment<T>({value, label})` — used in Task 9 (`<AiProvider>`, `<ThemeMode>`) and Task 11 (`<double>`).
- `BloomNavCard({icon, title, subtitle, onTap, selected})` — used in Task 3 (3 call sites; `selected` only on practice hub's SM-2 card).
- `AiKeyMissingCard()` (no params) — Task 7, 6 sites. `HomeNoticeCard({message})` — Task 7, the non-AI sites.
- `settings.aiAvailable` (existing getter, `bool`) — the single C2 read replacement everywhere.
- Every `context.go(...)` target that appears (`/settings` in `AiKeyMissingCard`, `/` in sign-in) matches `app_router.dart` (`:362` `/settings`, root).

**4. Risk notes for the implementer:**
- **C2 ordering is load-bearing.** Tasks 4–7 flip *reads* to `aiAvailable` while the `aiEnabled` field still exists (compiles fine). Task 8 deletes the field and its Step 1 is a `grep` gate — if any reader remains, a prior task missed it; stop and fix that task, don't force Task 8.
- **Test-harness conversion** (`aiEnabled` bool → `providerConfigs` with/without `apiKeyCiphertext`) is the bulk of the C2 work and touches ~20 test files. The Global Constraints block gives the exact `providerConfigs` map to paste. Every test body keeps `aiAvailable: true/false` — only the harness plumbing changes.
- **`showSingleSelectSheet` return semantics** (Task 9 Step 3): it returns `SelectOption<T>?` — `null` means the user dismissed; a non-null `SelectOption` whose `.value` is itself `null` is the deliberate "Tất cả" CEFR pick. Branch on the outer null, then pass `.value` through.
- **`RadioGroup` availability** (Task 12): if Flutter 3.41 doesn't have `RadioGroup`, use the `BloomMcOption`-style fallback described in the task. Confirm with `flutter --version` / the SDK source before choosing.
- **`_ModelTile` custom-model affordance** (Task 9): don't use a `'__custom__'` sentinel `SelectOption` — add a separate `BloomPillButton(variant: link)` under the FilterTile.
- **Analyze target is 0** — Task 9 gets it to 2 (removes the 8 settings `RadioListTile` infos), Task 12 gets it to 0 (the last 2 in `selection_sheets`). Any task that would *add* an info fails its gate.
- **`mockito` regen** (Task 5): the exact `build_runner` command — check `pubspec.yaml`'s dev_deps and any existing `*.mocks.dart` file header for the invocation this repo uses.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-03-flutter-bloom-plan6-settings-signin-cleanup.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — a fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session with `executing-plans`, batched with checkpoints.

**Which approach?**
