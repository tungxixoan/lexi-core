# Plan 9 — Task 01: showListeningPracticeOnMobile Setting

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** none (can start immediately)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
Add a `showListeningPracticeOnMobile: bool` field to `UserSettingsState`, persist it via `SharedPreferences` under key `'show_listening_mobile'`, and expose a Settings toggle — mirrors the existing `showReadingPracticeOnMobile` exactly, including the width-based visibility rule (not `kIsWeb`) already fixed for Reading.

## Files
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

## Produces (used by Task 04)
- `UserSettingsState.showListeningPracticeOnMobile: bool` — default `false`
- `UserSettingsNotifier.setShowListeningPracticeOnMobile(bool)` — persists to prefs under `'show_listening_mobile'`

## Steps

- [ ] **Step 1: Write the failing test**

Add to `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`, immediately after the existing `group('showReadingPracticeOnMobile', ...)` block (before the final two closing braces of `group('UserSettingsNotifier', ...)` and `main()`):

```dart
    group('showListeningPracticeOnMobile', () {
      test('defaults to false', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        expect(
          container.read(userSettingsNotifierProvider).showListeningPracticeOnMobile,
          false,
        );
      });

      test('setShowListeningPracticeOnMobile persists to prefs and updates state', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        final prefs = container.read(sharedPreferencesProvider);
        container
            .read(userSettingsNotifierProvider.notifier)
            .setShowListeningPracticeOnMobile(true);
        expect(
          container.read(userSettingsNotifierProvider).showListeningPracticeOnMobile,
          true,
        );
        expect(prefs.getBool('show_listening_mobile'), true);
      });

      test('build() loads persisted showListeningPracticeOnMobile from prefs', () async {
        final container = await makeContainer(
          initialValues: {'show_listening_mobile': true},
        );
        addTearDown(container.dispose);
        expect(
          container.read(userSettingsNotifierProvider).showListeningPracticeOnMobile,
          true,
        );
      });
    });
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL — `showListeningPracticeOnMobile` not defined yet.

- [ ] **Step 3: Update UserSettingsState**

In `lib/features/dictionary/domain/entities/user_settings_state.dart`:

Change the constructor parameter list — add `this.showListeningPracticeOnMobile = false,` right after `this.showReadingPracticeOnMobile = false,`:

```dart
    this.showReadingPracticeOnMobile = false,
    this.showListeningPracticeOnMobile = false,
  });
```

Add the field declaration right after `final bool showReadingPracticeOnMobile;`:

```dart
  final bool showReadingPracticeOnMobile;
  final bool showListeningPracticeOnMobile;
```

In `copyWith`, add the parameter and pass-through right after the `showReadingPracticeOnMobile` ones:

```dart
    bool? showReadingPracticeOnMobile,
    bool? showListeningPracticeOnMobile,
  }) =>
      UserSettingsState(
        // ...unchanged fields above...
        showReadingPracticeOnMobile:
            showReadingPracticeOnMobile ?? this.showReadingPracticeOnMobile,
        showListeningPracticeOnMobile:
            showListeningPracticeOnMobile ?? this.showListeningPracticeOnMobile,
      );
```

In `static const defaults`, add right after `showReadingPracticeOnMobile: false,`:

```dart
    showReadingPracticeOnMobile: false,
    showListeningPracticeOnMobile: false,
  );
```

- [ ] **Step 4: Update UserSettingsNotifier**

In `lib/features/dictionary/presentation/providers/user_settings_provider.dart`:

In `build()`, add right after the `showReadingPracticeOnMobile:` line:

```dart
      showReadingPracticeOnMobile:
          prefs.getBool('show_reading_mobile') ?? false,
      showListeningPracticeOnMobile:
          prefs.getBool('show_listening_mobile') ?? false,
    );
```

Add a new setter method right after `setShowReadingPracticeOnMobile`:

```dart
  void setShowListeningPracticeOnMobile(bool show) {
    _prefs.setBool('show_listening_mobile', show);
    state = state.copyWith(showListeningPracticeOnMobile: show);
  }
```

- [ ] **Step 5: Run tests — should pass now**

```bash
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: all tests pass, including the 3 new `showListeningPracticeOnMobile` tests.

- [ ] **Step 6: Add Settings toggle**

In `lib/features/settings/presentation/screens/settings_screen.dart`, add the following `SwitchListTile` immediately after the existing Reading toggle (which currently reads `if (MediaQuery.sizeOf(context).width < 600) SwitchListTile(... 'Hiện tab Luyện đọc & gõ trên điện thoại' ...)`), inside the same "Học tập" section:

```dart
          if (MediaQuery.sizeOf(context).width < 600)
            SwitchListTile(
              title: const Text('Hiện tab Luyện nghe trên điện thoại'),
              subtitle:
                  const Text('Mặc định ẩn trên mobile — bật nếu bạn muốn dùng'),
              value: settings.showListeningPracticeOnMobile,
              onChanged: (v) =>
                  notifier.setShowListeningPracticeOnMobile(v),
            ),
```

- [ ] **Step 7: Analyze**

```bash
flutter analyze lib/features/dictionary/domain/entities/user_settings_state.dart \
               lib/features/dictionary/presentation/providers/user_settings_provider.dart \
               lib/features/settings/presentation/screens/settings_screen.dart
```

Expected: no issues found.

- [ ] **Step 8: Run full test suite**

```bash
flutter test
```

Expected: all tests pass (no regressions).

- [ ] **Step 9: Commit**

```bash
git add lib/features/dictionary/domain/entities/user_settings_state.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.dart \
        lib/features/settings/presentation/screens/settings_screen.dart \
        test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan9): add showListeningPracticeOnMobile setting with toggle"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: flutter analyze output
Concerns: (if any)
