# Flutter Bloom — Plan 2: Dictionary + Vocab Bank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Dictionary (Tra từ) and Vocab Bank (Ngân hàng từ) screens to the Bloom design system, and remove the global "Ngữ cảnh" (AppContext) setting + the lookup-chain `context` parameter to match the web app (spec item C1).

**Architecture:** Two web-parity refactors first (C1: drop `UserSettingsState.activeContext` and the `context` param threaded through the lookup use-case/repository/source), each landing as a build-green commit. Then screen-by-screen Bloom restyle of the dictionary widgets and both vocab screens, plus a small extension to `BloomTextField` (from Plan 1) for the properties these screens need. `AppContext` the enum stays — it's still used per-session by Reading/Listening and stored on every `VocabRecord`; only the *global setting* and the *lookup usage* go.

**Tech Stack:** Flutter 3.41 / Dart ≥3.4, `flutter_riverpod` + `riverpod_annotation` + `build_runner` codegen, `mockito` (generated mocks), `go_router` (untouched), `flutter_test`. Bloom design system from Plan 1 (`lib/core/theme/bloom/`).

## Global Constraints

- **Bloom widgets** come from the barrel `import 'package:lexi_core/core/theme/bloom/bloom.dart';` — `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomCard`, `BloomPillButton` (+`BloomButtonVariant`), `BloomChip` (+`BloomChipStyle`), `BloomCefrPill`, `BloomProgressBar`, `BloomSectionHeader`, `BloomLeafMark`, `BloomListRow`, `BloomTextField`, `BloomBottomNav`/`BloomNavRail`. Colors via `context.bloom` (a `BloomColors`; falls back to `BloomColors.light` in themeless test harnesses). Prefer Bloom widgets over raw Material on these screens.
- **Radii:** only `BloomRadii.sm=10 / md=16 / lg=20 / pill=999`. No other radius literals in new Bloom code.
- **No deprecated APIs that add `flutter analyze` issues.** This Flutter deprecates `withOpacity` → use `.withValues(alpha:)`. The repo has exactly **21 pre-existing** `flutter analyze` infos (all `RadioListTile`/`CheckboxListTile` `groupValue`/`onChanged` deprecations). After every task `flutter analyze` must still report **21** — zero new.
- **Tests:** the suite is at **625 passing** at the start of this plan. It only goes up. When a widget swap breaks a finder, fix the finder (prefer `find.text` / `find.byKey` / `find.byType(BloomX)`) — never weaken or delete a behavior assertion.
- **Codegen:** after editing any `@riverpod` provider or any file with generated `mockito` mocks (`@GenerateMocks` / `@GenerateNiceMocks`, or a `.mocks.dart` alongside), run `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated `*.g.dart` / `*.mocks.dart`.
- **No route / `go_router` / IA changes.** `apps/web/` is never touched.
- **Vietnamese-first copy.** These screens still carry English user-facing strings (`"Vocab Bank"`, `"Search words..."`, `"Save to Vocab Bank"`, `"Meaning"`, `"No words saved yet."`, …). While restyling, translate every user-facing English string on the screen you're touching to Vietnamese (values given per task). Update any test assertion on those strings in the same commit — a string-literal change, never a behavior change.
- **`aiEnabled` stays.** `UserSettingsState.aiEnabled` / `settings.aiEnabled` / `setAiEnabled` are removed in Plan 6, NOT here. Every consumer keeps reading `aiEnabled` (uniform). Do not migrate to `aiAvailable` in this plan.
- **`AppContext` the enum stays** (`lib/features/dictionary/domain/entities/app_context.dart`). C1 removes only: the `UserSettingsState.activeContext` field, the `active_context` SharedPreferences key, `setActiveContext`, `ContextSelectorWidget`, and the `context`/`AppContext` parameter on the lookup use-case / repository / source. Every remaining reader of a context value passes `AppContext.general`.
- Spec: `docs/superpowers/specs/2026-08-30-flutter-bloom-redesign-design.md` (§ Phần B2, Phần B3, Phần C1).

---

## File Structure

**Modified — C1 (Tasks 1–2):**
- `lib/features/dictionary/domain/entities/user_settings_state.dart` — drop `activeContext`
- `lib/features/dictionary/presentation/providers/user_settings_provider.dart` — drop `active_context` read + `setActiveContext`
- `lib/features/dictionary/domain/repositories/dictionary_repository.dart` — drop `context` param
- `lib/features/dictionary/data/repositories/dictionary_repository_impl.dart` — drop `context` param
- `lib/features/dictionary/domain/use_cases/lookup_use_case.dart` — drop `context` param
- `lib/features/dictionary/data/sources/gemini_dictionary_source.dart` — drop `context` param + context lines in prompts
- `lib/features/dictionary/presentation/providers/lookup_provider.dart` — drop `context` args
- `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart` — `activeContext: AppContext.general` on save
- `lib/features/reading/presentation/screens/reading_home_screen.dart` — `context: AppContext.general`
- `lib/features/listening/presentation/screens/comprehension_home_screen.dart` — `_context = AppContext.general`

**Deleted — C1:**
- `lib/features/dictionary/presentation/widgets/context_selector_widget.dart`
- `test/features/dictionary/presentation/widgets/context_selector_widget_test.dart`

**Modified — Bloom restyle (Tasks 3–8):**
- `lib/core/theme/bloom/bloom_text_field.dart` — add `focusNode`, `keyboardType`, `textInputAction`, `onEditingComplete`, `readOnly`
- `lib/features/dictionary/presentation/screens/lookup_screen.dart`
- `lib/features/dictionary/presentation/widgets/search_bar_widget.dart`
- `lib/features/dictionary/presentation/widgets/word_result_widget.dart`
- `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`
- `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart` (again — restyle)
- `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart`
- `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`

**Test files touched:** `user_settings_state_test.dart`, `user_settings_notifier_test.dart`, `dictionary_repository_impl_test.dart` (+`.mocks.dart`), `gemini_dictionary_source_test.dart`, `lookup_use_case_test.dart` (+`.mocks.dart`), `lookup_provider_test.dart` (+`.mocks.dart`), `save_vocab_sheet_test.dart`, `core/theme/bloom/bloom_text_field_test.dart`, plus any dict/vocab screen/widget test that asserts a now-translated string or a swapped widget type.

**Not in this plan:** Practice / Reading / Listening / Word Radar / Progress / Settings / Sign-in screens (later plans); `aiEnabled` removal (Plan 6); `README.md` update (Plan 6); the feature-specific Bloom widgets not listed above.

---

## Task 1: C1a — remove the global `activeContext` setting

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `lib/features/dictionary/presentation/providers/lookup_provider.dart:19-49, 55-75`
- Modify: `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart:96`
- Modify: `lib/features/reading/presentation/screens/reading_home_screen.dart:256`
- Modify: `lib/features/listening/presentation/screens/comprehension_home_screen.dart:32`
- Delete: `lib/features/dictionary/presentation/widgets/context_selector_widget.dart`
- Delete: `test/features/dictionary/presentation/widgets/context_selector_widget_test.dart`
- Modify: `lib/features/dictionary/presentation/screens/lookup_screen.dart` (remove `ContextSelectorWidget`)
- Test: `test/features/dictionary/domain/entities/user_settings_state_test.dart`, `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Consumes: `AppContext` (`lib/features/dictionary/domain/entities/app_context.dart`, unchanged), `UserSettingsState` (still has `targetLanguage`, `aiEnabled`, `activeProvider`, `providerConfigs`, `targetCefrLevel`, `themePreference`, `reminder*`).
- Produces: `UserSettingsState` with **no** `activeContext` field/param/copyWith/default. `UserSettingsNotifier` with **no** `setActiveContext` and no `active_context` key read. The `lookup_use_case` / repository / source still take a `context` param at this point (removed in Task 2) — every call site now passes `AppContext.general` explicitly.

