# Multi-Provider AI Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded Gemini API key with a multi-provider AI settings system supporting Gemini, Groq, and OpenRouter — with per-provider model and key memory when switching providers.

**Architecture:** New `AiProvider` enum + `ProviderConfig` value object replace `geminiApiKey` in `UserSettingsState`. A single `AiClientFactory` translates the active config into the correct `GenerativeModelClient` (Gemini SDK or OpenAI-compatible HTTP). All three AI sources consume the factory instead of constructing `GenerativeModel` directly. All config stays in SharedPreferences — never Firestore.

**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, `google_generative_ai` SDK (Gemini), `http` package (Groq/OpenRouter). The `http` package is already a dependency at `^1.2.2`.

## Global Constraints

- `geminiApiKey` and all provider API keys MUST NEVER be written to Firestore — SharedPreferences only.
- `SyncService` only syncs `targetLanguage`, `activeContext`, `aiEnabled`, `targetCefrLevel` — provider/model/key fields never appear there.
- Migration from old `gemini_api_key` SharedPreferences key must be automatic and silent on first launch.
- `UserSettingsState.defaults` must be `const` — `ProviderConfig` must have a `const` constructor.
- Existing `.withModel()` / `.withClient()` test constructors on AI sources must be preserved unchanged — those tests must still pass.
- The `GenerativeModelClient` interface visible to test files importing `gemini_dictionary_source.dart` and `reading_passage_source.dart` must remain importable from those paths (re-export from factory file).
- `aiEnabled` toggle behavior unchanged — when false, AI features are disabled regardless of provider.
- No placeholders, TBD, or incomplete steps. Every step contains the actual code or command needed.

---

## File Map

| File | Action |
|------|--------|
| `lib/features/dictionary/domain/entities/ai_provider.dart` | **Create** — `AiProvider` enum + `AiProviderX` extension |
| `lib/features/dictionary/domain/entities/provider_config.dart` | **Create** — `ProviderConfig` value object |
| `lib/features/dictionary/domain/entities/user_settings_state.dart` | **Modify** — remove `geminiApiKey`, add `activeProvider` + `providerConfigs` + `activeConfig` getter |
| `lib/features/dictionary/presentation/providers/user_settings_provider.dart` | **Modify** — migration logic + new setters, remove `setGeminiApiKey` |
| `lib/core/services/ai_client_factory.dart` | **Create** — shared `GenerativeModelClient` interface + `AiClientFactory` + `_GeminiClient` + `_OpenAiClient` |
| `lib/features/dictionary/data/sources/gemini_dictionary_source.dart` | **Modify** — remove local interface, re-export from factory, new constructor |
| `lib/features/practice/data/sources/exercise_generator_source.dart` | **Modify** — remove `ExerciseGeneratorClient`, import `GenerativeModelClient` from factory, new constructor |
| `lib/features/reading/data/sources/reading_passage_source.dart` | **Modify** — remove local interface, re-export from factory, new constructor |
| `lib/core/di/app_providers.dart` | **Modify** — providers watch full settings, call factory constructor |
| `lib/features/settings/presentation/screens/settings_screen.dart` | **Modify** — provider picker, model dropdown, per-provider API key |
| `test/features/dictionary/domain/entities/ai_provider_test.dart` | **Create** |
| `test/features/dictionary/domain/entities/provider_config_test.dart` | **Create** |
| `test/core/services/ai_client_factory_test.dart` | **Create** |
| `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` | **Modify** — remove `geminiApiKey` tests, add migration + new-method tests |

---

### Task 1: Domain Entities (`AiProvider` + `ProviderConfig`)

**Files:**
- Create: `lib/features/dictionary/domain/entities/ai_provider.dart`
- Create: `lib/features/dictionary/domain/entities/provider_config.dart`
- Create: `test/features/dictionary/domain/entities/ai_provider_test.dart`
- Create: `test/features/dictionary/domain/entities/provider_config_test.dart`

**Interfaces:**
- Produces:
  - `enum AiProvider { gemini, groq, openRouter }` with `AiProviderX` extension methods: `label`, `baseUrl`, `defaultModel`, `modelPresets`
  - `final class ProviderConfig` with `const` constructor `({required String apiKey, required String model})`, fields `apiKey`/`model`, getter `isConfigured`, `toJson()`, `factory ProviderConfig.fromJson(Map<String,dynamic>)`, `static ProviderConfig empty(AiProvider)`

---

- [ ] **Step 1.1: Write failing tests for `AiProvider`**

```dart
// test/features/dictionary/domain/entities/ai_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';

void main() {
  group('AiProvider labels', () {
    test('gemini label', () => expect(AiProvider.gemini.label, 'Gemini'));
    test('groq label', () => expect(AiProvider.groq.label, 'Groq'));
    test('openRouter label', () => expect(AiProvider.openRouter.label, 'OpenRouter'));
  });

  group('AiProvider baseUrl', () {
    test('gemini has empty baseUrl (uses SDK)', () => expect(AiProvider.gemini.baseUrl, ''));
    test('groq baseUrl', () => expect(AiProvider.groq.baseUrl, 'https://api.groq.com/openai/v1'));
    test('openRouter baseUrl', () => expect(AiProvider.openRouter.baseUrl, 'https://openrouter.ai/api/v1'));
  });

  group('AiProvider defaultModel', () {
    test('gemini default model', () => expect(AiProvider.gemini.defaultModel, 'gemini-2.5-flash'));
    test('groq default model', () => expect(AiProvider.groq.defaultModel, 'llama-3.3-70b-versatile'));
    test('openRouter default model', () =>
        expect(AiProvider.openRouter.defaultModel, 'meta-llama/llama-3.3-70b-instruct'));
  });

  group('AiProvider modelPresets', () {
    test('gemini has 4 presets starting with gemini-2.5-flash', () {
      expect(AiProvider.gemini.modelPresets.first, 'gemini-2.5-flash');
      expect(AiProvider.gemini.modelPresets, hasLength(4));
    });
    test('groq has 4 presets starting with llama-3.3-70b-versatile', () {
      expect(AiProvider.groq.modelPresets.first, 'llama-3.3-70b-versatile');
      expect(AiProvider.groq.modelPresets, hasLength(4));
    });
    test('openRouter has 4 presets', () => expect(AiProvider.openRouter.modelPresets, hasLength(4)));
    test('every defaultModel is first in its modelPresets', () {
      for (final p in AiProvider.values) {
        expect(p.modelPresets.first, p.defaultModel,
            reason: '${p.name}.defaultModel should be first in modelPresets');
      }
    });
  });
}
```

