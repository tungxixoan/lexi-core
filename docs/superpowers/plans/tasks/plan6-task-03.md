# Plan 6 — Task 03: showReadingPracticeOnMobile Setting

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 6 Tasks 01–02 complete

## Global Constraints
(see `plan6-global-constraints.md`)

## What This Task Delivers
Add a `showReadingPracticeOnMobile: bool` field to `UserSettingsState`, persist it via `SharedPreferences` under key `'show_reading_mobile'`, and expose a Settings toggle visible only on mobile (hidden on web where reading is always shown).

## Files
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Modify: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

## Produces (used by Plan 6 Task 04 and Plan 7 Task 03)
- `UserSettingsState.showReadingPracticeOnMobile: bool` — default `false`
- `UserSettingsNotifier.setShowReadingPracticeOnMobile(bool)` — persists to prefs

## Steps

- [ ] **Step 1: Write the failing test**

Add to `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` inside `group('UserSettingsNotifier', ...)`:

```dart
group('showReadingPracticeOnMobile', () {
  test('defaults to false', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    expect(
      container.read(userSettingsNotifierProvider).showReadingPracticeOnMobile,
      false,
    );
  });

  test('setShowReadingPracticeOnMobile persists to prefs and updates state', () async {
    final container = await makeContainer();
    addTearDown(container.dispose);
    final prefs = container.read(sharedPreferencesProvider);
    container
        .read(userSettingsNotifierProvider.notifier)
        .setShowReadingPracticeOnMobile(true);
    expect(
      container.read(userSettingsNotifierProvider).showReadingPracticeOnMobile,
      true,
    );
    expect(prefs.getBool('show_reading_mobile'), true);
  });

  test('build() loads persisted showReadingPracticeOnMobile from prefs', () async {
    final container =
        await makeContainer(initialValues: {'show_reading_mobile': true});
    addTearDown(container.dispose);
    expect(
      container.read(userSettingsNotifierProvider).showReadingPracticeOnMobile,
      true,
    );
  });
});
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL — `showReadingPracticeOnMobile` not defined yet.

- [ ] **Step 3: Update UserSettingsState**

Replace `lib/features/dictionary/domain/entities/user_settings_state.dart` with:

```dart
// lib/features/dictionary/domain/entities/user_settings_state.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'app_context.dart';
import 'language.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.geminiApiKey,
    this.targetCefrLevel,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.showReadingPracticeOnMobile = false,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool showReadingPracticeOnMobile;

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
    Object? targetCefrLevel = _absent,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? showReadingPracticeOnMobile,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        showReadingPracticeOnMobile:
            showReadingPracticeOnMobile ?? this.showReadingPracticeOnMobile,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
    targetCefrLevel: null,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
    showReadingPracticeOnMobile: false,
  );
}
```

- [ ] **Step 4: Update UserSettingsNotifier**

Replace `lib/features/dictionary/presentation/providers/user_settings_provider.dart` with:

```dart
// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

part 'user_settings_provider.g.dart';

// Overridden in main.dart with the real SharedPreferences instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(SharedPreferencesRef ref) =>
    throw UnimplementedError(
        'sharedPreferencesProvider must be overridden in main.dart');