- [ ] **Step 1: Update the failing tests**

In `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`:
- In the `build() returns defaults when SharedPreferences is empty` test, **delete** the line `expect(state.activeContext, AppContext.general);`.
- In the `build() loads persisted provider and config from SharedPreferences` test, **delete** the `'active_context': 'business',` line from `initialValues` and **delete** the line `expect(state.activeContext, AppContext.business);`.
- Search the file for any remaining `activeContext` / `setActiveContext` / `AppContext` reference and remove the corresponding test or assertion. Remove the now-unused `import '.../app_context.dart';` if present.

`test/features/dictionary/domain/entities/user_settings_state_test.dart` has no `activeContext` reference — leave it.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart test/features/dictionary/domain/entities/user_settings_state_test.dart`
Expected: FAIL — the notifier still populates `activeContext` and the entity still has the field, but that's fine; the *compile* fails only once you edit the entity in Step 3. Actually at this point the tests still **pass** (you only removed assertions). That's acceptable — the RED here is the compile break you create in Step 3. Proceed.

- [ ] **Step 3: Remove `activeContext` from the entity**

`lib/features/dictionary/domain/entities/user_settings_state.dart`:
- Delete `import 'app_context.dart';`.
- Delete `required this.activeContext,` from the constructor.
- Delete `final AppContext activeContext;`.
- Delete `AppContext? activeContext,` from `copyWith`'s params and `activeContext: activeContext ?? this.activeContext,` from its body.
- Delete `activeContext: AppContext.general,` from `static const defaults`.

- [ ] **Step 4: Remove it from the notifier**

`lib/features/dictionary/presentation/providers/user_settings_provider.dart`:
- Delete `import '../../domain/entities/app_context.dart';`.
- In `build()`'s returned `UserSettingsState(...)`, delete the line:
  ```dart
        activeContext: AppContext.values.byName(
            prefs.getString('active_context') ?? AppContext.general.name),
  ```
- Delete the whole `setActiveContext` method:
  ```dart
    void setActiveContext(AppContext context) {
      _prefs.setString('active_context', context.name);
      state = state.copyWith(activeContext: context);
    }
  ```

- [ ] **Step 5: Fix every reader of `settings.activeContext`**

`lib/features/dictionary/presentation/providers/lookup_provider.dart` — add `import '../../domain/entities/app_context.dart';`, then replace the three `context: settings.activeContext,` occurrences with `context: AppContext.general,` (in `lookup()`'s `useCase.execute(...)`, and in `discover()`'s `gemini.discoverWord(...)` and `useCase.execute(...)`).

`lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart:96` — add `import '../../domain/entities/app_context.dart';`, change `activeContext: settings.activeContext,` → `activeContext: AppContext.general,`.

`lib/features/reading/presentation/screens/reading_home_screen.dart:256` — change `context: settings.activeContext,` → `context: AppContext.general,`. Add `import '../../../dictionary/domain/entities/app_context.dart';` if not already imported (check — `generate_reading_passage_use_case.dart` imports it, but this screen may not).

`lib/features/listening/presentation/screens/comprehension_home_screen.dart:32` — change `_context = settings.activeContext;` → `_context = AppContext.general;`. `AppContext` is already imported here (line uses `AppContext` at line 24/52).

- [ ] **Step 6: Delete `ContextSelectorWidget` and remove it from the lookup screen**

Delete `lib/features/dictionary/presentation/widgets/context_selector_widget.dart` and `test/features/dictionary/presentation/widgets/context_selector_widget_test.dart`.

`lib/features/dictionary/presentation/screens/lookup_screen.dart`:
- Delete `import '../widgets/context_selector_widget.dart';`.
- Delete the `const ContextSelectorWidget(),` line from the `Column`'s `children`.

- [ ] **Step 7: Regenerate + run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test`
Expected: all green. Any test that still references `settings.activeContext`, `setActiveContext`, or `ContextSelectorWidget` breaks — fix it (a screen/widget test asserting the context tile is gone → remove that assertion block; the tile no longer exists).