- [ ] **Step 1.2: Run tests — expect compile error (file doesn't exist yet)**

```
flutter test test/features/dictionary/domain/entities/ai_provider_test.dart
```

Expected: `Error: Cannot find 'AiProvider'`

- [ ] **Step 1.3: Create `ai_provider.dart`**

```dart
// lib/features/dictionary/domain/entities/ai_provider.dart
enum AiProvider { gemini, groq, openRouter }

extension AiProviderX on AiProvider {
  String get label => switch (this) {
        AiProvider.gemini => 'Gemini',
        AiProvider.groq => 'Groq',
        AiProvider.openRouter => 'OpenRouter',
      };

  String get baseUrl => switch (this) {
        AiProvider.gemini => '',
        AiProvider.groq => 'https://api.groq.com/openai/v1',
        AiProvider.openRouter => 'https://openrouter.ai/api/v1',
      };

  String get defaultModel => switch (this) {
        AiProvider.gemini => 'gemini-2.5-flash',
        AiProvider.groq => 'llama-3.3-70b-versatile',
        AiProvider.openRouter => 'meta-llama/llama-3.3-70b-instruct',
      };

  List<String> get modelPresets => switch (this) {
        AiProvider.gemini => [
            'gemini-2.5-flash',
            'gemini-2.5-pro',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
          ],
        AiProvider.groq => [
            'llama-3.3-70b-versatile',
            'llama-3.1-8b-instant',
            'mixtral-8x7b-32768',
            'gemma2-9b-it',
          ],
        AiProvider.openRouter => [
            'meta-llama/llama-3.3-70b-instruct',
            'google/gemini-2.5-flash',
            'anthropic/claude-haiku-4-5',
            'mistralai/mixtral-8x7b-instruct',
          ],
      };
}
```

- [ ] **Step 1.4: Run `AiProvider` tests — expect PASS**

```
flutter test test/features/dictionary/domain/entities/ai_provider_test.dart
```

Expected: All 10 tests pass.

- [ ] **Step 1.5: Write failing tests for `ProviderConfig`**

```dart
// test/features/dictionary/domain/entities/provider_config_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';

void main() {
  group('ProviderConfig.isConfigured', () {
    test('false when apiKey is empty', () {
      const c = ProviderConfig(apiKey: '', model: 'gemini-2.5-flash');
      expect(c.isConfigured, false);
    });
    test('false when model is empty', () {
      const c = ProviderConfig(apiKey: 'my-key', model: '');
      expect(c.isConfigured, false);
    });
    test('true when both are non-empty', () {
      const c = ProviderConfig(apiKey: 'my-key', model: 'gemini-2.5-flash');
      expect(c.isConfigured, true);
    });
  });

  group('ProviderConfig toJson / fromJson round-trip', () {
    test('round-trip preserves apiKey and model', () {
      const original = ProviderConfig(apiKey: 'test-key-123', model: 'llama-3.3-70b-versatile');
      final restored = ProviderConfig.fromJson(original.toJson());
      expect(restored.apiKey, original.apiKey);
      expect(restored.model, original.model);
    });
    test('fromJson with missing keys returns empty strings', () {
      final c = ProviderConfig.fromJson({});
      expect(c.apiKey, '');
      expect(c.model, '');
    });
  });

  group('ProviderConfig.empty', () {
    test('empty Gemini uses gemini-2.5-flash default model', () {
      final c = ProviderConfig.empty(AiProvider.gemini);
      expect(c.apiKey, '');
      expect(c.model, 'gemini-2.5-flash');
    });
    test('empty Groq uses llama-3.3-70b-versatile default model', () {
      final c = ProviderConfig.empty(AiProvider.groq);
      expect(c.model, 'llama-3.3-70b-versatile');
    });
    test('empty OpenRouter uses meta-llama/llama-3.3-70b-instruct default model', () {
      final c = ProviderConfig.empty(AiProvider.openRouter);
      expect(c.model, 'meta-llama/llama-3.3-70b-instruct');
    });
  });
}
```

- [ ] **Step 1.6: Run tests — expect compile error**

```
flutter test test/features/dictionary/domain/entities/provider_config_test.dart
```

Expected: `Error: Cannot find 'ProviderConfig'`

- [ ] **Step 1.7: Create `provider_config.dart`**

```dart
// lib/features/dictionary/domain/entities/provider_config.dart
import 'ai_provider.dart';

final class ProviderConfig {
  const ProviderConfig({required this.apiKey, required this.model});

  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty && model.isNotEmpty;

  Map<String, dynamic> toJson() => {'apiKey': apiKey, 'model': model};

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? '',
      );

  static ProviderConfig empty(AiProvider provider) =>
      ProviderConfig(apiKey: '', model: provider.defaultModel);
}
```

- [ ] **Step 1.8: Run `ProviderConfig` tests — expect PASS**

```
flutter test test/features/dictionary/domain/entities/provider_config_test.dart
```

Expected: All 8 tests pass.

- [ ] **Step 1.9: Commit**

```
git add lib/features/dictionary/domain/entities/ai_provider.dart \
        lib/features/dictionary/domain/entities/provider_config.dart \
        test/features/dictionary/domain/entities/ai_provider_test.dart \
        test/features/dictionary/domain/entities/provider_config_test.dart
git commit -m "feat: add AiProvider enum and ProviderConfig value object"
```

---

### Task 2: Update `UserSettingsState` + `UserSettingsNotifier` + Tests

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Consumes (from Task 1): `AiProvider`, `ProviderConfig`
- Produces:
  - `UserSettingsState` with fields `activeProvider: AiProvider`, `providerConfigs: Map<AiProvider, ProviderConfig>`, getter `ProviderConfig get activeConfig`
  - `UserSettingsNotifier` methods: `setActiveProvider(AiProvider)`, `setProviderConfig(AiProvider, ProviderConfig)`, `setApiKeyForActiveProvider(String)`, `setModelForActiveProvider(String)`
  - SharedPreferences keys written: `ai_active_provider` (provider name string), `ai_config_gemini` / `ai_config_groq` / `ai_config_openRouter` (JSON strings)
  - Migration: if `ai_active_provider` absent and `gemini_api_key` present → migrate and delete old key

---

- [ ] **Step 2.1: Update `UserSettingsState`**

Replace the entire file content:

```dart
// lib/features/dictionary/domain/entities/user_settings_state.dart
import '../../../vocabulary/domain/entities/cefr_level.dart';
import 'ai_provider.dart';
import 'app_context.dart';
import 'language.dart';
import 'provider_config.dart';

final class UserSettingsState {
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.activeProvider,
    required this.providerConfigs,
    this.targetCefrLevel,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.showReadingPracticeOnMobile = false,
  });

  final Language targetLanguage;
  final AppContext activeContext;
  final bool aiEnabled;
  final AiProvider activeProvider;
  final Map<AiProvider, ProviderConfig> providerConfigs;
  final CEFRLevel? targetCefrLevel;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool showReadingPracticeOnMobile;

  // The active provider's config. Falls back to an empty default if not yet configured.
  ProviderConfig get activeConfig =>
      providerConfigs[activeProvider] ?? ProviderConfig.empty(activeProvider);

  static const _absent = Object();

  UserSettingsState copyWith({
    Language? targetLanguage,
    AppContext? activeContext,
    bool? aiEnabled,
    AiProvider? activeProvider,
    Map<AiProvider, ProviderConfig>? providerConfigs,
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
        activeProvider: activeProvider ?? this.activeProvider,
        providerConfigs: providerConfigs ?? this.providerConfigs,
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
    activeProvider: AiProvider.gemini,
    providerConfigs: {
      AiProvider.gemini: ProviderConfig(apiKey: '', model: 'gemini-2.5-flash'),
    },
    targetCefrLevel: null,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
    showReadingPracticeOnMobile: false,
  );
}
```

- [ ] **Step 2.2: Update `UserSettingsNotifier`**

Replace the entire file content:

```dart
// lib/features/dictionary/presentation/providers/user_settings_provider.dart
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/ai_provider.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/provider_config.dart';
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

    // One-time silent migration from old gemini_api_key to new ai_config_* keys.
    if (!prefs.containsKey('ai_active_provider') &&
        prefs.containsKey('gemini_api_key')) {
      final oldKey = prefs.getString('gemini_api_key') ?? '';
      prefs.setString(
        'ai_config_gemini',
        jsonEncode({'apiKey': oldKey, 'model': 'gemini-2.5-flash'}),
      );
      prefs.setString('ai_active_provider', 'gemini');
      prefs.remove('gemini_api_key');
    }

    final activeProvider = AiProvider.values.byName(
      prefs.getString('ai_active_provider') ?? AiProvider.gemini.name,
    );

    final providerConfigs = <AiProvider, ProviderConfig>{};
    for (final provider in AiProvider.values) {
      final raw = prefs.getString('ai_config_${provider.name}');
      if (raw != null) {
        providerConfigs[provider] =
            ProviderConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    }

    return UserSettingsState(
      targetLanguage: Language.values.byName(
          prefs.getString('target_language') ?? Language.english.name),
      activeContext: AppContext.values.byName(
          prefs.getString('active_context') ?? AppContext.general.name),
      aiEnabled: prefs.getBool('ai_enabled') ?? false,
      activeProvider: activeProvider,
      providerConfigs: providerConfigs,
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

  void setActiveProvider(AiProvider provider) {
    _prefs.setString('ai_active_provider', provider.name);
    state = state.copyWith(activeProvider: provider);
  }

  void setProviderConfig(AiProvider provider, ProviderConfig config) {
    _prefs.setString(
      'ai_config_${provider.name}',
      jsonEncode(config.toJson()),
    );
    final updated = Map<AiProvider, ProviderConfig>.from(state.providerConfigs);
    updated[provider] = config;
    state = state.copyWith(providerConfigs: updated);
  }

  void setApiKeyForActiveProvider(String key) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKey: key, model: current.model),
    );
  }

  void setModelForActiveProvider(String model) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKey: current.apiKey, model: model),
    );
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

- [ ] **Step 2.3: Run codegen**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: Exits 0. Regenerates `user_settings_provider.g.dart`.

- [ ] **Step 2.4: Update `user_settings_notifier_test.dart`**

Replace the entire file content:

```dart
// test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
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
      expect(state.activeProvider, AiProvider.gemini);
      expect(state.providerConfigs, isEmpty);
      expect(state.activeConfig.apiKey, '');
      expect(state.activeConfig.model, 'gemini-2.5-flash');
      expect(state.targetCefrLevel, isNull);
    });

    test('build() loads persisted provider and config from SharedPreferences', () async {
      final container = await makeContainer(initialValues: {
        'target_language': 'chinese',
        'active_context': 'business',
        'ai_enabled': true,
        'ai_active_provider': 'groq',
        'ai_config_groq': jsonEncode({'apiKey': 'gsk_test', 'model': 'llama-3.3-70b-versatile'}),
        'target_cefr_level': 'b2',
      });
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.chinese);
      expect(state.activeContext, AppContext.business);
      expect(state.aiEnabled, true);
      expect(state.activeProvider, AiProvider.groq);
      expect(state.activeConfig.apiKey, 'gsk_test');
      expect(state.activeConfig.model, 'llama-3.3-70b-versatile');
      expect(state.targetCefrLevel, CEFRLevel.b2);
    });

    group('migration from old gemini_api_key', () {
      test('migrates old gemini_api_key to ai_config_gemini on build()', () async {
        final container = await makeContainer(initialValues: {
          'gemini_api_key': 'old-key-xyz',
        });
        addTearDown(container.dispose);
        final prefs = container.read(sharedPreferencesProvider);
        final state = container.read(userSettingsNotifierProvider);

        expect(state.activeProvider, AiProvider.gemini);
        expect(state.activeConfig.apiKey, 'old-key-xyz');
        expect(state.activeConfig.model, 'gemini-2.5-flash');

        // Old key must be removed; new keys must exist.
        expect(prefs.containsKey('gemini_api_key'), false);
        expect(prefs.containsKey('ai_active_provider'), true);
        expect(prefs.containsKey('ai_config_gemini'), true);

        final geminiJson =
            jsonDecode(prefs.getString('ai_config_gemini')!) as Map<String, dynamic>;
        expect(geminiJson['apiKey'], 'old-key-xyz');
        expect(geminiJson['model'], 'gemini-2.5-flash');
      });

      test('does not migrate when ai_active_provider already exists', () async {
        final container = await makeContainer(initialValues: {
          'gemini_api_key': 'should-not-migrate',
          'ai_active_provider': 'groq',
        });
        addTearDown(container.dispose);
        final prefs = container.read(sharedPreferencesProvider);
        container.read(userSettingsNotifierProvider); // trigger build

        // Old key must still be present (migration skipped).
        expect(prefs.containsKey('gemini_api_key'), true);
        expect(prefs.containsKey('ai_config_gemini'), false);
      });
    });

    test('setActiveProvider() updates state and writes to prefs', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      container.read(userSettingsNotifierProvider.notifier).setActiveProvider(AiProvider.groq);
      expect(container.read(userSettingsNotifierProvider).activeProvider, AiProvider.groq);
      expect(prefs.getString('ai_active_provider'), 'groq');
    });

    test('setProviderConfig() persists JSON and updates state', () async {
      final container = await makeContainer();
      addTearDown(container.dispose);
      final prefs = container.read(sharedPreferencesProvider);
      const config = ProviderConfig(apiKey: 'my-key', model: 'llama-3.1-8b-instant');
      container
          .read(userSettingsNotifierProvider.notifier)
          .setProviderConfig(AiProvider.groq, config);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs[AiProvider.groq]?.apiKey, 'my-key');
      expect(state.providerConfigs[AiProvider.groq]?.model, 'llama-3.1-8b-instant');
      final stored = jsonDecode(prefs.getString('ai_config_groq')!) as Map<String, dynamic>;
      expect(stored['apiKey'], 'my-key');
      expect(stored['model'], 'llama-3.1-8b-instant');
    });

    test('setApiKeyForActiveProvider() keeps model, updates key', () async {
      final container = await makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKey': 'old', 'model': 'gemini-2.5-pro'}),
      });
      addTearDown(container.dispose);
      container
          .read(userSettingsNotifierProvider.notifier)
          .setApiKeyForActiveProvider('new-key');
      final config = container.read(userSettingsNotifierProvider).activeConfig;
      expect(config.apiKey, 'new-key');
      expect(config.model, 'gemini-2.5-pro'); // model unchanged
    });

    test('setModelForActiveProvider() keeps key, updates model', () async {
      final container = await makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKey': 'test-key', 'model': 'gemini-2.5-flash'}),
      });
      addTearDown(container.dispose);
      container
          .read(userSettingsNotifierProvider.notifier)
          .setModelForActiveProvider('gemini-2.5-pro');
      final config = container.read(userSettingsNotifierProvider).activeConfig;
      expect(config.model, 'gemini-2.5-pro');
      expect(config.apiKey, 'test-key'); // key unchanged
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

    group('reminder settings', () {
      test('reminderEnabled defaults to false', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        expect(container.read(userSettingsNotifierProvider).reminderEnabled, false);
      });

      test('setReminderEnabled persists to prefs and updates state', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setReminderEnabled(enabled: true);
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getBool('reminder_enabled'), true);
        expect(container.read(userSettingsNotifierProvider).reminderEnabled, true);
      });

      test('reminderHour defaults to 20 and setReminderHour persists', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        expect(container.read(userSettingsNotifierProvider).reminderHour, 20);
        container.read(userSettingsNotifierProvider.notifier).setReminderHour(8);
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getInt('reminder_hour'), 8);
        expect(container.read(userSettingsNotifierProvider).reminderHour, 8);
      });
    });

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
  });
}
```

- [ ] **Step 2.5: Run the notifier test suite**

```
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
```

Expected: All tests pass. (The state and notifier changes compile at this point; other source files referencing `geminiApiKey` will fail to compile but those are fixed in Task 4.)

- [ ] **Step 2.6: Commit**

```
git add lib/features/dictionary/domain/entities/user_settings_state.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.dart \
        lib/features/dictionary/presentation/providers/user_settings_provider.g.dart \
        test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat: replace geminiApiKey with multi-provider activeProvider/providerConfigs in settings"