@Riverpod(keepAlive: true)
class UserSettingsNotifier extends _$UserSettingsNotifier {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  UserSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return UserSettingsState(
      targetLanguage: Language.values.byName(
          prefs.getString('target_language') ?? Language.english.name),
      activeContext: AppContext.values.byName(
          prefs.getString('active_context') ?? AppContext.general.name),
      aiEnabled: prefs.getBool('ai_enabled') ?? false,
      geminiApiKey: prefs.getString('gemini_api_key') ?? '',
      targetCefrLevel: prefs.containsKey('target_cefr_level')
          ? CEFRLevel.values.byName(prefs.getString('target_cefr_level')!)
          : null,
      reminderEnabled: prefs.getBool('reminder_enabled') ?? false,
      reminderHour: prefs.getInt('reminder_hour') ?? 20,
      reminderMinute: prefs.getInt('reminder_minute') ?? 0,
      showReadingPracticeOnMobile:
          prefs.getBool('show_reading_mobile') ?? false,
    );
  }

  void setTargetLanguage(Language lang) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
  }

  void setActiveContext(AppContext context) {
    _prefs.setString('active_context', context.name);
    state = state.copyWith(activeContext: context);
  }

  void setAiEnabled({required bool enabled}) {
    _prefs.setBool('ai_enabled', enabled);
    state = state.copyWith(aiEnabled: enabled);
  }

  void setGeminiApiKey(String key) {
    _prefs.setString('gemini_api_key', key);
    state = state.copyWith(geminiApiKey: key);
  }

  void setTargetCefrLevel(CEFRLevel? level) {
    if (level == null) {
      _prefs.remove('target_cefr_level');
    } else {
      _prefs.setString('target_cefr_level', level.name);
    }
    state = state.copyWith(targetCefrLevel: level);
  }

  void setReminderEnabled({required bool enabled}) {
    _prefs.setBool('reminder_enabled', enabled);
    state = state.copyWith(reminderEnabled: enabled);
  }

  void setReminderHour(int hour) {
    _prefs.setInt('reminder_hour', hour);
    state = state.copyWith(reminderHour: hour);
  }

  void setReminderMinute(int minute) {
    _prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderMinute: minute);
  }

  void setReminderTime(int hour, int minute) {
    _prefs.setInt('reminder_hour', hour);
    _prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);
  }

  void setShowReadingPracticeOnMobile(bool show) {
    _prefs.setBool('show_reading_mobile', show);
    state = state.copyWith(showReadingPracticeOnMobile: show);
  }
}
```

- [ ] **Step 5: Run tests — should pass now**

```bash
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: all tests pass, including the new `showReadingPracticeOnMobile` tests.

- [ ] **Step 6: Re-generate Riverpod code**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `user_settings_provider.g.dart` regenerated without errors.

- [ ] **Step 7: Add Settings toggle to settings_screen.dart**

In `lib/features/settings/presentation/screens/settings_screen.dart`, add `import 'package:flutter/foundation.dart' show kIsWeb;` at the top, then add the following ListTile inside the `// ── Học tập ───────────────────────────────────────────` section, AFTER the existing `ListTile` for "Cấp độ mục tiêu":

```dart
if (!kIsWeb)
  SwitchListTile(
    title: const Text('Hiện tab Luyện đọc & gõ trên điện thoại'),
    subtitle:
        const Text('Mặc định ẩn trên mobile — bật nếu bạn muốn dùng'),
    value: settings.showReadingPracticeOnMobile,
    onChanged: (v) =>
        notifier.setShowReadingPracticeOnMobile(v),
  ),
```

The full "Học tập" section after this change should look like:

```dart
// ── Học tập ───────────────────────────────────────────
_SectionHeader('Học tập'),
ListTile(
  title: const Text('Ngôn ngữ mục tiêu'),
  trailing: DropdownButton<Language>(
    value: settings.targetLanguage,
    underline: const SizedBox(),
    items: Language.values
        .map((l) => DropdownMenuItem(
              value: l,
              child: Text(l.label),
            ))
        .toList(),
    onChanged: (l) {
      if (l != null) notifier.setTargetLanguage(l);
    },
  ),
),
ListTile(
  title: const Text('Cấp độ mục tiêu'),
  subtitle: Text(
    settings.targetCefrLevel?.label ?? 'Tất cả',
    style: theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.primary),
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () =>
      _showCefrPicker(context, ref, settings.targetCefrLevel),
),
if (!kIsWeb)
  SwitchListTile(
    title: const Text('Hiện tab Luyện đọc & gõ trên điện thoại'),
    subtitle:
        const Text('Mặc định ẩn trên mobile — bật nếu bạn muốn dùng'),
    value: settings.showReadingPracticeOnMobile,
    onChanged: (v) =>
        notifier.setShowReadingPracticeOnMobile(v),
  ),
```

- [ ] **Step 8: Run analyze**

```bash
flutter analyze lib/features/dictionary/domain/entities/user_settings_state.dart \
               lib/features/dictionary/presentation/providers/user_settings_provider.dart \
               lib/features/settings/presentation/screens/settings_screen.dart
```

Expected: no issues found.

- [ ] **Step 9: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
git add lib/features/dictionary/domain/entities/user_settings_state.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.g.dart \
        lib/features/settings/presentation/screens/settings_screen.dart \
        test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan6): add showReadingPracticeOnMobile setting with toggle"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Build: flutter analyze output
Concerns: (if any)
