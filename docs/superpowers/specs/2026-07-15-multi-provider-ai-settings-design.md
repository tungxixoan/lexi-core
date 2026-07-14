# Multi-Provider AI Settings Design

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update AI settings to support multiple LLM providers (Gemini, Groq, OpenRouter), with per-provider API key and model selection, remembering each provider's config independently when switching.

**Architecture:** New `AiProvider` enum + `ProviderConfig` value object replace the hardcoded `geminiApiKey` field. A single `AiClientFactory` translates the active config into the correct SDK/HTTP client for each source. All config stays in SharedPreferences — never Firestore.

**Tech Stack:** Flutter/Dart, Riverpod, SharedPreferences, `google_generative_ai` SDK (Gemini), `http` package (Groq/OpenRouter OpenAI-compatible endpoints).

## Global Constraints

- `geminiApiKey` and all API keys must NEVER be written to Firestore — SharedPreferences only.
- Existing `GenerativeModelClient` abstract interface in `reading_passage_source.dart` must be preserved and extended, not replaced.
- `aiEnabled` toggle behavior unchanged — when false, all AI features are disabled regardless of provider.
- Migration from old `gemini_api_key` SharedPreferences key must be automatic and silent on first launch.
- No breaking changes to `UserSettingsState.defaults` — new fields have sensible defaults.

---

## Supported Providers

| Provider | Protocol | Base URL | Notes |
|----------|----------|----------|-------|
| Gemini | `google_generative_ai` SDK | N/A (SDK handles) | Current provider |
| Groq | OpenAI-compatible REST | `https://api.groq.com/openai/v1` | Free tier |
| OpenRouter | OpenAI-compatible REST | `https://openrouter.ai/api/v1` | Aggregates many models |

## Model Presets (per provider)

**Gemini:** `gemini-2.5-flash` (default ⭐), `gemini-2.5-pro`, `gemini-2.0-flash`, `gemini-1.5-flash`

**Groq:** `llama-3.3-70b-versatile` (default ⭐), `llama-3.1-8b-instant`, `mixtral-8x7b-32768`, `gemma2-9b-it`

**OpenRouter:** `meta-llama/llama-3.3-70b-instruct` (default ⭐), `google/gemini-2.5-flash`, `anthropic/claude-haiku-4-5`, `mistralai/mixtral-8x7b-instruct`

All dropdowns include a free-text "Khác" option so users can type any model name.

---

## Data Model

### New files

**`lib/features/dictionary/domain/entities/ai_provider.dart`**

```dart
enum AiProvider { gemini, groq, openRouter }

extension AiProviderX on AiProvider {
  String get label => switch (this) {
    AiProvider.gemini => 'Gemini',
    AiProvider.groq => 'Groq',
    AiProvider.openRouter => 'OpenRouter',
  };

  String get baseUrl => switch (this) {
    AiProvider.gemini => '',  // uses SDK, no base URL
    AiProvider.groq => 'https://api.groq.com/openai/v1',
    AiProvider.openRouter => 'https://openrouter.ai/api/v1',
  };

  String get defaultModel => switch (this) {
    AiProvider.gemini => 'gemini-2.5-flash',
    AiProvider.groq => 'llama-3.3-70b-versatile',
    AiProvider.openRouter => 'meta-llama/llama-3.3-70b-instruct',
  };

  List<String> get modelPresets => switch (this) {
    AiProvider.gemini => ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-1.5-flash'],
    AiProvider.groq => ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant', 'mixtral-8x7b-32768', 'gemma2-9b-it'],
    AiProvider.openRouter => ['meta-llama/llama-3.3-70b-instruct', 'google/gemini-2.5-flash', 'anthropic/claude-haiku-4-5', 'mistralai/mixtral-8x7b-instruct'],
  };
}
```

**`lib/features/dictionary/domain/entities/provider_config.dart`**

```dart
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

### Modified file

**`lib/features/dictionary/domain/entities/user_settings_state.dart`**

Remove `geminiApiKey: String`. Add:

```dart
final AiProvider activeProvider;
final Map<AiProvider, ProviderConfig> providerConfigs;

// Computed getter — AI sources use this exclusively
ProviderConfig get activeConfig =>
    providerConfigs[activeProvider] ?? ProviderConfig.empty(activeProvider);