```

---

### Task 3: Create `AiClientFactory`

**Files:**
- Create: `lib/core/services/ai_client_factory.dart`
- Create: `test/core/services/ai_client_factory_test.dart`

**Interfaces:**
- Consumes (from Task 1): `AiProvider`, `ProviderConfig`
- Consumes (from Task 2): `UserSettingsState.activeProvider`, `UserSettingsState.activeConfig`
- Produces:
  - `abstract interface class GenerativeModelClient` — `Future<GenerateContentResponse> generateContent(Iterable<Content> prompt)`
  - `class AiClientFactory` — `static GenerativeModelClient buildClient(UserSettingsState settings)`
  - Re-exported by `gemini_dictionary_source.dart` and `reading_passage_source.dart` in Task 4

---

- [ ] **Step 3.1: Write failing test**

```dart
// test/core/services/ai_client_factory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/ai_client_factory.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';

UserSettingsState _settingsFor(AiProvider provider, String model) =>
    UserSettingsState.defaults.copyWith(
      activeProvider: provider,
      providerConfigs: {
        provider: ProviderConfig(apiKey: 'test-key', model: model),
      },
    );

void main() {
  group('AiClientFactory.buildClient', () {
    test('returns GenerativeModelClient for Gemini', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.gemini, 'gemini-2.5-flash'),
      );
      expect(client, isA<GenerativeModelClient>());
    });

    test('returns GenerativeModelClient for Groq', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.groq, 'llama-3.3-70b-versatile'),
      );
      expect(client, isA<GenerativeModelClient>());
    });

    test('returns GenerativeModelClient for OpenRouter', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.openRouter, 'meta-llama/llama-3.3-70b-instruct'),
      );
      expect(client, isA<GenerativeModelClient>());
    });
  });
}
```

- [ ] **Step 3.2: Run test — expect compile error**

```
flutter test test/core/services/ai_client_factory_test.dart
```

Expected: `Error: Cannot find 'AiClientFactory'`

- [ ] **Step 3.3: Create `ai_client_factory.dart`**

```dart
// lib/core/services/ai_client_factory.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:http/http.dart' as http;
import '../../features/dictionary/domain/entities/ai_provider.dart';
import '../../features/dictionary/domain/entities/user_settings_state.dart';