- [ ] **Step 8: `flutter analyze`**

Run: `flutter analyze`
Expected: `21 issues found.` — no new issues. (An "unused import" here is a new issue — clean it up.)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(settings): remove global activeContext (C1a) — match web"
```

---

## Task 2: C1b — remove the `context` parameter from the lookup chain

**Files:**
- Modify: `lib/features/dictionary/domain/repositories/dictionary_repository.dart`
- Modify: `lib/features/dictionary/data/repositories/dictionary_repository_impl.dart`
- Modify: `lib/features/dictionary/domain/use_cases/lookup_use_case.dart`
- Modify: `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`
- Modify: `lib/features/dictionary/presentation/providers/lookup_provider.dart` (drop the `context:` args added in Task 1)
- Test: `test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart` (+ `.mocks.dart`), `test/features/dictionary/data/sources/gemini_dictionary_source_test.dart`, `test/features/dictionary/domain/use_cases/lookup_use_case_test.dart` (+ `.mocks.dart`), `test/features/dictionary/presentation/providers/lookup_provider_test.dart` (+ `.mocks.dart`)

**Interfaces:**
- Consumes: `Language`, `InputType`, `LookupResult`, `DictionaryException` (all unchanged).
- Produces:
  - `DictionaryRepository.lookup({required String query, required Language targetLanguage, required bool aiEnabled}) → Future<LookupResult>` (no `context`)
  - `LookupUseCase.execute({required String query, required Language targetLanguage, required bool aiEnabled}) → Future<LookupResult>` (no `context`)
  - `GeminiDictionarySource.lookup({required String query, required InputType inputType, required Language targetLanguage}) → Future<LookupResult>` (no `context`)
  - `GeminiDictionarySource.discoverWord({required Language targetLanguage}) → Future<String>` (no `context`)

- [ ] **Step 1: Update the failing tests**

`test/features/dictionary/domain/use_cases/lookup_use_case_test.dart`:
- In the mock stub `when(mockRepo.lookup(...))`, delete the line `context: anyNamed('context'),`.
- In every `useCase.execute(...)` call, delete the `context: AppContext.general,` line.
- In every `verify(mockRepo.lookup(...))` call, delete `context: anyNamed('context'),`.
- Remove the now-unused `import '.../app_context.dart';`.

`test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart`:
- In every `repo.lookup(...)` call and every `when(...)` / `verify(...)` on the sources, delete the `context:` line (`context: AppContext.general,` and `context: anyNamed('context')`).
- The `geminiSource.lookup(...)` stubs: delete `context: anyNamed('context'),`.
- Remove the now-unused `import '.../app_context.dart';`.

`test/features/dictionary/data/sources/gemini_dictionary_source_test.dart`:
- In every `source.lookup(...)` call, delete the `context: AppContext.<x>,` line.
- If there's a `source.discoverWord(...)` call, delete its `context:` line.
- Remove the now-unused `import '.../app_context.dart';`.
- Any assertion on `suggestedTopics` equal to `['Business']` etc. stays — the `FakeGenerativeModelClient` returns fixed JSON regardless of prompt, so those still hold.

`test/features/dictionary/presentation/providers/lookup_provider_test.dart`:
- In `when(mockUseCase.execute(...))`, delete `context: anyNamed('context'),`.
- Any `verify(mockUseCase.execute(...))` — delete `context: anyNamed('context'),`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dictionary/`
Expected: at this point tests still compile against the old signatures and pass — the RED is the compile break in Steps 3–6. Proceed.

- [ ] **Step 3: Repository interface + impl**

`lib/features/dictionary/domain/repositories/dictionary_repository.dart`:
- Delete `import '../entities/app_context.dart';`.
- Change the abstract method to:
  ```dart
    Future<LookupResult> lookup({
      required String query,
      required Language targetLanguage,
      required bool aiEnabled,
    });
  ```

`lib/features/dictionary/data/repositories/dictionary_repository_impl.dart`:
- Delete `import '../../domain/entities/app_context.dart';`.
- Change `lookup` to drop `required AppContext context,` from the params, and in the `geminiSource.lookup(...)` call drop `context: context,`.

- [ ] **Step 4: Use case**

`lib/features/dictionary/domain/use_cases/lookup_use_case.dart`:
- Delete `import '../entities/app_context.dart';`.
- Drop `required AppContext context,` from `execute`'s params and `context: context,` from the `_repository.lookup(...)` call.

- [ ] **Step 5: Gemini source + prompts**

`lib/features/dictionary/data/sources/gemini_dictionary_source.dart`:
- Delete `import '../../domain/entities/app_context.dart';`.
- `lookup(...)`: drop `required AppContext context,` from params; in the ternary drop `, context` from `_wordPhrasePrompt(query, inputType, targetLanguage, context)` → `_wordPhrasePrompt(query, inputType, targetLanguage)`.
- `discoverWord(...)`: drop `required AppContext context,` from params; delete the `'Context: ${context.label}. '` line from the prompt string so it reads:
  ```dart
      final prompt =
          'Suggest one ${targetLanguage.label} vocabulary word for an intermediate learner. '
          'Respond with JSON only: {"word": "the word"}';
  ```
- `_wordPhrasePrompt(...)`: drop the `AppContext context,` param; delete the line `'Shape examples for context: ${context.label}. '` from the returned string.

- [ ] **Step 6: Lookup provider**

`lib/features/dictionary/presentation/providers/lookup_provider.dart`:
- Remove `import '../../domain/entities/app_context.dart';` (added in Task 1).
- Delete the three `context: AppContext.general,` lines from `useCase.execute(...)` (×2) and `gemini.discoverWord(...)` (×1).