// Convenience — replaces settings.geminiApiKey reads
bool get aiEnabled => aiEnabled; // unchanged
```

`UserSettingsState.defaults`:
```dart
activeProvider: AiProvider.gemini,
providerConfigs: {
  AiProvider.gemini: ProviderConfig(apiKey: '', model: 'gemini-2.5-flash'),
},
```

`copyWith` additions: `activeProvider`, `providerConfigs`.

---

## Persistence (SharedPreferences)

| Key | Value | Notes |
|-----|-------|-------|
| `ai_active_provider` | `"gemini"` \| `"groq"` \| `"openRouter"` | Active provider name |
| `ai_config_gemini` | JSON string `{"apiKey":"...","model":"..."}` | Gemini config |
| `ai_config_groq` | JSON string | Groq config |
| `ai_config_openRouter` | JSON string | OpenRouter config |

**Migration (one-time, automatic):**

On `UserSettingsNotifier.build()`, if `ai_active_provider` is absent but `gemini_api_key` exists:
1. Read old key value
2. Write `ai_config_gemini = {"apiKey": <old_value>, "model": "gemini-2.5-flash"}`
3. Write `ai_active_provider = "gemini"`
4. Delete `gemini_api_key`

**`UserSettingsNotifier` new methods:**

```dart
void setActiveProvider(AiProvider provider);
void setProviderConfig(AiProvider provider, ProviderConfig config);
// Convenience:
void setModelForActiveProvider(String model);
void setApiKeyForActiveProvider(String key);
```

---

## AI Client Abstraction

### New file: `lib/core/services/ai_client_factory.dart`

```dart
// Returns the correct GenerativeModelClient for the active provider.
// Gemini → _GeminiClient (wraps google_generative_ai GenerativeModel)
// Groq / OpenRouter → _OpenAiClient (HTTP POST to base URL)
GenerativeModelClient buildClient(UserSettingsState settings);
```

`_OpenAiClient` implements `GenerativeModelClient`:
- `generateContent(prompt)` → `POST {baseUrl}/chat/completions` with `Authorization: Bearer {apiKey}`, body `{"model": model, "messages": [...]}`
- Returns a `GenerateContentResponse`-compatible wrapper

### Modified AI sources

`GeminiDictionarySource`, `ExerciseGeneratorSource`, `ReadingPassageSource` — replace:
```dart
// Before:
GenerativeModel(model: 'gemini-2.5-flash', apiKey: settings.geminiApiKey)

// After:
AiClientFactory.buildClient(settings)
```

No logic changes inside sources — only the client construction changes.

---

## Settings UI

**`lib/features/settings/presentation/screens/settings_screen.dart`** — AI section (visible only when `aiEnabled`):

```
┌─ AI ─────────────────────────────────────────────────────┐
│  [toggle] Bật AI                                          │
│                                                           │
│  Provider:  [ Gemini | Groq | OpenRouter ]  ← SegmentedButton │
│                                                           │
│  Model:     [gemini-2.5-flash ▼]  (dropdown + free text) │
│                                                           │
│  API Key:   ••••••••1234          [edit]                  │
└───────────────────────────────────────────────────────────┘
```

Switching provider:
- `setActiveProvider(provider)` called immediately
- UI reflects the saved `ProviderConfig` for that provider (model + masked key)
- No confirmation dialog needed

Model dropdown:
- Shows `provider.modelPresets` as options
- Last option: "Khác..." → opens a text field dialog to enter any model name
- Selected model displayed in the tile subtitle

API Key edit:
- Same dialog pattern as current Gemini key dialog
- Calls `setApiKeyForActiveProvider(key)`

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/dictionary/domain/entities/ai_provider.dart` | Create |
| `lib/features/dictionary/domain/entities/provider_config.dart` | Create |
| `lib/features/dictionary/domain/entities/user_settings_state.dart` | Modify — replace `geminiApiKey` |
| `lib/features/dictionary/presentation/providers/user_settings_provider.dart` | Modify — migration + new methods |
| `lib/core/services/ai_client_factory.dart` | Create |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Modify — AI section UI |
| `lib/features/dictionary/data/sources/gemini_dictionary_source.dart` | Modify — use factory |
| `lib/features/practice/data/sources/exercise_generator_source.dart` | Modify — use factory |
| `lib/features/reading/data/sources/reading_passage_source.dart` | Modify — use factory |

---

## Security Constraints (preserved from existing design)

- `ai_config_*` keys are read in `UserSettingsNotifier` and **never passed to** `SyncService.startSync()`
- `SyncService` only syncs: `targetLanguage`, `activeContext`, `aiEnabled`, `targetCefrLevel`
- `activeProvider` and `providerConfigs` are both local-only (SharedPreferences) — nothing in the AI config block is synced to Firestore