/// Shared AI client interface used by all three AI sources.
abstract interface class GenerativeModelClient {
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
}

class AiClientFactory {
  const AiClientFactory._();

  /// Builds the correct [GenerativeModelClient] for [settings.activeProvider].
  static GenerativeModelClient buildClient(UserSettingsState settings) {
    final config = settings.activeConfig;
    return switch (settings.activeProvider) {
      AiProvider.gemini => _GeminiClient(
          apiKey: config.apiKey,
          model: config.model,
        ),
      AiProvider.groq || AiProvider.openRouter => _OpenAiClient(
          apiKey: config.apiKey,
          model: config.model,
          baseUrl: settings.activeProvider.baseUrl,
        ),
    };
  }
}

final class _GeminiClient implements GenerativeModelClient {
  _GeminiClient({required String apiKey, required String model})
      : _model = GenerativeModel(
          model: model,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  final GenerativeModel _model;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) =>
      _model.generateContent(prompt);
}

final class _OpenAiClient implements GenerativeModelClient {
  _OpenAiClient({
    required String apiKey,
    required String model,
    required String baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _model = model,
        _baseUrl = baseUrl,
        _http = httpClient ?? http.Client();

  final String _apiKey;
  final String _model;
  final String _baseUrl;
  final http.Client _http;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    final text = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');

    final response = await _http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': text},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'AI API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content =
        (json['choices'] as List).first['message']['content'] as String;
    return GenerateContentResponse(
      [Candidate(Content.text(content), null, null, null, null)],
      null,
    );
  }
}
```

- [ ] **Step 3.4: Run factory test — expect PASS**

```
flutter test test/core/services/ai_client_factory_test.dart
```

Expected: All 3 tests pass.

- [ ] **Step 3.5: Commit**

```
git add lib/core/services/ai_client_factory.dart \
        test/core/services/ai_client_factory_test.dart
git commit -m "feat: add AiClientFactory with Gemini SDK and OpenAI-compatible HTTP client"
```

---

### Task 4: Update AI Sources + DI Provider

**Files:**
- Modify: `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`
- Modify: `lib/features/practice/data/sources/exercise_generator_source.dart`
- Modify: `lib/features/reading/data/sources/reading_passage_source.dart`
- Modify: `lib/core/di/app_providers.dart`

**Interfaces:**
- Consumes (from Task 3): `GenerativeModelClient`, `AiClientFactory.buildClient(settings)`
- Consumes (from Task 2): `UserSettingsState` (full object passed to factory)
- Preserves: `.withModel(GenerativeModelClient)` / `.withClient(GenerativeModelClient)` test constructors remain unchanged; existing source tests must still pass.

---

- [ ] **Step 4.1: Update `gemini_dictionary_source.dart`**

Remove the local interface definition and `_RealModelClient`. Import `GenerativeModelClient` from the factory and re-export it (so the existing test import still resolves). Add a `UserSettingsState`-based production constructor.

Replace the entire file:

```dart
// lib/features/dictionary/data/sources/gemini_dictionary_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/entities/user_settings_state.dart';

// Re-export so existing test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class GeminiDictionarySource {
  GeminiDictionarySource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  /// Constructor for testing — inject any [GenerativeModelClient] fake.
  GeminiDictionarySource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  Future<LookupResult> lookup({
    required String query,
    required InputType inputType,
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt = inputType == InputType.sentence
        ? _sentencePrompt(query)
        : _wordPhrasePrompt(query, inputType, targetLanguage, context);

    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;

    if (inputType == InputType.sentence) {
      return SentenceResult(
        original: query,
        translation: json['translation'] as String,
      );
    }

    return WordPhraseResult(
      headword: json['headword'] as String,
      inputType: inputType,
      ipa: json['ipa'] as String,
      meaning: json['meaning'] as String,
      examples: (json['examples'] as List).cast<String>(),
      suggestedTopics: (json['suggestedTopics'] as List).cast<String>(),
    );
  }

  Future<String> discoverWord({
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt =
        'Suggest one ${targetLanguage.label} vocabulary word for an intermediate learner. '
        'Context: ${context.label}. '
        'Respond with JSON only: {"word": "the word"}';
    final response = await _client.generateContent([Content.text(prompt)]);
    final json = jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    return json['word'] as String;
  }

  String _wordPhrasePrompt(
    String query,
    InputType inputType,
    Language targetLanguage,
    AppContext context,
  ) =>
      'You are a language learning assistant helping a Vietnamese speaker learn ${targetLanguage.label}. '
      'Look up "$query" and respond with JSON only (no markdown, no code fences): '
      '{"headword":"exact word or phrase","ipa":"IPA transcription",'
      '"meaning":"Vietnamese definition",'
      '"examples":["example 1 in ${targetLanguage.label}","example 2"],'
      '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"]} '
      'Shape examples for context: ${context.label}.';

  String _sentencePrompt(String sentence) =>
      'Translate this sentence to Vietnamese: "$sentence" '
      'Respond with JSON only: {"translation":"translated sentence"}';
}
```

- [ ] **Step 4.2: Run `gemini_dictionary_source` tests — expect PASS**

```
flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart
```

Expected: 2 tests pass. (The test's `FakeGenerativeModelClient implements GenerativeModelClient` now resolves via the re-export.)

- [ ] **Step 4.3: Update `exercise_generator_source.dart`**

Remove `ExerciseGeneratorClient` and `_RealClient`. Import `GenerativeModelClient` from factory. No re-export needed (no test imports `ExerciseGeneratorClient` directly). Update constructor.

Replace the entire file:

```dart
// lib/features/practice/data/sources/exercise_generator_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';

class ExerciseGeneratorSource {
  ExerciseGeneratorSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  /// For testing — inject any [GenerativeModelClient].
  ExerciseGeneratorSource.withClient(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  Future<Exercise> generate(VocabRecord record) async {
    final prompt = _buildPrompt(record);
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parseExercise(json, record);
  }

  Exercise _parseExercise(Map<String, dynamic> json, VocabRecord record) {
    final type = json['type'] as String? ?? '';
    return switch (type) {
      'multiple_choice' => MultipleChoiceExercise(
          vocabRecord: record,
          question: json['question'] as String,
          options: (json['options'] as List).cast<String>(),
          correctIndex: json['correctIndex'] as int,
        ),
      'fill_in_blank' => FillInBlankExercise(
          vocabRecord: record,
          sentence: json['sentence'] as String,
          answer: (json['answer'] as String).toLowerCase().trim(),
        ),
      'translation' => TranslationExercise(
          vocabRecord: record,
          prompt: json['prompt'] as String,
          answer: json['answer'] as String,
        ),
      _ => FlashcardExercise(vocabRecord: record),
    };
  }

  String _buildPrompt(VocabRecord record) {
    final examples = record.examples.take(2).join('; ');
    return '''
Generate a vocabulary exercise for a learner studying ${record.targetLanguage.label}.
Word: "${record.headword}"
Meaning: "${record.meaning}"
Examples: "$examples"
CEFR level: ${record.cefrLevel.label}

Choose ONE exercise type appropriate for this CEFR level:
- A1/A2: prefer "multiple_choice"
- B1/B2: prefer "fill_in_blank" or "multiple_choice"
- C1/C2: prefer "translation" or "fill_in_blank"

Respond with JSON only (no markdown), exactly one of these shapes:
{"type":"multiple_choice","question":"What does '${record.headword}' mean?","options":["...","...","...","..."],"correctIndex":0}
{"type":"fill_in_blank","sentence":"A sentence with ___ replacing the word.","answer":"${record.headword}"}
{"type":"translation","prompt":"Translate to Vietnamese: 'A short sentence using ${record.headword}'","answer":"Vietnamese translation here"}
''';
  }
}
```

- [ ] **Step 4.4: Update `reading_passage_source.dart`**

Remove local `GenerativeModelClient` and `_RealModelClient`. Import from factory and re-export. Update constructor.

Replace the entire file:

```dart
// lib/features/reading/data/sources/reading_passage_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

// Re-export so existing test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class ReadingPassageSource {
  ReadingPassageSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  ReadingPassageSource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<ReadingPassage> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    final wordMap = {for (final w in words) w.headword: w.id};
    final prompt = _buildPrompt(
      headwords: wordMap.keys.toList(),
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"sentences":[]}';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parse(json, wordMap, level, context, targetLanguage);
  }

  String _buildPrompt({
    required List<String> headwords,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) {
    final wordList = headwords.join(', ');
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. '
        'Write a short passage of 4 to 6 sentences in ${targetLanguage.label} at ${level.label} level. '
        'Context/register: ${context.label}. '
        'Naturally use as many of these vocabulary words as possible: $wordList. '
        'For each sentence, provide its Vietnamese translation and list which vocabulary words from the input appear in that sentence. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"sentences": [{"target": "sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}]}';
  }

  ReadingPassage _parse(
    Map<String, dynamic> json,
    Map<String, String> wordMap,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final sentences = (json['sentences'] as List? ?? []).map((s) {
      final sm = s as Map<String, dynamic>;
      final vocabWords = List<String>.from(sm['vocabWords'] as List? ?? []);
      final vocabIds =
          vocabWords.map((w) => wordMap[w]).whereType<String>().toList();
      return BilingualSentence(
        target: sm['target'] as String,
        vietnamese: sm['vietnamese'] as String,
        vocabIds: vocabIds,
      );
    }).toList();

    final allVocabIds =
        sentences.expand((s) => s.vocabIds).toSet().toList();

    return ReadingPassage(
      id: _uuid.v4(),
      sentences: sentences,
      vocabIds: allVocabIds,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4.5: Update `app_providers.dart`**

The three source providers must now watch the full `UserSettingsState` and pass it to the new constructors. Find the three provider functions in `lib/core/di/app_providers.dart` and replace them:

```dart
// Replace the geminiDictionarySource provider (around line 55):
@riverpod
GeminiDictionarySource geminiDictionarySource(GeminiDictionarySourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return GeminiDictionarySource(settings);
}

// Replace the exerciseGeneratorSource provider (around line 108):
@riverpod
ExerciseGeneratorSource exerciseGeneratorSource(ExerciseGeneratorSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return ExerciseGeneratorSource(settings);
}

// Replace the readingPassageSource provider (around line 139):
@riverpod
ReadingPassageSource readingPassageSource(ReadingPassageSourceRef ref) {
  final settings = ref.watch(userSettingsNotifierProvider);
  return ReadingPassageSource(settings);
}
```

Also add the missing import at the top of `app_providers.dart` if not present:
```dart
import '../../features/dictionary/domain/entities/user_settings_state.dart';
```

- [ ] **Step 4.6: Run codegen**

```
dart run build_runner build --delete-conflicting-outputs
```

Expected: Exits 0. Regenerates `app_providers.g.dart`.

- [ ] **Step 4.7: Run all source tests**

```
flutter test test/features/dictionary/data/sources/gemini_dictionary_source_test.dart \
             test/features/reading/data/sources/reading_passage_source_test.dart \
             test/features/practice/domain/use_cases/generate_exercise_use_case_test.dart
```

Expected: All tests pass.

- [ ] **Step 4.8: Run full test suite**

```
flutter test
```

Expected: All tests pass.

- [ ] **Step 4.9: Commit**

```
git add lib/features/dictionary/data/sources/gemini_dictionary_source.dart \
        lib/features/practice/data/sources/exercise_generator_source.dart \
        lib/features/reading/data/sources/reading_passage_source.dart \
        lib/core/di/app_providers.dart \
        lib/core/di/app_providers.g.dart
git commit -m "feat: wire AI sources to AiClientFactory, drop hardcoded geminiApiKey"
```

---

### Task 5: Update Settings UI

**Files:**
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`

**Interfaces:**
- Consumes (from Task 2):
  - `settings.activeProvider: AiProvider`
  - `settings.activeConfig: ProviderConfig` (`.apiKey`, `.model`)
  - `notifier.setActiveProvider(AiProvider)`
  - `notifier.setApiKeyForActiveProvider(String)`
  - `notifier.setModelForActiveProvider(String)`
- Consumes (from Task 1): `AiProvider.values`, `AiProvider.label`, `AiProvider.modelPresets`

---

- [ ] **Step 5.1: Update the AI section in `settings_screen.dart`**

Replace the entire file content:

```dart
// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../features/dictionary/domain/entities/ai_provider.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/provider_config.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../providers/auth_notifier.dart';
import '../providers/sync_notifier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final authAsync = ref.watch(authNotifierProvider);
    final syncStatus = ref.watch(syncNotifierProvider);
    final notifier = ref.read(userSettingsNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        children: [
          // ── Tài khoản ─────────────────────────────────────────
          _SectionHeader('Tài khoản'),
          authAsync.when(
            data: (user) => user == null
                ? _SignedOutCard(
                    onSignIn: () async {
                      try {
                        await ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle();
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Đăng nhập thất bại. Thử lại.')),
                          );
                        }
                      }
                    },
                  )
                : _SignedInSection(
                    user: user,
                    syncStatus: syncStatus,
                    onSignOut: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (_, __) =>
                const ListTile(title: Text('Lỗi xác thực')),
          ),

          // ── AI ────────────────────────────────────────────────
          _SectionHeader('AI'),
          SwitchListTile(
            title: const Text('Bật AI'),
            subtitle: const Text('Tạo bài tập và nội dung tự động'),
            value: settings.aiEnabled,
            onChanged: (v) => notifier.setAiEnabled(enabled: v),
          ),
          if (settings.aiEnabled) ...[
            // Provider picker
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Provider',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  SegmentedButton<AiProvider>(
                    segments: AiProvider.values
                        .map((p) => ButtonSegment<AiProvider>(
                              value: p,
                              label: Text(p.label),
                            ))
                        .toList(),
                    selected: {settings.activeProvider},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) notifier.setActiveProvider(s.first);
                    },
                  ),
                ],
              ),
            ),
            // Model picker
            _ModelTile(
              settings: settings,
              onModelChanged: notifier.setModelForActiveProvider,
            ),
            // API Key
            ListTile(
              title: const Text('API Key'),
              subtitle: Text(
                settings.activeConfig.apiKey.isEmpty
                    ? 'Chưa cài đặt'
                    : '••••••••${_lastFour(settings.activeConfig.apiKey)}',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showApiKeyDialog(
                  context, ref, settings.activeConfig.apiKey),
            ),
          ],

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
            onTap: () => _showCefrPicker(
                context, ref, settings.targetCefrLevel),
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