- [ ] **Step 7: Regenerate mocks + run tests**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test`
Expected: all green.

- [ ] **Step 8: `flutter analyze`**

Run: `flutter analyze`
Expected: `21 issues found.`

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(dictionary): drop context param from lookup chain (C1b) — match web prompts"
```

---

## Task 3: Extend BloomTextField

**Files:**
- Modify: `lib/core/theme/bloom/bloom_text_field.dart`
- Test: `test/core/theme/bloom/bloom_text_field_test.dart`

**Interfaces:**
- Consumes: `context.bloom`, `BloomRadii`.
- Produces:
  ```dart
  class BloomTextField extends StatelessWidget {
    const BloomTextField({
      super.key,
      this.controller,
      this.focusNode,
      this.hintText,
      this.onChanged,
      this.onSubmitted,
      this.onEditingComplete,
      this.obscureText = false,
      this.maxLines = 1,
      this.minLines,
      this.enabled = true,
      this.readOnly = false,
      this.autofocus = false,
      this.keyboardType,
      this.textInputAction,
      this.prefixIcon,   // IconData?
      this.suffix,       // Widget?
    });
  }
  ```

- [ ] **Step 1: Write the failing test (append to the existing file)**

```dart
  testWidgets('forwards focusNode, keyboardType, textInputAction, readOnly',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(
          focusNode: node,
          hintText: 'x',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.search,
          readOnly: true,
        ),
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode, same(node));
    expect(field.keyboardType, TextInputType.emailAddress);
    expect(field.textInputAction, TextInputAction.search);
    expect(field.readOnly, isTrue);
  });

  testWidgets('renders a prefix icon and a suffix widget', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(
          hintText: 'x',
          prefixIcon: Icons.search,
          suffix: const Text('clear'),
        ),
      ),
    ));
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('clear'), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_text_field_test.dart`
Expected: FAIL — `focusNode`/`keyboardType`/`prefixIcon`/`suffix` are not constructor params.

- [ ] **Step 3: Implement**

Replace `lib/core/theme/bloom/bloom_text_field.dart` with:

```dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A `TextField` wrapped in Bloom styling: `surface2` ground, pill border
/// for single-line, `sm` rounded for multi-line, accent focus ring.
class BloomTextField extends StatelessWidget {
  const BloomTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final radius = (maxLines ?? 2) == 1 ? BloomRadii.pill : BloomRadii.sm;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: TextStyle(color: c.ink, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: c.inkFaint),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: c.inkFaint),
        suffixIcon: suffix,
        filled: true,
        fillColor: c.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent),
        disabledBorder: border(c.border),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_text_field_test.dart`
Expected: PASS (all cases).

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/bloom/bloom_text_field.dart test/core/theme/bloom/bloom_text_field_test.dart
git commit -m "feat(bloom): BloomTextField gains focusNode/keyboardType/readOnly/prefixIcon/suffix"
```

---

## Task 4: Lookup screen + search bar → Bloom

**Files:**
- Modify: `lib/features/dictionary/presentation/screens/lookup_screen.dart`
- Modify: `lib/features/dictionary/presentation/widgets/search_bar_widget.dart`
- Test: `test/features/dictionary/` — any lookup/search-bar widget test that breaks

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomLeafMark`, `BloomIconButton`, `BloomTextField`, `BloomPillButton`, `BloomButtonVariant`, `context.bloom` (Plan 1 + Task 3); `lookupNotifierProvider`, `userSettingsNotifierProvider` (unchanged).
- Produces: no new public interface — restyle only. `SearchBarWidget` and `LookupScreen` keep their `const X({super.key})` constructors.

- [ ] **Step 1: Rewrite `search_bar_widget.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../providers/lookup_provider.dart';
import '../providers/user_settings_provider.dart';

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _controller = TextEditingController();

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    ref.read(lookupNotifierProvider.notifier).lookup(query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(
      userSettingsNotifierProvider.select((s) => s.aiEnabled),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: BloomTextField(
                  controller: _controller,
                  hintText: 'Từ, cụm từ, hoặc câu…',
                  prefixIcon: Icons.search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              BloomIconButton(
                icon: Icons.arrow_forward,
                tooltip: 'Tra từ',
                onPressed: _submit,
              ),
            ],
          ),
          if (aiEnabled) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: BloomPillButton(
                label: 'Khám phá',
                icon: Icons.auto_awesome,
                variant: BloomButtonVariant.sage,
                onPressed: () =>
                    ref.read(lookupNotifierProvider.notifier).discover(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Rewrite `lookup_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/lookup_provider.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sentence_result_widget.dart';
import '../widgets/word_result_widget.dart';

