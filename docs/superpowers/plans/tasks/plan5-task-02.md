# Plan 5 — Task 02: UserSettingsState Reminder Fields + Setters

**Context:** Task 02 of Plan 5. Task 01 (packages) must be complete first. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Produces:
  - `UserSettingsState.reminderEnabled: bool` (default `false`)
  - `UserSettingsState.reminderHour: int` (default `20`)
  - `UserSettingsState.reminderMinute: int` (default `0`)
  - `UserSettingsNotifier.setReminderEnabled({required bool enabled})`
  - `UserSettingsNotifier.setReminderHour(int hour)`
  - `UserSettingsNotifier.setReminderMinute(int minute)`
- These are consumed by Tasks 06 (NotificationNotifier) and 08 (SettingsScreen).

---

- [ ] **Step 1: Write failing tests**

Add to `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` inside `main()`:

```dart
  group('reminder settings', () {
    test('reminderEnabled defaults to false', () {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      expect(container.read(userSettingsNotifierProvider).reminderEnabled, false);
    });

    test('setReminderEnabled persists to prefs and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      container.read(userSettingsNotifierProvider.notifier).setReminderEnabled(enabled: true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('reminder_enabled'), true);
      expect(container.read(userSettingsNotifierProvider).reminderEnabled, true);
    });

    test('reminderHour defaults to 20 and setReminderHour persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      expect(container.read(userSettingsNotifierProvider).reminderHour, 20);
      container.read(userSettingsNotifierProvider.notifier).setReminderHour(8);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminder_hour'), 8);
      expect(container.read(userSettingsNotifierProvider).reminderHour, 8);
    });
  });
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL (reminderEnabled not found on UserSettingsState).

- [ ] **Step 3: Replace UserSettingsState**

Replace the full content of `lib/features/dictionary/domain/entities/user_settings_state.dart`:

```dart
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
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;

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
  );
}
```

- [ ] **Step 4: Replace UserSettingsNotifier**

Replace the full content of `lib/features/dictionary/presentation/providers/user_settings_provider.dart`:

```dart
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
}
```

- [ ] **Step 5: Run tests — now pass**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: all tests pass (existing + 3 new).

- [ ] **Step 6: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```
git add lib/features/dictionary/domain/entities/user_settings_state.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.dart \
        test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan5): add reminderEnabled/Hour/Minute to UserSettingsState and notifier"
```

**Report status:** DONE