          // ── Thông báo ─────────────────────────────────────────
          _SectionHeader('Thông báo'),
          SwitchListTile(
            title: const Text('Nhắc nhở hàng ngày'),
            subtitle: const Text('Thông báo khi có từ cần ôn'),
            value: settings.reminderEnabled,
            onChanged: (v) => notifier.setReminderEnabled(enabled: v),
          ),
          if (settings.reminderEnabled)
            ListTile(
              title: const Text('Giờ nhắc cố định'),
              trailing: Text(
                '${settings.reminderHour.toString().padLeft(2, '0')}:'
                '${settings.reminderMinute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              onTap: () => _showTimePicker(context, ref, settings),
            ),
        ],
      ),
    );
  }

  String _lastFour(String key) =>
      key.length > 4 ? key.substring(key.length - 4) : key;

  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, String currentKey) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ApiKeyDialog(
        currentKey: currentKey,
        onSave: (key) => ref
            .read(userSettingsNotifierProvider.notifier)
            .setApiKeyForActiveProvider(key),
      ),
    );
  }

  void _showCefrPicker(
      BuildContext context, WidgetRef ref, CEFRLevel? current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<CEFRLevel?>(
              title: const Text('Tất cả'),
              value: null,
              groupValue: current,
              onChanged: (_) {
                ref
                    .read(userSettingsNotifierProvider.notifier)
                    .setTargetCefrLevel(null);
                Navigator.pop(ctx);
              },
            ),
            ...CEFRLevel.values.map((level) => RadioListTile<CEFRLevel?>(
                  title: Text(level.label),
                  value: level,
                  groupValue: current,
                  onChanged: (v) {
                    ref
                        .read(userSettingsNotifierProvider.notifier)
                        .setTargetCefrLevel(v);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePicker(
      BuildContext context, WidgetRef ref, UserSettingsState settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
    );
    if (picked == null) return;
    ref
        .read(userSettingsNotifierProvider.notifier)
        .setReminderTime(picked.hour, picked.minute);
  }
}

// ── Model tile with preset dropdown + free-text "Khác..." option ──────────

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.settings, required this.onModelChanged});
  final UserSettingsState settings;
  final void Function(String) onModelChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = settings.activeProvider.modelPresets;
    final currentModel = settings.activeConfig.model.isEmpty
        ? settings.activeProvider.defaultModel
        : settings.activeConfig.model;
    final isCustom = !presets.contains(currentModel);

    return ListTile(
      title: const Text('Model'),
      subtitle: Text(currentModel),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showModelPicker(context, presets, currentModel, isCustom),
    );
  }

  void _showModelPicker(
    BuildContext context,
    List<String> presets,
    String currentModel,
    bool isCustom,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCustom)
              RadioListTile<String>(
                title: Text(currentModel),
                subtitle: const Text('Tuỳ chỉnh'),
                value: currentModel,
                groupValue: currentModel,
                onChanged: (_) => Navigator.pop(ctx),
              ),
            ...presets.map((model) => RadioListTile<String>(
                  title: Text(model),
                  value: model,
                  groupValue: currentModel,
                  onChanged: (v) {
                    if (v != null) onModelChanged(v);
                    Navigator.pop(ctx);
                  },
                )),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Khác...'),
              onTap: () {
                Navigator.pop(ctx);
                _showCustomModelDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomModelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _CustomModelDialog(
        currentModel: settings.activeConfig.model,
        onSave: onModelChanged,
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Đăng nhập để đồng bộ dữ liệu trên nhiều thiết bị'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Đăng nhập với Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInSection extends StatelessWidget {
  const _SignedInSection({
    required this.user,
    required this.syncStatus,
    required this.onSignOut,
  });
  final User user;
  final SyncStatus syncStatus;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoURL != null
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL == null
                ? Text(
                    (user.displayName?.isNotEmpty ?? false)
                        ? user.displayName![0].toUpperCase()
                        : '?',
                  )
                : null,
          ),
          title: Text(user.displayName ?? 'Người dùng'),
          subtitle: Text(user.email ?? ''),
          trailing: TextButton(
            onPressed: onSignOut,
            child: const Text('Đăng xuất'),
          ),
        ),
        ListTile(
          leading: syncStatus == SyncStatus.syncing
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  syncStatus == SyncStatus.error
                      ? Icons.sync_problem_outlined
                      : Icons.sync_outlined,
                  color: syncStatus == SyncStatus.error ? Colors.red : null,
                ),
          title: const Text('Đồng bộ'),
          subtitle: Text(switch (syncStatus) {
            SyncStatus.idle => 'Đã đồng bộ',
            SyncStatus.syncing => 'Đang đồng bộ...',
            SyncStatus.error => 'Lỗi đồng bộ',
          }),
        ),
      ],
    );
  }
}