class LookupScreen extends ConsumerWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(lookupNotifierProvider);
    final c = context.bloom;

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'LexiCore',
        leading: const BloomLeafMark(size: 22),
      ),
      body: Column(
        children: [
          const SearchBarWidget(),
          Divider(height: 1, color: c.border),
          Expanded(
            child: lookupState.when(
              data: (result) {
                if (result == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nhập một từ, cụm từ, hoặc câu để bắt đầu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.inkSoft),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: switch (result) {
                    WordPhraseResult r => WordResultWidget(result: r),
                    SentenceResult r => SentenceResultWidget(result: r),
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.danger),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Run the affected tests, fix finders**

Run: `flutter test test/features/dictionary/`
Fix breaks:
- A search-bar test tapping `find.byIcon(Icons.search)` for the submit button → the submit button is now `Icons.arrow_forward` inside a `BloomIconButton`; the search icon is the field's prefix. Update to `find.widgetWithIcon(BloomIconButton, Icons.arrow_forward)` or tap the field + `tester.testTextInput`. A test asserting `IconButton.filledTonal` / `Icons.auto_awesome` for discover → now `find.widgetWithText(BloomPillButton, 'Khám phá')`.
- A lookup-screen test asserting `find.byType(AppBar)` → still fine (`BloomAppBar` renders an `AppBar`), or switch to `find.byType(BloomAppBar)`. A test asserting the old empty-state English string `'Enter a word, phrase, or sentence to get started.'` → `'Nhập một từ, cụm từ, hoặc câu để bắt đầu.'`.
- Do NOT change any assertion about *what happens* on submit / discover.

- [ ] **Step 4: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle lookup screen + search bar"
```

---

## Task 5: Word + sentence result widgets → Bloom

**Files:**
- Modify: `lib/features/dictionary/presentation/widgets/word_result_widget.dart`
- Modify: `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`
- Test: `test/features/dictionary/` — any result-widget test that breaks

**Interfaces:**
- Consumes: `BloomCard`, `BloomCefrPill`, `BloomChip` (+`BloomChipStyle`), `BloomPillButton`, `context.bloom`; `WordPhraseResult` / `SentenceResult` (`lib/features/dictionary/domain/entities/lookup_result.dart`, unchanged); `ttsServiceProvider`, `PronunciationTier`, `vocabBankNotifierProvider`, `userSettingsNotifierProvider`, `SaveVocabSheet` (unchanged).
- Produces: restyle only. `WordResultWidget` / `SentenceResultWidget` keep `const X({super.key, required this.result})`.

- [ ] **Step 1: Add a shared pronounce button helper**

At the top of `word_result_widget.dart` (below imports), add a small private widget both files' rows can use. Actually — put it in its own file so `sentence_result_widget.dart` can import it: create `lib/features/dictionary/presentation/widgets/pronounce_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../../../../core/theme/bloom_tokens.dart';

/// A small round speaker button matching Bloom's `.pron-btn` (`bloom.css`).
class PronounceButton extends StatelessWidget {
  const PronounceButton({super.key, required this.onPressed, this.size = 26});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        iconSize: size * 0.6,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.volume_up),
        color: c.inkSoft,
        style: IconButton.styleFrom(
          backgroundColor: c.surface2,
          side: BorderSide(color: c.border),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
```

Add its test `test/features/dictionary/presentation/widgets/pronounce_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/pronounce_button.dart';

void main() {
  testWidgets('fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: PronounceButton(onPressed: () => taps++)),
    ));
    await tester.tap(find.byType(PronounceButton));
    expect(taps, 1);
  });
}
```

Run: `flutter test test/features/dictionary/presentation/widgets/pronounce_button_test.dart` → PASS.

- [ ] **Step 2: Rewrite `word_result_widget.dart`**

```dart
// lib/features/dictionary/presentation/widgets/word_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';
import 'pronounce_button.dart';
import 'save_vocab_sheet.dart';

class WordResultWidget extends ConsumerWidget {
  const WordResultWidget({super.key, required this.result});

  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final c = context.bloom;
    final canSpeak = targetLanguage.ttsCloudCode != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: BloomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    result.headword,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                if (canSpeak)
                  PronounceButton(
                    onPressed: () => tts.pronounce(result.headword,
                        targetLanguage, tier: PronunciationTier.word),
                  ),
                const Spacer(),
                if (result.cefrLevel != null)
                  BloomCefrPill(result.cefrLevel!.label),
              ],
            ),
            if (result.ipa.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(result.ipa,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: c.inkSoft)),
            ],
            const SizedBox(height: 10),
            Text(result.meaning,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (result.definition.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(result.definition,
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: c.inkSoft)),
            ],
            if (result.synonyms.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in result.synonyms) BloomChip(label: s),
                ],
              ),
            ],
            if (result.examples.isNotEmpty) ...[
              Divider(height: 24, color: c.border),
              for (final ex in result.examples)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(ex,
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: c.inkSoft)),
                      ),
                      if (canSpeak) ...[
                        const SizedBox(width: 8),
                        PronounceButton(
                          size: 22,
                          onPressed: () => tts.pronounce(ex, targetLanguage,
                              tier: PronunciationTier.sentence),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            if (result.suggestedTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in result.suggestedTopics)
                    BloomChip(label: t, style: BloomChipStyle.topic),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _SaveButton(result: result),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.result});
  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final settings = ref.read(userSettingsNotifierProvider);
    final c = context.bloom;

    final isSaved = vocabAsync.valueOrNull?.any(
          (r) =>
              r.headword.toLowerCase() == result.headword.toLowerCase() &&
              r.targetLanguage == settings.targetLanguage,
        ) ??
        false;

    if (isSaved) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: c.sage),
          const SizedBox(width: 4),
          Text('Đã lưu',
              style: TextStyle(
                  color: c.sage, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      );
    }

    return BloomPillButton(
      label: 'Lưu từ',
      block: true,
      onPressed: () async {
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SaveVocabSheet(result: result),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Rewrite `sentence_result_widget.dart`**

```dart
// lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';
import 'pronounce_button.dart';

class SentenceResultWidget extends ConsumerWidget {
  const SentenceResultWidget({super.key, required this.result});

  final SentenceResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final c = context.bloom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: BloomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(result.original,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (targetLanguage.ttsCloudCode != null) ...[
                  const SizedBox(width: 8),
                  PronounceButton(
                    onPressed: () => tts.pronounce(result.original,
                        targetLanguage, tier: PronunciationTier.sentence),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(result.translation,
                style: TextStyle(fontSize: 18, color: c.inkSoft)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run affected tests, fix finders**

Run: `flutter test test/features/dictionary/`
Fix breaks: `find.byType(Card)` → `find.byType(BloomCard)`; `find.text('Saved')` → `find.text('Đã lưu')`; a test tapping the `OutlinedButton.icon` "Save" → `find.widgetWithText(BloomPillButton, 'Lưu từ')`; synonym/topic `Chip` finders → `find.byType(BloomChip)`. Behavior assertions (save sheet opens, tts called) unchanged.

- [ ] **Step 5: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle word + sentence result widgets"
```

---

## Task 6: Save vocab sheet → Bloom

**Files:**
- Modify: `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`
- Test: `test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`

**Interfaces:**
- Consumes: `BloomTextField`, `BloomPillButton`, `BloomChip`, `BloomSectionHeader`, `FilterTile` (already Bloom-styled from Plan 1), `context.bloom`; `showMultiSelectSheet` / `SelectOption` (Bloom-styled from Plan 1), `VocabRecord`, `Topic`, `CEFRLevel`, `topicsNotifierProvider`, `vocabBankNotifierProvider`, `userSettingsNotifierProvider`, `WordPhraseResult`, `AppContext` (for `AppContext.general` — added in Task 1).
- Produces: restyle only. `SaveVocabSheet` keeps `const SaveVocabSheet({super.key, required this.result})`.

- [ ] **Step 1: Restyle the sheet**

In `save_vocab_sheet.dart`:
- Add `import '../../../../core/theme/bloom/bloom.dart';`.
- Header: keep the `Row`, but title `Text` uses `style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)` and the close button becomes `BloomIconButton(icon: Icons.close, onPressed: () => Navigator.of(context).pop(false))`. Text: `'Lưu "${widget.result.headword}"'`.
- Replace each section-label `Text('Meaning', style: theme.textTheme.labelLarge)` etc. with `const BloomSectionHeader('Nghĩa')` / `'Định nghĩa'` / `'Từ đồng nghĩa'` / `'Ví dụ'` / `'Chủ đề'` / `'Ghi chú cá nhân'`.
- `_meaningCtrl` field: `BloomTextField(controller: _meaningCtrl, maxLines: 3, minLines: 2)`.
- Definition (read-only): keep as a plain `Text(widget.result.definition, style: TextStyle(color: context.bloom.inkSoft))`.
- Synonyms (read-only): `Wrap(spacing: 6, runSpacing: 6, children: [for (final s in widget.result.synonyms) BloomChip(label: s)])`.
- Example rows: each is `Row([Expanded(child: BloomTextField(controller: e.value)), BloomIconButton(icon: Icons.close, onPressed: () => setState(() => _exampleCtrls.removeAt(e.key)))])`.
- "Add example" button: `BloomPillButton(label: 'Thêm ví dụ', icon: Icons.add, variant: BloomButtonVariant.link, onPressed: () => setState(() => _exampleCtrls.add(TextEditingController())))`.
- Topics `FilterTile`: label `'Chủ đề (tối đa 2)'`, `value` unchanged logic but `'Chưa chọn'` when empty. The `showMultiSelectSheet` `title:` → `'Chủ đề'`.
- Notes: `BloomTextField(controller: _notesCtrl, maxLines: 4, minLines: 3, hintText: 'Thêm ghi chú để dễ nhớ…')`.
- Bottom save button: `BloomPillButton(label: 'Lưu vào Ngân hàng từ', block: true, onPressed: _save)`.
- `_save()`: the `activeContext:` field is already `AppContext.general` from Task 1 — leave it.
- Keep the outer `SelectionArea` + `DraggableScrollableSheet` and the `_preSelectTopics` post-frame logic exactly as-is.

- [ ] **Step 2: Update the test**

Open `test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`. For every finder that targets `TextField` by decoration/label, prefer `find.byType(BloomTextField)` or `find.widgetWithText(...)`. For the save button: `find.widgetWithText(BloomPillButton, 'Lưu vào Ngân hàng từ')`. For section labels: `find.text('Nghĩa')` etc. Keep every assertion about the saved `VocabRecord`'s fields, the pre-selection of topics, and navigation-on-save. If the test asserts `record.activeContext`, it should now expect `AppContext.general`.

- [ ] **Step 3: Run tests, fix, full suite**

Run: `flutter test test/features/dictionary/presentation/widgets/save_vocab_sheet_test.dart`
Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle save-vocab sheet + Vietnamese copy"
```

---

## Task 7: Vocab Bank screen → Bloom

**Files:**
- Modify: `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart`
- Test: `test/features/vocabulary/` — any vocab-bank widget test that breaks

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomTextField`, `BloomListRow`, `BloomCard`, `BloomPillButton`, `FilterTile` (Plan 1), `showMultiSelectSheet` / `SelectOption` (Plan 1), `context.bloom`; `vocabBankNotifierProvider`, `topicsNotifierProvider`, `userSettingsNotifierProvider`, `Topic`, `VocabRecord`, `Language` (all unchanged).
- Produces: restyle only + Vietnamese copy + title change. `VocabBankScreen` keeps `const VocabBankScreen({super.key})`.

- [ ] **Step 1: Rewrite the screen**

Key changes to `vocab_bank_screen.dart`:
- `import '../../../../core/theme/bloom/bloom.dart';` (remove the direct `filter_tile.dart` import only if `FilterTile` is re-exported by the barrel — it is NOT; keep `import '../../../../core/widgets/filter_tile.dart';`... actually `FilterTile` lives at `lib/core/widgets/filter_tile.dart` and is not in the Bloom barrel. Keep its existing import.)
- `Scaffold` → `BloomScaffold`. `AppBar` → `BloomAppBar(title: 'Ngân hàng từ · ${targetLanguage.label}', actions: [BloomIconButton(icon: Icons.add, tooltip: 'Thêm chủ đề', onPressed: () => _showAddTopicDialog(context))])`.
- The Material `SearchBar` → `BloomTextField(controller: _searchCtrl, hintText: 'Tìm từ…', prefixIcon: Icons.search, suffix: _searchQuery.isEmpty ? null : GestureDetector(onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }, child: Icon(Icons.clear, size: 18, color: context.bloom.inkFaint)), onChanged: (v) => setState(() => _searchQuery = v))`.
- The hand-rolled topic-filter `Material`+`InkWell` block → `FilterTile(icon: Icons.sell_outlined, label: 'Chủ đề', value: _selectedTopicIds.isEmpty ? 'Tất cả' : '${_selectedTopicIds.length} đã chọn', onTap: () => _openTopicPicker(topics))`. Wrap in `Padding(padding: const EdgeInsets.symmetric(horizontal: 16))`.
- `_openTopicPicker`'s `showMultiSelectSheet(title: 'Chủ đề', ...)` — unchanged (already Bloom-styled).
- Empty state: `Icons.menu_book_outlined` icon `color: context.bloom.inkFaint`; text `'Chưa lưu từ nào.'` and `'Tra một từ rồi bấm Lưu.'` — styled from `context.bloom`.
- No-match state: `'Không có từ nào khớp tìm kiếm hoặc bộ lọc.'`.
- `_VocabCard` → replace the `Card`+`ListTile` with a `BloomCard(onTap: () => context.push('/vocab/${record.id}'), child: BloomListRow(cefr: record.cefrLevel.label, headword: record.headword, meaning: record.meaning, trailingText: record.inputType.name))`. Actually simpler: drop `_VocabCard` and render each row as a `BloomListRow` directly inside the `ListView`, separated by a 1px `Divider(color: context.bloom.border)`, tapping pushes the detail route. The IPA line is dropped from the row (it's on the detail screen) — matches the demo's compact `.vrow`.
- FAB: `BloomScaffold` has `floatingActionButton:` — add `floatingActionButton: Container(...)` — actually use a small helper: a `GestureDetector`/`Material` rounded-18 square `context.bloom.accent` with a `+` `Icon(Icons.add, color: context.bloom.accentInk)`, `onTap` = push `/` (the lookup tab) — matches the demo's pink rounded-square FAB that jumps to lookup to add words. Concretely:
  ```dart
  floatingActionButton: Material(
    color: context.bloom.accent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.go('/'),
      child: SizedBox(
        width: 52, height: 52,
        child: Icon(Icons.add, color: context.bloom.accentInk, size: 26),
      ),
    ),
  ),
  ```
- `_showAddTopicDialog`: keep the `AlertDialog` but its two `TextField`s → `BloomTextField` (name: `hintText: 'vd: Từ vựng của tôi'`; emoji: `hintText: 'Emoji'`); buttons → `BloomPillButton` (`'Huỷ'` variant secondary, `'Thêm'` variant primary). Dialog title `'Chủ đề mới'`. Labels: name field prefixed by `const BloomSectionHeader('Tên chủ đề')` above it.

- [ ] **Step 2: Run affected tests, fix**

Run: `flutter test test/features/vocabulary/`
Fix: `find.byType(SearchBar)` → `find.byType(BloomTextField)`; `find.text('Vocab Bank · English')` → `find.text('Ngân hàng từ · English')`; `find.text('No words saved yet.')` → `'Chưa lưu từ nào.'`; `find.byType(Card)` → `find.byType(BloomCard)` or `find.byType(BloomListRow)`; `find.byType(ListTile)` → `find.byType(BloomListRow)`. Keep navigation / filter / search behavior assertions.

- [ ] **Step 3: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle Vocab Bank screen + Vietnamese copy"
```

---

## Task 8: Vocab detail screen → Bloom

**Files:**
- Modify: `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`
- Test: `test/features/vocabulary/` — any vocab-detail widget test that breaks

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomAppBar`, `BloomIconButton`, `BloomPillButton` (+`BloomButtonVariant`), `BloomSectionHeader`, `BloomCard`, `BloomChip`, `BloomCefrPill`, `FilterTile` (Plan 1), `showMultiSelectSheet` (Plan 1), `PronounceButton` (Task 5), `context.bloom`; `vocabRepositoryProvider`, `vocabBankNotifierProvider`, `topicsNotifierProvider`, `userSettingsNotifierProvider`, `ttsServiceProvider`, `PronunciationTier`, `VocabRecord`, `Topic` (all unchanged).
- Produces: restyle only + Vietnamese copy. `VocabDetailScreen` keeps `const VocabDetailScreen({super.key, required this.id})`.

- [ ] **Step 1: Rewrite the screen**

Key changes to `vocab_detail_screen.dart`:
- `import '../../../../core/theme/bloom/bloom.dart';` and `import '../../../dictionary/presentation/widgets/pronounce_button.dart';`.
- Loading / not-found: `BloomScaffold(body: Center(child: CircularProgressIndicator()))` and `BloomScaffold(appBar: BloomAppBar(title: ''), body: Center(child: Text('Không tìm thấy từ.')))`.
- Main: `Scaffold` → `BloomScaffold`. `AppBar` → `BloomAppBar(title: r.headword, actions: <see below>)`.
  - view mode actions: `[BloomIconButton(icon: Icons.edit_outlined, tooltip: 'Sửa', onPressed: () => setState(() => _editing = true)), BloomIconButton(icon: Icons.delete_outline, tooltip: 'Xoá', onPressed: _deleteRecord)]`.
  - edit mode actions: `[BloomPillButton(label: 'Huỷ', variant: BloomButtonVariant.link, onPressed: _cancelEdit), BloomPillButton(label: 'Lưu', variant: BloomButtonVariant.primary, onPressed: _saveEdit)]` — wrap each in a `Padding(padding: const EdgeInsets.symmetric(vertical: 6))` and add a trailing `SizedBox(width: 8)`.
- Body stays `SingleChildScrollView` with `padding: const EdgeInsets.all(16)`. Wrap the whole content `Column` in a `BloomCard` (so the detail reads as one surface), OR keep sections as bare content on the gradient — pick **bare content** (matches the demo's drawer style) but put the headword+IPA+CEFR row and the "Examples" list each in their own `BloomCard`. Keep it simple: one outer `BloomCard` wrapping everything.
- Headword row: `Text(r.headword, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))`, IPA below in mono `color: context.bloom.inkSoft`, a `BloomCefrPill(r.cefrLevel.label)` at the end of the row, and a `PronounceButton` when `settings.targetLanguage.ttsCloudCode != null`.
- `_SectionLabel(...)` → `BloomSectionHeader(...)` with Vietnamese: `'Nghĩa'`, `'Định nghĩa'`, `'Từ đồng nghĩa'`, `'Ví dụ'`, `'Chủ đề'`, `'Ghi chú cá nhân'`.
- Edit-mode `TextField`s → `BloomTextField` (meaning: `maxLines: 3, minLines: 2`; example rows: single-line with a trailing `BloomIconButton(icon: Icons.close)`; notes: `maxLines: 4, minLines: 3`).
- Example view rows: keep the `1. ` numbering (`color: context.bloom.inkFaint`), italic text `color: context.bloom.inkSoft`, trailing `PronounceButton(size: 22)`.
- Synonyms / topic chips: `BloomChip(label: s)` / `BloomChip(label: '${topic.emoji} ${topic.name}', style: BloomChipStyle.topic)`. `'None'` → `'Chưa có'`; `'No notes.'` → `'Chưa có ghi chú.'`.
- Edit-mode topic `FilterTile`: label `'Chủ đề (tối đa 2)'`, `value` `'Chưa chọn'` when empty. `showMultiSelectSheet(title: 'Chủ đề', ...)`.
- `_deleteRecord` dialog: title `'Xoá khỏi Ngân hàng từ?'`, body `'"${_record!.headword}" sẽ bị xoá. Không thể hoàn tác.'`, buttons `BloomPillButton('Huỷ', secondary)` / `BloomPillButton('Xoá', danger)`.

- [ ] **Step 2: Run affected tests, fix**

Run: `flutter test test/features/vocabulary/`
Fix: `find.byType(AppBar)` still works (BloomAppBar renders one) or switch to `find.byType(BloomAppBar)`; English string finders → the Vietnamese values above; edit/save/cancel button finders → `find.widgetWithText(BloomPillButton, 'Lưu')` etc.; `find.byIcon(Icons.edit_outlined)` inside `find.byType(BloomIconButton)`. Keep every assertion about entering/leaving edit mode, the saved `copyWith`, delete-and-pop, and topic editing.

- [ ] **Step 3: Full suite + analyze**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green; `21 issues found.`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(bloom): restyle Vocab detail screen + Vietnamese copy"
```

---

## Self-Review

**1. Spec coverage (against `2026-08-30-flutter-bloom-redesign-design.md` §B2, §B3, §C1):**
- §C1 (bỏ ContextSelectorWidget khỏi Tra từ; bỏ `activeContext` khỏi `UserSettingsState` + sync; `lookup_use_case`/`gemini_dictionary_source` bỏ tham số context; prompt chỉ theo `targetLanguage`; `vocab_record.activeContext` = `general` khi lưu; `comprehension_home`/`reading_home` init `AppContext.general`) → **Tasks 1–2** ✓. (Sync: `AiSettingsSyncService` never carried `activeContext` — spec `2026-08-29` confirms it was local-only — so "bỏ khỏi sync" = it simply disappears from local; no sync-service edit needed. Noted, no task.)
- §B2 (lookup_screen, search_bar_widget, context_selector_widget xoá, word_result_widget, sentence_result_widget, save_vocab_sheet — BloomCard/BloomCefrPill/nút phát âm tròn/BloomPillButton "Lưu từ"/nút sage "Khám phá"/BloomTextField pill) → **Tasks 4–6** (+ Task 3 for the `BloomTextField` props they need) ✓.
- §B3 (vocab_bank_screen, vocab_detail_screen, filter_tile→BloomFilterTile [done in Plan 1], các sheet lọc [done in Plan 1]; List: BloomListRow; FAB bo góc mềm 18px màu accent) → **Tasks 7–8** ✓.
- Spec's "FAB bo góc mềm 18px" → Task 7 Step 1 (`Material` rounded-18 accent square). The spec says the FAB is "màu accent thay vì tròn Material" — implemented.

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Each rewrite step gives the full file or an explicit, itemized change list with the exact widget/string. The two large screens (Tasks 7–8) use itemized change lists rather than full-file dumps because the files are 294/423 lines and the structural skeleton (state, controllers, `_save`/`_delete` logic) is explicitly preserved — the list enumerates every visual swap and every string. If an implementer finds the list ambiguous at a specific spot, that's a NEEDS_CONTEXT, not a silent guess.

**3. Type consistency:**
- `BloomTextField` new params (`focusNode`, `keyboardType`, `textInputAction`, `onEditingComplete`, `readOnly`, `minLines`, `prefixIcon`, `suffix`) defined in Task 3, consumed in Tasks 4/6/7/8 — names match.
- `PronounceButton({required VoidCallback onPressed, double size})` defined in Task 5, consumed in Task 8 — matches.
- `DictionaryRepository.lookup` / `LookupUseCase.execute` / `GeminiDictionarySource.lookup` / `.discoverWord` post-C1b signatures listed in Task 2's Produces block, consumed by `lookup_provider.dart` (Task 2 Step 6) and the tests (Task 2 Step 1) — the `context`/`AppContext` param is gone from all four consistently.
- `BloomCefrPill(String level)` takes the CEFR label string — `result.cefrLevel!.label` / `r.cefrLevel.label` (Tasks 5, 8). `CEFRLevel.label` exists (`lib/features/vocabulary/domain/entities/cefr_level.dart`).
- `BloomChip(label:, style:)` with `BloomChipStyle.topic` — Tasks 5, 6, 8 use it consistently.

No mismatches found. `AppContext.general` is passed at exactly the call sites Task 1 lists, and Task 2 removes the ones in the lookup chain, leaving only `save_vocab_sheet` (record field), `reading_home_screen`, and `comprehension_home_screen` — all outside the lookup chain, all correct.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-31-flutter-bloom-plan2-dictionary-vocab.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
