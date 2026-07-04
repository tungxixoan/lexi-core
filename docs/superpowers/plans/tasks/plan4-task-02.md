# Plan 4 — Task 02: UserSettingsState + SharedPreferences persistence

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (`sharedPreferencesProvider` exists)

## What this task builds

- Adds `targetCefrLevel: CEFRLevel?` to `UserSettingsState`
- Updates `UserSettingsNotifier` to read initial state from `SharedPreferences` and write back on every setter
- Adds sentinel-object pattern to `copyWith` for the nullable `targetCefrLevel` field
- 5 unit tests

## Files

- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Create: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

## Interfaces consumed

```dart
sharedPreferencesProvider  // from Task 01 — in user_settings_provider.dart
CEFRLevel                  // lib/features/vocabulary/domain/entities/cefr_level.dart
// CEFRLevel.values.byName('b2') → CEFRLevel.b2
// CEFRLevel.b2.name → 'b2'
```

## Interfaces produced

```dart
// UserSettingsState (updated):
final class UserSettingsState {
  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;  // NEW — null = no CEFR filter
  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
    targetCefrLevel: null,
  );
  UserSettingsState copyWith({
    Language? targetLanguage, AppContext? activeContext, bool? aiEnabled,
    String? geminiApiKey,
    Object? targetCefrLevel,  // sentinel: default = _absent, null = clear filter
  });
}

// UserSettingsNotifier (updated):
// build() reads from SharedPreferences
void setTargetLanguage(Language lang)          // writes 'target_language'
void setActiveContext(AppContext ctx)           // writes 'active_context'
void setAiEnabled({required bool enabled})      // writes 'ai_enabled'
void setGeminiApiKey(String key)                // writes 'gemini_api_key'
void setTargetCefrLevel(CEFRLevel? level)       // NEW — writes/removes 'target_cefr_level'
```

---

- [ ] **Step 1: Update UserSettingsState**

Replace `lib/features/dictionary/domain/entities/user_settings_state.dart` with:

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
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final String geminiApiKey;
  final CEFRLevel? targetCefrLevel;

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    String? geminiApiKey,
    Object? targetCefrLevel = _absent,
  }) =>
      UserSettingsState(
        targetLanguage: targetLanguage ?? this.targetLanguage,
        activeContext: activeContext ?? this.activeContext,
        aiEnabled: aiEnabled ?? this.aiEnabled,
        geminiApiKey: geminiApiKey ?? this.geminiApiKey,
        targetCefrLevel: identical(targetCefrLevel, _absent)
            ? this.targetCefrLevel
            : targetCefrLevel as CEFRLevel?,
      );

  static const defaults = UserSettingsState(
    targetLanguage: Language.english,
    activeContext: AppContext.general,
    aiEnabled: false,
    geminiApiKey: '',
    targetCefrLevel: null,
  );
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> makeContainer(
    {Map<String, Object> initialValues = const {}}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UserSettingsNotifier', () {
    test('build() returns defaults when SharedPreferences is empty', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.english);
      expect(state.activeContext, AppContext.general);
      expect(state.aiEnabled, false);
      expect(state.geminiApiKey, '');
      expect(state.targetCefrLevel, isNull);
    });

    test('build() loads persisted values from SharedPreferences', () async {
      final container = await makeContainer(initialValues: {
        'target_language': 'chinese',
        'active_context': 'business',
        'ai_enabled': true,
        'gemini_api_key': 'test-key',
        'target_cefr_level': 'b2',
      });
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.chinese);
      expect(state.activeContext, AppContext.business);
      expect(state.aiEnabled, true);
      expect(state.geminiApiKey, 'test-key');
      expect(state.targetCefrLevel, CEFRLevel.b2);
    });

    test('setTargetLanguage() updates state and writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetLanguage(Language.japanese);
      expect(container.read(userSettingsNotifierProvider).targetLanguage,
          Language.japanese);
      expect(prefs.getString('target_language'), 'japanese');
    });

    test('setTargetCefrLevel(null) removes key from prefs', () async {
      final container =
          await makeContainer(initialValues: {'target_cefr_level': 'b1'});
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetCefrLevel(null);
      expect(container.read(userSettingsNotifierProvider).targetCefrLevel,
          isNull);
      expect(prefs.containsKey('target_cefr_level'), false);
    });

    test('setTargetCefrLevel(b2) updates state and writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier)
          .setTargetCefrLevel(CEFRLevel.b2);
      expect(container.read(userSettingsNotifierProvider).targetCefrLevel,
          CEFRLevel.b2);
      expect(prefs.getString('target_cefr_level'), 'b2');
    });
  });
}
```

- [ ] **Step 3: Run tests to confirm they fail**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: FAIL — `UserSettingsNotifier.build()` still returns `UserSettingsState.defaults` without reading prefs, and there's no `setTargetCefrLevel` method yet.

- [ ] **Step 4: Update UserSettingsNotifier**

Replace the full content of `lib/features/dictionary/presentation/providers/user_settings_provider.dart` with:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

part 'user_settings_provider.g.dart';

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
}
```

- [ ] **Step 5: Run build_runner**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: `user_settings_provider.g.dart` regenerated.

- [ ] **Step 6: Run tests — expect all pass**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: 5/5 PASS.

- [ ] **Step 7: Run full suite**

```
flutter test
```

Expected: all prior tests still pass + 5 new ones.

- [ ] **Step 8: Analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 9: Commit**

```
git add lib/features/dictionary/domain/entities/user_settings_state.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat(plan4): persist UserSettings to SharedPreferences, add targetCefrLevel"
```

## Self-review checklist

- [ ] `UserSettingsState` has `targetCefrLevel: CEFRLevel?` (nullable, not required)
- [ ] `copyWith` uses `_absent` sentinel so `copyWith(targetCefrLevel: null)` clears the field
- [ ] `UserSettingsNotifier` is `@Riverpod(keepAlive: true)` (not auto-dispose)
- [ ] `build()` uses `ref.watch(sharedPreferencesProvider)` (not `ref.read`)
- [ ] Setters use `ref.read(sharedPreferencesProvider)` (not `ref.watch`)
- [ ] `geminiApiKey` setter writes to prefs key `'gemini_api_key'` (local only — no Firestore here)
- [ ] 5/5 tests pass
- [ ] Full suite still passes