class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({required this.currentKey, required this.onSave});
  final String currentKey;
  final void Function(String) onSave;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Key'),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        decoration: const InputDecoration(
          hintText: 'Nhập API key...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            widget.onSave(_ctrl.text.trim());
            Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _CustomModelDialog extends StatefulWidget {
  const _CustomModelDialog({required this.currentModel, required this.onSave});
  final String currentModel;
  final void Function(String) onSave;

  @override
  State<_CustomModelDialog> createState() => _CustomModelDialogState();
}

class _CustomModelDialogState extends State<_CustomModelDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentModel);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tên model'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          hintText: 'vd: gemini-2.5-pro, llama-3.1-8b-instant...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ')),
        FilledButton(
          onPressed: () {
            final model = _ctrl.text.trim();
            if (model.isNotEmpty) widget.onSave(model);
            Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5.2: Run full test suite**

```
flutter test
```

Expected: All tests pass.

- [ ] **Step 5.3: Build to verify no compile errors**

```
flutter build apk --debug 2>&1 | tail -20
```

Or on web:
```
flutter build web 2>&1 | tail -20
```

Expected: Build completes without errors.

- [ ] **Step 5.4: Commit**

```
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "feat: update Settings UI with provider picker, model dropdown, per-provider API key"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] `AiProvider` enum with `gemini`, `groq`, `openRouter` — Task 1
- [x] `ProviderConfig` with `toJson`/`fromJson` — Task 1
- [x] `UserSettingsState` replaces `geminiApiKey` with `activeProvider` + `providerConfigs` + `activeConfig` getter — Task 2
- [x] Persistence via `ai_active_provider` + `ai_config_{provider}` keys — Task 2
- [x] Migration from old `gemini_api_key` — Task 2, with test
- [x] `setActiveProvider`, `setProviderConfig`, `setApiKeyForActiveProvider`, `setModelForActiveProvider` — Task 2
- [x] `AiClientFactory.buildClient` returns correct client per provider — Task 3
- [x] Groq base URL `https://api.groq.com/openai/v1` — Task 3 `_OpenAiClient`
- [x] OpenRouter base URL `https://openrouter.ai/api/v1` — Task 3 `_OpenAiClient`
- [x] `_OpenAiClient` posts to `/chat/completions`, wraps response in `GenerateContentResponse` — Task 3
- [x] `GenerativeModelClient` interface shared via re-export from source files — Task 4
- [x] `.withModel()` / `.withClient()` test constructors preserved — Task 4
- [x] All source tests pass after Task 4 — Step 4.7/4.8
- [x] `app_providers.dart` watches full settings, uses factory constructor — Task 4
- [x] Settings UI: `SegmentedButton` for provider, model bottom sheet with presets + "Khác...", API key dialog — Task 5
- [x] API keys NEVER written to Firestore — no Firestore calls in any of these files
- [x] `aiEnabled` toggle unchanged — Task 5, SwitchListTile preserved
- [x] `defaults` remains `const` — `ProviderConfig` has `const` constructor — Task 1

**Type consistency:**
- `AiClientFactory.buildClient(UserSettingsState) → GenerativeModelClient` — consistent across Tasks 3, 4
- `setProviderConfig(AiProvider, ProviderConfig)` — consistent between Task 2 impl and Task 5 UI usage
- `setApiKeyForActiveProvider(String)` — consistent between Task 2 impl and Task 5 `_ApiKeyDialog.onSave`
- `setModelForActiveProvider(String)` — consistent between Task 2 impl and Task 5 `_ModelTile.onModelChanged`
- Re-export of `GenerativeModelClient` from `gemini_dictionary_source.dart` and `reading_passage_source.dart` — same type as defined in `ai_client_factory.dart`, consistent across Tasks 3, 4
