# Flutter AI Settings Firestore Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter's AI settings (active provider, per-provider model/API key, target language) sync to the same `users/{uid}/settings/config` Firestore document apps/web/ already uses, with the raw API key replaced everywhere by a Cloud-KMS ciphertext, and every AI call routed through the `generateContent` Cloud Function instead of a direct client-side SDK/HTTP call.

**Architecture:** `ProviderConfig.apiKey` (plaintext) becomes `ProviderConfig.apiKeyCiphertext` (nullable, KMS ciphertext); `AiClientFactory` is rewritten to call the `generateContent` Cloud Function through a small injectable `CloudFunctionCaller` seam instead of `google_generative_ai`/raw HTTP; a new `AiSettingsSyncService` does a one-shot Firestore fetch-and-merge on sign-in (remote wins, with a one-time local-plaintext-to-ciphertext migration for keys entered before this update) plus a best-effort push whenever `UserSettingsNotifier` changes a synced field — `UserSettingsNotifier.build()` itself stays fully synchronous throughout.

**Tech Stack:** Flutter/Dart, Riverpod (`riverpod_generator`), `cloud_functions` (new dependency), `cloud_firestore`, `fake_cloud_firestore` (test), `mocktail` (test).

## Global Constraints

- Every Cloud Functions call from Flutter uses region `asia-southeast1` (`FirebaseFunctions.instanceFor(region: 'asia-southeast1')`) — matches every `onCall` function in `functions/src/` and `apps/web/src/lib/firebase.ts`'s `getFunctions(app, "asia-southeast1")` (CLAUDE.md).
- The raw API key is never stored anywhere after this plan ships — not in SharedPreferences, not in Firestore. Only the Cloud-KMS ciphertext produced by the `encryptApiKey` Cloud Function is persisted, matching web's `apiKeyCiphertext` model.
- Firestore document path and field names must match `apps/web/src/lib/settings.ts` exactly: `users/{uid}/settings/config`, top-level fields `activeProvider` (lowercase provider id string), `providers` (map keyed by lowercase provider id, each `{model, apiKeyCiphertext}`), `targetLanguage` (lowercase `Language.name` string). Flutter writes these three top-level fields with `SetOptions(merge: true)` and must never write or clear `theme`/`fontSize` (web-only fields with no Flutter equivalent).
- Provider id mapping: `AiProvider.gemini` → `"gemini"`, `AiProvider.groq` → `"groq"`, `AiProvider.openRouter` → `"openrouter"` (lowercase — NOT `.name`, which produces `"openRouter"`).
- Sync scope is exactly `activeProvider` / `providerConfigs` / `targetLanguage`. `activeContext`, `aiEnabled`, `targetCefrLevel`, and all `reminder*` fields stay local-only and are never read from or written to Firestore by this plan.
- No live Firestore listener for settings — one-shot fetch-and-merge on sign-in (`AiSettingsSyncService.bootstrapSync`) plus fire-and-forget push on local change (`AiSettingsSyncService.pushProviderSettings`). Neither method may throw to its caller; every failure is caught and logged/ignored internally.
- `UserSettingsNotifier.build()` stays synchronous and SharedPreferences-backed, unchanged in shape — Firestore sync is bolted on as a side effect of the existing setters and a separate bootstrap call, never a new async read path.
- `FakeFirebaseFirestore` cannot simulate a write/read failure (see `lib/core/services/hive_migration_service.dart`'s own doc comment on this exact limitation) — do not attempt to force one through it. Where "never throws" needs verifying and no real failure can be simulated through the fake, the plan says so explicitly and relies on the task reviewer reading the try/catch in the diff instead of a runtime test.

---

## Task 1: Rewire AI calls through the Cloud Function; ciphertext-only key storage

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/dictionary/domain/entities/ai_provider.dart`
- Modify: `lib/features/dictionary/domain/entities/provider_config.dart`
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Create: `lib/core/services/cloud_function_caller.dart`
- Modify: `lib/core/services/ai_client_factory.dart`
- Create: `lib/core/services/encrypt_api_key.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Modify: `lib/features/settings/presentation/screens/settings_screen.dart`
- Test: `test/features/dictionary/domain/entities/ai_provider_test.dart` (new)
- Test: `test/features/dictionary/domain/entities/provider_config_test.dart`
- Test: `test/core/services/ai_client_factory_test.dart`
- Test: `test/core/services/encrypt_api_key_test.dart` (new)
- Test: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Produces: `AiProviderX.cloudId` (`String` getter on `AiProvider`), `aiProviderFromCloudId(String) -> AiProvider?` (top-level function in `ai_provider.dart`) — used by Task 2's `AiSettingsSyncService`.
- Produces: `ProviderConfig(apiKeyCiphertext: String?, model: String)` — the new shape every later task and Task 2 build on.
- Produces: `CloudFunctionCaller` (abstract interface, `Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data)`) and `FirebaseCloudFunctionCaller` (real impl) in `lib/core/services/cloud_function_caller.dart` — the shared seam Task 2's `AiSettingsSyncService` also uses.
- Produces: `ApiKeyEncryptor` (`Future<String> encrypt(String rawApiKey)`, throws `EncryptApiKeyException`) in `lib/core/services/encrypt_api_key.dart` — used by both the Settings dialog (this task) and `AiSettingsSyncService`'s legacy migration (Task 2).
- Produces: `UserSettingsNotifier.setApiKeyCiphertextForActiveProvider(String)` (replaces the old `setApiKeyForActiveProvider`), `apiKeyEncryptorProvider` (Riverpod provider).
- Consumes: nothing from other tasks (this is the foundational task).

### Step 1: Add the `cloud_functions` dependency

Run:
```
flutter pub add cloud_functions
```
This lets pub resolve a version compatible with the already-pinned `firebase_core: ^3.0.0` / the resolved `firebase_core: 3.15.2` in `pubspec.lock` — do not hand-pick a version number. Then run:
```
flutter pub get
```
Expected: `pubspec.yaml` gains a `cloud_functions: ^X.Y.Z` line under `dependencies`, `pubspec.lock` updates, both commands exit 0. If pub reports a version conflict, stop and report it — do not downgrade other `firebase_*` packages to force a resolution.

- [ ] **Step 1 done**

### Step 2: Add `AiProvider.cloudId` and `aiProviderFromCloudId`

Replace the full contents of `lib/features/dictionary/domain/entities/ai_provider.dart` with:

```dart
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
        AiProvider.groq => 'openai/gpt-oss-120b',
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
            'openai/gpt-oss-120b',
            'openai/gpt-oss-20b',
          ],
        AiProvider.openRouter => [
            'meta-llama/llama-3.3-70b-instruct',
            'google/gemini-2.5-flash',
            'anthropic/claude-haiku-4-5',
            'mistralai/mixtral-8x7b-instruct',
          ],
      };

  /// The lowercase provider id the `generateContent`/`encryptApiKey` Cloud
  /// Functions and the shared `users/{uid}/settings/config` Firestore
  /// document expect (functions/src/generateContent.ts,
  /// apps/web/src/lib/settings.ts). Deliberately NOT `.name` — that
  /// produces `"openRouter"` (Dart camelCase) for [AiProvider.openRouter],
  /// which does not match the Cloud Function's `"openrouter"`.
  String get cloudId => switch (this) {
        AiProvider.gemini => 'gemini',
        AiProvider.groq => 'groq',
        AiProvider.openRouter => 'openrouter',
      };
}

/// Reverse lookup for [AiProviderX.cloudId] — used when parsing the
/// `activeProvider` field back out of Firestore. Returns null for an
/// unrecognized id (malformed/future remote data) rather than throwing.
AiProvider? aiProviderFromCloudId(String id) {
  for (final provider in AiProvider.values) {
    if (provider.cloudId == id) return provider;
  }
  return null;
}
```

- [ ] **Step 2 done**

### Step 3: Test `cloudId` / `aiProviderFromCloudId`

Create `test/features/dictionary/domain/entities/ai_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';

void main() {
  group('AiProviderX.cloudId', () {
    test('gemini -> "gemini"', () {
      expect(AiProvider.gemini.cloudId, 'gemini');
    });
    test('groq -> "groq"', () {
      expect(AiProvider.groq.cloudId, 'groq');
    });
    test('openRouter -> lowercase "openrouter", not .name', () {
      expect(AiProvider.openRouter.cloudId, 'openrouter');
      expect(AiProvider.openRouter.name, isNot('openrouter'));
    });
  });

  group('aiProviderFromCloudId', () {
    test('round-trips every provider through its cloudId', () {
      for (final provider in AiProvider.values) {
        expect(aiProviderFromCloudId(provider.cloudId), provider);
      }
    });
    test('returns null for an unrecognized id', () {
      expect(aiProviderFromCloudId('not-a-real-provider'), isNull);
    });
  });
}
```

Run: `flutter test test/features/dictionary/domain/entities/ai_provider_test.dart`
Expected: 5/5 pass.

- [ ] **Step 3 done**

### Step 4: Rename `ProviderConfig.apiKey` → `apiKeyCiphertext`

Replace the full contents of `lib/features/dictionary/domain/entities/provider_config.dart`:

```dart
import 'ai_provider.dart';

final class ProviderConfig {
  const ProviderConfig({required this.apiKeyCiphertext, required this.model});

  /// A Cloud KMS ciphertext produced by the `encryptApiKey` Cloud Function
  /// (see lib/core/services/encrypt_api_key.dart) — never a raw API key.
  /// `null` means this provider has no key configured yet.
  final String? apiKeyCiphertext;
  final String model;

  bool get isConfigured =>
      (apiKeyCiphertext?.isNotEmpty ?? false) && model.isNotEmpty;

  Map<String, dynamic> toJson() =>
      {'apiKeyCiphertext': apiKeyCiphertext, 'model': model};

  factory ProviderConfig.fromJson(Map<String, dynamic> json) => ProviderConfig(
        apiKeyCiphertext: json['apiKeyCiphertext'] as String?,
        model: json['model'] as String? ?? '',
      );

  static ProviderConfig empty(AiProvider provider) =>
      ProviderConfig(apiKeyCiphertext: null, model: provider.defaultModel);
}
```

- [ ] **Step 4 done**

### Step 5: Update `ProviderConfig`'s test to the new field

Replace the full contents of `test/features/dictionary/domain/entities/provider_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';

void main() {
  group('ProviderConfig.isConfigured', () {
    test('false when apiKeyCiphertext is null', () {
      const c = ProviderConfig(apiKeyCiphertext: null, model: 'gemini-2.5-flash');
      expect(c.isConfigured, false);
    });
    test('false when apiKeyCiphertext is empty', () {
      const c = ProviderConfig(apiKeyCiphertext: '', model: 'gemini-2.5-flash');
      expect(c.isConfigured, false);
    });
    test('false when model is empty', () {
      const c = ProviderConfig(apiKeyCiphertext: 'cipher', model: '');
      expect(c.isConfigured, false);
    });
    test('true when both are non-empty', () {
      const c = ProviderConfig(apiKeyCiphertext: 'cipher', model: 'gemini-2.5-flash');
      expect(c.isConfigured, true);
    });
  });

  group('ProviderConfig toJson / fromJson round-trip', () {
    test('round-trip preserves apiKeyCiphertext and model', () {
      const original =
          ProviderConfig(apiKeyCiphertext: 'cipher-123', model: 'llama-3.3-70b-versatile');
      final restored = ProviderConfig.fromJson(original.toJson());
      expect(restored.apiKeyCiphertext, original.apiKeyCiphertext);
      expect(restored.model, original.model);
    });
    test('fromJson with missing keys returns null ciphertext and empty model', () {
      final c = ProviderConfig.fromJson({});
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, '');
    });
    test('fromJson ignores a legacy plaintext "apiKey" field', () {
      final c = ProviderConfig.fromJson({'apiKey': 'old-plaintext', 'model': 'gemini-2.5-flash'});
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, 'gemini-2.5-flash');
    });
  });

  group('ProviderConfig.empty', () {
    test('empty Gemini uses gemini-2.5-flash default model, null ciphertext', () {
      final c = ProviderConfig.empty(AiProvider.gemini);
      expect(c.apiKeyCiphertext, isNull);
      expect(c.model, 'gemini-2.5-flash');
    });
    test('empty Groq uses openai/gpt-oss-120b default model', () {
      final c = ProviderConfig.empty(AiProvider.groq);
      expect(c.model, 'openai/gpt-oss-120b');
    });
    test('empty OpenRouter uses meta-llama/llama-3.3-70b-instruct default model', () {
      final c = ProviderConfig.empty(AiProvider.openRouter);
      expect(c.model, 'meta-llama/llama-3.3-70b-instruct');
    });
  });
}
```

Run: `flutter test test/features/dictionary/domain/entities/provider_config_test.dart`
Expected: 10/10 pass.

- [ ] **Step 5 done**

### Step 6: Update `UserSettingsState.defaults`

In `lib/features/dictionary/domain/entities/user_settings_state.dart`, change line 68 from:
```dart
      AiProvider.gemini: ProviderConfig(apiKey: '', model: 'gemini-2.5-flash'),
```
to:
```dart
      AiProvider.gemini: ProviderConfig(apiKeyCiphertext: null, model: 'gemini-2.5-flash'),
```
No other lines in this file change.

- [ ] **Step 6 done**

### Step 7: Create the shared Cloud Functions call seam

Create `lib/core/services/cloud_function_caller.dart`:

```dart
import 'package:cloud_functions/cloud_functions.dart';

/// Thin seam over a Cloud Functions `onCall` invocation, injectable for
/// testing — this codebase's established pattern is to test through an
/// injected interface (e.g. VocabRepository, TtsService) rather than mock
/// the Firebase SDK's own concrete classes directly.
abstract interface class CloudFunctionCaller {
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data);
}

/// Real implementation. Every onCall function in functions/src/ is deployed
/// to asia-southeast1 (see CLAUDE.md) — the client must request the same
/// region, or httpsCallable silently targets the wrong endpoint.
class FirebaseCloudFunctionCaller implements CloudFunctionCaller {
  FirebaseCloudFunctionCaller({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
    final callable = _functions.httpsCallable(name);
    final result = await callable.call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }
}
```

No dedicated test for `FirebaseCloudFunctionCaller` itself — it is a thin pass-through to a platform-channel plugin with nothing to unit-test in isolation (mirrors why `VocabRepositoryImpl` itself has no dedicated unit test; it's exercised through fakes of the `CloudFunctionCaller` interface everywhere it's consumed).

- [ ] **Step 7 done**

### Step 8: Create `ApiKeyEncryptor`

Create `lib/core/services/encrypt_api_key.dart`:

```dart
import 'cloud_function_caller.dart';

/// Thrown when the `encryptApiKey` Cloud Function call fails — carries a
/// user-facing Vietnamese message shown directly in the Settings API-key
/// dialog (mirrors apps/web/src/components/settings/AiProviderSection.tsx's
/// handleUpdateKey error handling).
class EncryptApiKeyException implements Exception {
  const EncryptApiKeyException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Wraps the `encryptApiKey` Cloud Function (functions/src/encryptApiKey.ts)
/// — turns a raw, user-entered API key into a Cloud KMS ciphertext that's
/// safe to store in Firestore/SharedPreferences. The raw key itself is never
/// persisted anywhere, per this project's BYOK policy (see CLAUDE.md).
class ApiKeyEncryptor {
  ApiKeyEncryptor({CloudFunctionCaller? caller})
      : _caller = caller ?? FirebaseCloudFunctionCaller();

  final CloudFunctionCaller _caller;

  static const _genericError = 'Không thể mã hoá API key. Vui lòng thử lại.';

  Future<String> encrypt(String rawApiKey) async {
    try {
      final result = await _caller.call('encryptApiKey', {'apiKey': rawApiKey});
      final ciphertext = result['ciphertext'] as String?;
      if (ciphertext == null || ciphertext.isEmpty) {
        throw const EncryptApiKeyException(_genericError);
      }
      return ciphertext;
    } on EncryptApiKeyException {
      rethrow;
    } catch (_) {
      throw const EncryptApiKeyException(_genericError);
    }
  }
}
```

- [ ] **Step 8 done**

### Step 9: Test `ApiKeyEncryptor`

Create `test/core/services/encrypt_api_key_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/core/services/encrypt_api_key.dart';

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error});
  Map<String, dynamic>? response;
  Object? error;
  String? capturedName;
  Map<String, dynamic>? capturedData;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    capturedName = name;
    capturedData = data;
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  group('ApiKeyEncryptor.encrypt', () {
    test('returns the ciphertext from a successful call', () async {
      final fake = _FakeCaller(response: {'ciphertext': 'cipher-abc'});
      final encryptor = ApiKeyEncryptor(caller: fake);

      final result = await encryptor.encrypt('raw-key-123');

      expect(result, 'cipher-abc');
      expect(fake.capturedName, 'encryptApiKey');
      expect(fake.capturedData, {'apiKey': 'raw-key-123'});
    });

    test('throws EncryptApiKeyException when the response has no ciphertext', () async {
      final fake = _FakeCaller(response: {});
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });

    test('throws EncryptApiKeyException when the response has an empty ciphertext', () async {
      final fake = _FakeCaller(response: {'ciphertext': ''});
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });

    test('wraps an underlying Cloud Function error as EncryptApiKeyException', () async {
      final fake = _FakeCaller(error: Exception('permission-denied'));
      final encryptor = ApiKeyEncryptor(caller: fake);

      await expectLater(
        () => encryptor.encrypt('raw-key'),
        throwsA(isA<EncryptApiKeyException>()),
      );
    });
  });
}
```

Run: `flutter test test/core/services/encrypt_api_key_test.dart`
Expected: 4/4 pass.

- [ ] **Step 9 done**

### Step 10: Rewrite `AiClientFactory` to call `generateContent` via `CloudFunctionCaller`

Replace the full contents of `lib/core/services/ai_client_factory.dart`:

```dart
// lib/core/services/ai_client_factory.dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../features/dictionary/domain/entities/ai_provider.dart';
import '../../features/dictionary/domain/entities/user_settings_state.dart';
import 'cloud_function_caller.dart';

/// Shared AI client interface used by all AI sources.
abstract interface class GenerativeModelClient {
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
}

class AiClientFactory {
  const AiClientFactory._();

  /// Builds a [GenerativeModelClient] that proxies every call through the
  /// `generateContent` Cloud Function (functions/src/generateContent.ts),
  /// exactly like apps/web/ already does — Flutter no longer calls any AI
  /// provider directly, since the stored key is now a KMS ciphertext only
  /// the Cloud Function can decrypt.
  ///
  /// [functionCaller] is injected for testing; production code omits it.
  static GenerativeModelClient buildClient(
    UserSettingsState settings, {
    CloudFunctionCaller? functionCaller,
  }) {
    final config = settings.activeConfig;
    return _CloudFunctionClient(
      provider: settings.activeProvider,
      apiKeyCiphertext: config.apiKeyCiphertext ?? '',
      model: config.model,
      caller: functionCaller ?? FirebaseCloudFunctionCaller(),
    );
  }
}

final class _CloudFunctionClient implements GenerativeModelClient {
  _CloudFunctionClient({
    required this.provider,
    required this.apiKeyCiphertext,
    required this.model,
    required this.caller,
  });

  final AiProvider provider;
  final String apiKeyCiphertext;
  final String model;
  final CloudFunctionCaller caller;

  @override
  Future<GenerateContentResponse> generateContent(
      Iterable<Content> prompt) async {
    final text = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');

    final result = await caller.call('generateContent', {
      'provider': provider.cloudId,
      'apiKeyCiphertext': apiKeyCiphertext,
      'model': model,
      'prompt': text,
    });

    final content = result['text'] as String? ?? '';
    return GenerateContentResponse(
      [Candidate(Content.text(content), null, null, null, null)],
      null,
    );
  }
}
```

This deletes `_GeminiClient` and `_OpenAiClient` entirely — all 9 call sites (`gemini_dictionary_source.dart`, `dictation_source.dart`, `listening_passage_source.dart`, `exercise_generator_source.dart`, `part5_source.dart`, `part6_source.dart`, `part7_source.dart`, `reading_passage_source.dart`, `word_radar_source.dart`) only ever consume `GenerativeModelClient.generateContent(...)`, which is unchanged, so none of them need any edit.

- [ ] **Step 10 done**

### Step 11: Rewrite `ai_client_factory_test.dart` for the Cloud-Function-backed client

Replace the full contents of `test/core/services/ai_client_factory_test.dart`:

```dart
// test/core/services/ai_client_factory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/core/services/ai_client_factory.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';

UserSettingsState _settingsFor(AiProvider provider, String model, {String? ciphertext}) =>
    UserSettingsState.defaults.copyWith(
      activeProvider: provider,
      providerConfigs: {
        provider: ProviderConfig(
            apiKeyCiphertext: ciphertext ?? 'cipher-abc', model: model),
      },
    );

/// Fake CloudFunctionCaller: records the last (name, data) it was called
/// with and returns whatever [response] the test configured, or throws
/// [error] if set.
class _FakeCaller implements CloudFunctionCaller {
  String? capturedName;
  Map<String, dynamic>? capturedData;
  Map<String, dynamic> response = {'text': 'default'};
  Object? error;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    capturedName = name;
    capturedData = data;
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  group('AiClientFactory.buildClient — type checks', () {
    test('returns GenerativeModelClient for Gemini', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.gemini, 'gemini-2.5-flash'),
        functionCaller: _FakeCaller(),
      );
      expect(client, isA<GenerativeModelClient>());
    });

    test('returns GenerativeModelClient for Groq', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.groq, 'openai/gpt-oss-120b'),
        functionCaller: _FakeCaller(),
      );
      expect(client, isA<GenerativeModelClient>());
    });

    test('returns GenerativeModelClient for OpenRouter', () {
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.openRouter, 'meta-llama/llama-3.3-70b-instruct'),
        functionCaller: _FakeCaller(),
      );
      expect(client, isA<GenerativeModelClient>());
    });
  });

  group('_CloudFunctionClient.generateContent — payload shape', () {
    test('sends provider/apiKeyCiphertext/model/prompt to generateContent', () async {
      final fake = _FakeCaller()..response = {'text': '{"word": "hello"}'};
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.groq, 'openai/gpt-oss-120b', ciphertext: 'cipher-xyz'),
        functionCaller: fake,
      );

      await client.generateContent([Content.text('translate this')]);

      expect(fake.capturedName, 'generateContent');
      expect(fake.capturedData, {
        'provider': 'groq',
        'apiKeyCiphertext': 'cipher-xyz',
        'model': 'openai/gpt-oss-120b',
        'prompt': 'translate this',
      });
    });

    test('maps AiProvider.openRouter to the lowercase "openrouter" id', () async {
      final fake = _FakeCaller()..response = {'text': 'ok'};
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.openRouter, 'meta-llama/llama-3.3-70b-instruct'),
        functionCaller: fake,
      );

      await client.generateContent([Content.text('prompt')]);

      expect(fake.capturedData?['provider'], 'openrouter');
    });

    test('wraps the returned text into GenerateContentResponse.text', () async {
      final fake = _FakeCaller()..response = {'text': '{"word": "hello"}'};
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.gemini, 'gemini-2.5-flash'),
        functionCaller: fake,
      );

      final result = await client.generateContent([Content.text('prompt')]);

      expect(result.text, '{"word": "hello"}');
    });

    test('propagates an error thrown by the Cloud Function call', () async {
      final fake = _FakeCaller()..error = Exception('generateContent failed');
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.gemini, 'gemini-2.5-flash'),
        functionCaller: fake,
      );

      await expectLater(
        () => client.generateContent([Content.text('prompt')]),
        throwsA(isA<Exception>()),
      );
    });

    test('flattens multiple Content parts into one newline-joined prompt', () async {
      final fake = _FakeCaller()..response = {'text': 'ok'};
      final client = AiClientFactory.buildClient(
        _settingsFor(AiProvider.gemini, 'gemini-2.5-flash'),
        functionCaller: fake,
      );

      await client.generateContent(
          [Content.text('line one'), Content.text('line two')]);

      expect(fake.capturedData?['prompt'], 'line one\nline two');
    });
  });
}
```

Run: `flutter test test/core/services/ai_client_factory_test.dart`
Expected: 9/9 pass.

- [ ] **Step 11 done**

### Step 12: Update `UserSettingsNotifier` — rename the key setter, add the encryptor provider

In `lib/features/dictionary/presentation/providers/user_settings_provider.dart`:

Add this import alongside the existing ones:
```dart
import '../../../../core/services/encrypt_api_key.dart';
```

Add this provider directly below the existing `sharedPreferences` provider (before the `UserSettingsNotifier` class):
```dart
// Overridden in tests with a fake to avoid a real Cloud Functions call.
@Riverpod(keepAlive: true)
ApiKeyEncryptor apiKeyEncryptor(ApiKeyEncryptorRef ref) => ApiKeyEncryptor();
```

Replace the `setApiKeyForActiveProvider` method:
```dart
  void setApiKeyForActiveProvider(String key) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKey: key, model: current.model),
    );
  }
```
with:
```dart
  void setApiKeyCiphertextForActiveProvider(String ciphertext) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKeyCiphertext: ciphertext, model: current.model),
    );
  }
```

Replace the `setModelForActiveProvider` method:
```dart
  void setModelForActiveProvider(String model) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKey: current.apiKey, model: model),
    );
  }
```
with:
```dart
  void setModelForActiveProvider(String model) {
    final current = state.activeConfig;
    setProviderConfig(
      state.activeProvider,
      ProviderConfig(apiKeyCiphertext: current.apiKeyCiphertext, model: model),
    );
  }
```

No other lines in this file change in this task (the `sync` parameter, `_pushBestEffort`, and `legacyPlaintextApiKey` are added in Task 2 — this task only fixes the field rename).

Regenerate the Riverpod codegen for the new provider:
```
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0, `user_settings_provider.g.dart` gains an `apiKeyEncryptorProvider` (and its generated `ApiKeyEncryptorRef` typedef/class).

- [ ] **Step 12 done**

### Step 13: Rewrite the Settings screen's API-key entry flow

In `lib/features/settings/presentation/screens/settings_screen.dart`:

Add this import alongside the existing ones:
```dart
import '../../../../core/services/encrypt_api_key.dart';
```

Replace the API Key `ListTile` block:
```dart
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
```
with:
```dart
            // API Key
            ListTile(
              title: const Text('API Key'),
              subtitle: Text(
                (settings.activeConfig.apiKeyCiphertext?.isNotEmpty ?? false)
                    ? 'Đã cài đặt'
                    : 'Chưa cài đặt',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showApiKeyDialog(
                context,
                ref,
                settings.activeConfig.apiKeyCiphertext?.isNotEmpty ?? false,
              ),
            ),
```

Delete the `_lastFour` helper method entirely:
```dart
  String _lastFour(String key) =>
      key.length > 4 ? key.substring(key.length - 4) : key;

```

Replace the `_showApiKeyDialog` method:
```dart
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
```
with:
```dart
  void _showApiKeyDialog(
      BuildContext context, WidgetRef ref, bool isConfigured) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ApiKeyDialog(
        isConfigured: isConfigured,
        encryptor: ref.read(apiKeyEncryptorProvider),
        onSave: (ciphertext) => ref
            .read(userSettingsNotifierProvider.notifier)
            .setApiKeyCiphertextForActiveProvider(ciphertext),
      ),
    );
  }
```

Replace the entire `_ApiKeyDialog` + `_ApiKeyDialogState` block:
```dart
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
```
with:
```dart
class _ApiKeyDialog extends StatefulWidget {
  const _ApiKeyDialog({
    required this.isConfigured,
    required this.encryptor,
    required this.onSave,
  });
  final bool isConfigured;
  final ApiKeyEncryptor encryptor;
  final void Function(String ciphertext) onSave;

  @override
  State<_ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<_ApiKeyDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ciphertext = await widget.encryptor.encrypt(raw);
      widget.onSave(ciphertext);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is EncryptApiKeyException
            ? e.message
            : 'Không thể mã hoá API key. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            obscureText: true,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: widget.isConfigured ? '••••••••' : 'Nhập API key...',
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Lưu'),
        ),
      ],
    );
  }
}
```

No other part of this file changes (the `_CustomModelDialog`/`_ModelTile` classes and everything else are untouched).

There is no existing widget-test file for `settings_screen.dart` (confirmed — none exists in `test/`), and this dialog's meaningful logic (encrypt-then-save, error-on-failure) is exactly `ApiKeyEncryptor.encrypt`, already fully covered by Step 9's test. Do not add a new widget test for this dialog in this task — the `_ApiKeyDialog`/`_ApiKeyDialogState` classes are UI wiring only (`setState` calls around the already-tested encryptor), consistent with every other dialog in this same file (`_CustomModelDialog`, the CEFR/model picker sheets) having no dedicated widget test either.

- [ ] **Step 13 done**

### Step 14: Update `user_settings_notifier_test.dart` for the field rename

In `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`, make these changes (all other tests/lines are unchanged):

Change the "returns defaults" test's assertion:
```dart
      expect(state.activeConfig.apiKey, '');
```
to:
```dart
      expect(state.activeConfig.apiKeyCiphertext, isNull);
```

Change the "loads persisted provider and config" test's seed and assertion — replace:
```dart
        'ai_config_groq': jsonEncode({'apiKey': 'gsk_test', 'model': 'llama-3.3-70b-versatile'}),
```
with:
```dart
        'ai_config_groq': jsonEncode({'apiKeyCiphertext': 'cipher_gsk_test', 'model': 'llama-3.3-70b-versatile'}),
```
and replace:
```dart
      expect(state.activeConfig.apiKey, 'gsk_test');
```
with:
```dart
      expect(state.activeConfig.apiKeyCiphertext, 'cipher_gsk_test');
```

Replace the entire "migrates old gemini_api_key to ai_config_gemini on build()" test:
```dart
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
```
with:
```dart
      test('migrates old gemini_api_key to ai_config_gemini, still in the plaintext shape', () async {
        final container = await makeContainer(initialValues: {
          'gemini_api_key': 'old-key-xyz',
        });
        addTearDown(container.dispose);
        final prefs = container.read(sharedPreferencesProvider);
        final state = container.read(userSettingsNotifierProvider);

        expect(state.activeProvider, AiProvider.gemini);
        // This ancient migration predates the apiKeyCiphertext rename — it
        // still writes the OLD plaintext shape (`{"apiKey": ..., ...}`).
        // ProviderConfig.fromJson only reads apiKeyCiphertext now, so this
        // plaintext value is correctly NOT surfaced as a usable ciphertext.
        // (Task 2 adds a follow-up assertion here once
        // UserSettingsNotifier.legacyPlaintextApiKey exists, confirming the
        // plaintext value is still recoverable for that later migration.)
        expect(state.activeConfig.apiKeyCiphertext, isNull);
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
```

This version is fully self-contained and compiles/passes on its own in this task — it does not yet reference `legacyPlaintextApiKey` (Task 2 adds that method and extends this exact test with one more assertion in its own Step 4).

Replace the "setProviderConfig() persists JSON and updates state" test's body — replace:
```dart
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
```
with:
```dart
      const config = ProviderConfig(apiKeyCiphertext: 'cipher-my-key', model: 'llama-3.1-8b-instant');
      container
          .read(userSettingsNotifierProvider.notifier)
          .setProviderConfig(AiProvider.groq, config);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs[AiProvider.groq]?.apiKeyCiphertext, 'cipher-my-key');
      expect(state.providerConfigs[AiProvider.groq]?.model, 'llama-3.1-8b-instant');
      final stored = jsonDecode(prefs.getString('ai_config_groq')!) as Map<String, dynamic>;
      expect(stored['apiKeyCiphertext'], 'cipher-my-key');
      expect(stored['model'], 'llama-3.1-8b-instant');
```

Replace the "setApiKeyForActiveProvider() keeps model, updates key" test:
```dart
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
```
with:
```dart
    test('setApiKeyCiphertextForActiveProvider() keeps model, updates ciphertext', () async {
      final container = await makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKeyCiphertext': 'old-cipher', 'model': 'gemini-2.5-pro'}),
      });
      addTearDown(container.dispose);
      container
          .read(userSettingsNotifierProvider.notifier)
          .setApiKeyCiphertextForActiveProvider('new-cipher');
      final config = container.read(userSettingsNotifierProvider).activeConfig;
      expect(config.apiKeyCiphertext, 'new-cipher');
      expect(config.model, 'gemini-2.5-pro'); // model unchanged
    });
```

Replace the "setModelForActiveProvider() keeps key, updates model" test:
```dart
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
```
with:
```dart
    test('setModelForActiveProvider() keeps ciphertext, updates model', () async {
      final container = await makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKeyCiphertext': 'test-cipher', 'model': 'gemini-2.5-flash'}),
      });
      addTearDown(container.dispose);
      container
          .read(userSettingsNotifierProvider.notifier)
          .setModelForActiveProvider('gemini-2.5-pro');
      final config = container.read(userSettingsNotifierProvider).activeConfig;
      expect(config.model, 'gemini-2.5-pro');
      expect(config.apiKeyCiphertext, 'test-cipher'); // ciphertext unchanged
    });
```

Run: `flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`
Expected: every test in the file passes.

- [ ] **Step 14 done**

### Step 15: Full-repo compile check and commit

Run:
```
flutter analyze
```
Expected: no errors or warnings.

Run:
```
flutter test
```
Expected: the full suite passes.

Commit:
```bash
git add pubspec.yaml pubspec.lock lib/features/dictionary/domain/entities/ai_provider.dart lib/features/dictionary/domain/entities/provider_config.dart lib/features/dictionary/domain/entities/user_settings_state.dart lib/core/services/cloud_function_caller.dart lib/core/services/ai_client_factory.dart lib/core/services/encrypt_api_key.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart lib/features/settings/presentation/screens/settings_screen.dart test/features/dictionary/domain/entities/ai_provider_test.dart test/features/dictionary/domain/entities/provider_config_test.dart test/core/services/ai_client_factory_test.dart test/core/services/encrypt_api_key_test.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
git commit -m "feat: route Flutter AI calls through generateContent Cloud Function, ciphertext-only keys"
```

- [ ] **Step 15 done**

---

## Task 2: Firestore settings sync — bootstrap fetch/migrate + push-on-change

**Files:**
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Create: `lib/core/services/ai_settings_sync_service.dart`
- Modify: `lib/features/settings/presentation/screens/sign_in_screen.dart`
- Test: `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`
- Test: `test/core/services/ai_settings_sync_service_test.dart` (new)

**Interfaces:**
- Consumes: `CloudFunctionCaller`, `ApiKeyEncryptor` (Task 1, `lib/core/services/`), `AiProviderX.cloudId` / `aiProviderFromCloudId` (Task 1, `ai_provider.dart`), `ProviderConfig(apiKeyCiphertext, model)` (Task 1).
- Produces: `AiSettingsSyncService.bootstrapSync(String uid, UserSettingsNotifier notifier)`, `AiSettingsSyncService.pushProviderSettings(String uid, AiProvider, Map<AiProvider, ProviderConfig>, Language)`; `currentUidProvider` and `aiSettingsSyncServiceProvider` (Riverpod, in `user_settings_provider.dart`); `UserSettingsNotifier.legacyPlaintextApiKey(AiProvider) -> String?`; `sync` named bool parameter (default `true`) on `setActiveProvider`, `setProviderConfig`, `setTargetLanguage`.

### Step 1: Add `sync`, `_pushBestEffort`, `legacyPlaintextApiKey`, and the two new providers to `UserSettingsNotifier`

In `lib/features/dictionary/presentation/providers/user_settings_provider.dart`, add these imports:
```dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/ai_settings_sync_service.dart';
```
(`dart:convert` and the rest of the existing imports stay as they are.)

Add these two providers directly below the `apiKeyEncryptor` provider added in Task 1:
```dart
// Overridden in tests with a fixed value to avoid touching real
// FirebaseAuth (which isn't initialized in plain unit tests).
@Riverpod(keepAlive: true)
String? currentUid(CurrentUidRef ref) => FirebaseAuth.instance.currentUser?.uid;

// Overridden in tests with a fake to verify push-on-change without a real
// Firestore/Cloud Functions round-trip.
@Riverpod(keepAlive: true)
AiSettingsSyncService aiSettingsSyncService(AiSettingsSyncServiceRef ref) =>
    AiSettingsSyncService();
```

Add these two members to `UserSettingsNotifier`, directly below the existing `_prefs` getter:
```dart
  AiSettingsSyncService get _syncService =>
      ref.read(aiSettingsSyncServiceProvider);

  /// Best-effort push of the fields AiSettingsSyncService syncs
  /// (activeProvider/providerConfigs/targetLanguage) to Firestore. Never
  /// throws — a failure here must never surface to a caller that just did a
  /// successful local SharedPreferences write.
  void _pushBestEffort() {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    unawaited(
      _syncService
          .pushProviderSettings(uid, state.activeProvider, state.providerConfigs,
              state.targetLanguage)
          .catchError((Object _) {}),
    );
  }

  /// Returns the raw legacy plaintext API key still stored under
  /// [provider]'s SharedPreferences entry, if that entry is still in the
  /// pre-encryption shape (`{"apiKey": "...", "model": "..."}` — no
  /// `apiKeyCiphertext` key) — i.e. a key entered before this update that
  /// hasn't been migrated to a Cloud KMS ciphertext yet. Returns null once
  /// migrated (or if nothing was ever stored for this provider).
  ///
  /// Used only by AiSettingsSyncService.bootstrapSync — ProviderConfig
  /// itself no longer reads the old `apiKey` field at all, so this is the
  /// one remaining place that inspects the raw pre-migration JSON shape.
  String? legacyPlaintextApiKey(AiProvider provider) {
    final raw = _prefs.getString('ai_config_${provider.name}');
    if (raw == null) return null;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json.containsKey('apiKeyCiphertext')) return null;
    final legacy = json['apiKey'] as String?;
    return (legacy != null && legacy.isNotEmpty) ? legacy : null;
  }
```

Change the `setTargetLanguage` method:
```dart
  void setTargetLanguage(Language lang) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
  }
```
to:
```dart
  void setTargetLanguage(Language lang, {bool sync = true}) {
    _prefs.setString('target_language', lang.name);
    state = state.copyWith(targetLanguage: lang);
    if (sync) _pushBestEffort();
  }
```

Change the `setActiveProvider` method:
```dart
  void setActiveProvider(AiProvider provider) {
    _prefs.setString('ai_active_provider', provider.name);
    state = state.copyWith(activeProvider: provider);
  }
```
to:
```dart
  void setActiveProvider(AiProvider provider, {bool sync = true}) {
    _prefs.setString('ai_active_provider', provider.name);
    state = state.copyWith(activeProvider: provider);
    if (sync) _pushBestEffort();
  }
```

Change the `setProviderConfig` method:
```dart
  void setProviderConfig(AiProvider provider, ProviderConfig config) {
    _prefs.setString(
      'ai_config_${provider.name}',
      jsonEncode(config.toJson()),
    );
    final updated = Map<AiProvider, ProviderConfig>.from(state.providerConfigs);
    updated[provider] = config;
    state = state.copyWith(providerConfigs: updated);
  }
```
to:
```dart
  void setProviderConfig(AiProvider provider, ProviderConfig config, {bool sync = true}) {
    _prefs.setString(
      'ai_config_${provider.name}',
      jsonEncode(config.toJson()),
    );
    final updated = Map<AiProvider, ProviderConfig>.from(state.providerConfigs);
    updated[provider] = config;
    state = state.copyWith(providerConfigs: updated);
    if (sync) _pushBestEffort();
  }
```

`setApiKeyCiphertextForActiveProvider` and `setModelForActiveProvider` (from Task 1) call `setProviderConfig(...)` without a `sync:` argument, so they keep the default `sync: true` — no change needed to either. `setActiveContext`, `setAiEnabled`, `setTargetCefrLevel`, and the three reminder setters are NOT synced fields and stay completely unchanged (no `sync` parameter, no push).

Regenerate codegen:
```
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0, `user_settings_provider.g.dart` gains `currentUidProvider` and `aiSettingsSyncServiceProvider`.

- [ ] **Step 1 done**

### Step 2: Create `AiSettingsSyncService`

Create `lib/core/services/ai_settings_sync_service.dart`:

```dart
// lib/core/services/ai_settings_sync_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/dictionary/domain/entities/ai_provider.dart';
import '../../features/dictionary/domain/entities/language.dart';
import '../../features/dictionary/domain/entities/provider_config.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';
import 'encrypt_api_key.dart';

/// Syncs the AI-related subset of UserSettingsState
/// (activeProvider/providerConfigs/targetLanguage) with the same
/// `users/{uid}/settings/config` Firestore document apps/web/ already reads
/// and writes (apps/web/src/lib/settings.ts) — no live listener, just a
/// one-shot fetch-and-merge on bootstrap plus a best-effort push whenever
/// UserSettingsNotifier changes one of these fields locally.
///
/// Deliberately NOT a Riverpod provider's own logic host — it's a plain
/// injectable class (mirrors HiveMigrationService's shape), wired into
/// UserSettingsNotifier via the aiSettingsSyncServiceProvider seam so tests
/// can substitute a fake.
class AiSettingsSyncService {
  AiSettingsSyncService({FirebaseFirestore? firestore, ApiKeyEncryptor? encryptor})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptor = encryptor ?? ApiKeyEncryptor();

  final FirebaseFirestore _firestore;
  final ApiKeyEncryptor _encryptor;

  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('settings')
      .doc('config');

  /// One-shot fetch: pulls `users/{uid}/settings/config` and applies it onto
  /// [notifier] (remote wins for any provider Firestore already has data
  /// for), then migrates any local pre-encryption plaintext key Firestore
  /// had nothing for. Never throws — a failure here must never block app
  /// startup; [notifier]'s local SharedPreferences state stays authoritative
  /// for this session if the fetch (or a migration encryption call) fails.
  Future<void> bootstrapSync(String uid, UserSettingsNotifier notifier) async {
    try {
      final snapshot = await _settingsDoc(uid).get();
      final remote = snapshot.data();
      final remoteProviders = remote?['providers'];

      final legacyToMigrate = <AiProvider, String>{};
      for (final provider in AiProvider.values) {
        final remoteEntry =
            remoteProviders is Map<String, dynamic> ? remoteProviders[provider.cloudId] : null;
        if (remoteEntry is Map<String, dynamic>) {
          notifier.setProviderConfig(
            provider,
            ProviderConfig(
              apiKeyCiphertext: remoteEntry['apiKeyCiphertext'] as String?,
              model: remoteEntry['model'] as String? ?? provider.defaultModel,
            ),
            sync: false,
          );
          continue;
        }
        final legacyKey = notifier.legacyPlaintextApiKey(provider);
        if (legacyKey != null) legacyToMigrate[provider] = legacyKey;
      }

      final remoteActiveId = remote?['activeProvider'];
      if (remoteActiveId is String) {
        final remoteActive = aiProviderFromCloudId(remoteActiveId);
        if (remoteActive != null) {
          notifier.setActiveProvider(remoteActive, sync: false);
        }
      }

      final remoteLanguage = remote?['targetLanguage'];
      if (remoteLanguage is String) {
        for (final lang in Language.values) {
          if (lang.name == remoteLanguage) {
            notifier.setTargetLanguage(lang, sync: false);
            break;
          }
        }
      }

      // Migrate any legacy plaintext key Firestore had nothing for. This
      // deliberately calls setProviderConfig with its default sync: true —
      // that fires the same best-effort push every other local change does,
      // so the newly-encrypted key reaches Firestore without this method
      // needing its own separate call to pushProviderSettings.
      for (final entry in legacyToMigrate.entries) {
        String ciphertext;
        try {
          ciphertext = await _encryptor.encrypt(entry.value);
        } catch (_) {
          // Best-effort — try again on the next bootstrap.
          continue;
        }
        final model =
            notifier.state.providerConfigs[entry.key]?.model ?? entry.key.defaultModel;
        notifier.setProviderConfig(
          entry.key,
          ProviderConfig(apiKeyCiphertext: ciphertext, model: model),
        );
      }
    } catch (_) {
      // Best-effort: any Firestore fetch failure (offline, first launch,
      // permission issue) leaves local state as-is for this session.
    }
  }

  /// Best-effort push of the current synced fields to Firestore. Never
  /// throws — UserSettingsNotifier fires this without awaiting it.
  Future<void> pushProviderSettings(
    String uid,
    AiProvider activeProvider,
    Map<AiProvider, ProviderConfig> providerConfigs,
    Language targetLanguage,
  ) async {
    try {
      await _settingsDoc(uid).set({
        'activeProvider': activeProvider.cloudId,
        'providers': {
          for (final entry in providerConfigs.entries)
            entry.key.cloudId: {
              'model': entry.value.model,
              'apiKeyCiphertext': entry.value.apiKeyCiphertext,
            },
        },
        'targetLanguage': targetLanguage.name,
      }, SetOptions(merge: true));
    } catch (_) {
      // Best-effort — see class doc.
    }
  }
}
```

- [ ] **Step 2 done**

### Step 3: Test `AiSettingsSyncService`

Create `test/core/services/ai_settings_sync_service_test.dart`:

```dart
// test/core/services/ai_settings_sync_service_test.dart
import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/ai_settings_sync_service.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/core/services/encrypt_api_key.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error});
  Map<String, dynamic>? response;
  Object? error;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    if (error != null) throw error!;
    return response!;
  }
}

const _uid = 'test-uid';

Future<ProviderContainer> _makeContainer({
  Map<String, Object> initialValues = const {},
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    currentUidProvider.overrideWithValue(null),
    ...extraOverrides,
  ]);
}

void main() {
  group('AiSettingsSyncService.bootstrapSync', () {
    test('remote wins: overwrites local provider config, active provider, and language', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc(_uid).collection('settings').doc('config').set({
        'activeProvider': 'groq',
        'providers': {
          'groq': {'model': 'remote-model', 'apiKeyCiphertext': 'remote-cipher'},
        },
        'targetLanguage': 'chinese',
      });

      final container = await _makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKeyCiphertext': 'local-cipher', 'model': 'local-model'}),
      });
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final service = AiSettingsSyncService(firestore: firestore);
      await service.bootstrapSync(_uid, notifier);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.activeProvider, AiProvider.groq);
      expect(state.providerConfigs[AiProvider.groq]?.apiKeyCiphertext, 'remote-cipher');
      expect(state.providerConfigs[AiProvider.groq]?.model, 'remote-model');
      expect(state.targetLanguage, Language.chinese);
    });

    test('local plaintext migrates when Firestore has nothing for that provider, and pushes the result', () async {
      final firestore = FakeFirebaseFirestore(); // no settings doc — first-ever bootstrap
      final caller = _FakeCaller(response: {'ciphertext': 'newly-encrypted'});
      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: caller),
      );

      final container = await _makeContainer(
        initialValues: {
          'ai_active_provider': 'gemini',
          // Pre-migration shape: plaintext under the old 'apiKey' field.
          'ai_config_gemini': jsonEncode({'apiKey': 'plaintext-key', 'model': 'gemini-2.5-pro'}),
        },
        extraOverrides: [
          currentUidProvider.overrideWithValue(_uid),
          aiSettingsSyncServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      await service.bootstrapSync(_uid, notifier);
      // Let the fire-and-forget push (triggered by the notifier's own
      // setProviderConfig call inside the migration branch) settle.
      await Future<void>.delayed(Duration.zero);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs[AiProvider.gemini]?.apiKeyCiphertext, 'newly-encrypted');
      expect(state.providerConfigs[AiProvider.gemini]?.model, 'gemini-2.5-pro');

      final doc =
          await firestore.collection('users').doc(_uid).collection('settings').doc('config').get();
      expect(doc.data()?['providers']?['gemini']?['apiKeyCiphertext'], 'newly-encrypted');
    });

    test('both empty: no-op, no crash', () async {
      final firestore = FakeFirebaseFirestore();
      final container = await _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final service = AiSettingsSyncService(firestore: firestore);
      await expectLater(service.bootstrapSync(_uid, notifier), completes);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs, isEmpty);
    });

    test('an encryptApiKey failure during legacy migration is swallowed — key stays un-migrated, no crash', () async {
      final firestore = FakeFirebaseFirestore();
      final container = await _makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({'apiKey': 'plaintext-key', 'model': 'gemini-2.5-pro'}),
      });
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final caller = _FakeCaller(error: Exception('encryptApiKey unavailable'));
      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: caller),
      );

      await expectLater(service.bootstrapSync(_uid, notifier), completes);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs[AiProvider.gemini]?.apiKeyCiphertext, isNull);
      expect(notifier.legacyPlaintextApiKey(AiProvider.gemini), 'plaintext-key');
    });
  });

  group('AiSettingsSyncService.pushProviderSettings', () {
    test('writes activeProvider/providers/targetLanguage to Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AiSettingsSyncService(firestore: firestore);

      await service.pushProviderSettings(
        _uid,
        AiProvider.openRouter,
        {AiProvider.openRouter: const ProviderConfig(apiKeyCiphertext: 'cipher-or', model: 'model-or')},
        Language.japanese,
      );

      final doc =
          await firestore.collection('users').doc(_uid).collection('settings').doc('config').get();
      final data = doc.data()!;
      expect(data['activeProvider'], 'openrouter');
      expect(data['providers']['openrouter'], {'model': 'model-or', 'apiKeyCiphertext': 'cipher-or'});
      expect(data['targetLanguage'], 'japanese');
    });

    test('merges into an existing doc without clobbering unrelated fields (e.g. theme/fontSize)', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .set({'theme': 'dark', 'fontSize': 'large'});

      final service = AiSettingsSyncService(firestore: firestore);
      await service.pushProviderSettings(
        _uid,
        AiProvider.gemini,
        {AiProvider.gemini: const ProviderConfig(apiKeyCiphertext: 'c', model: 'm')},
        Language.english,
      );

      final doc =
          await firestore.collection('users').doc(_uid).collection('settings').doc('config').get();
      final data = doc.data()!;
      expect(data['theme'], 'dark');
      expect(data['fontSize'], 'large');
      expect(data['activeProvider'], 'gemini');
    });
  });
}
```

Note: there is no test here asserting "a Firestore write failure never throws back to the caller" — `FakeFirebaseFirestore` has no way to force a write to fail (see this plan's Global Constraints and `hive_migration_service.dart`'s own doc comment on the same limitation). The `try`/`catch` around the `.set(...)` call in `pushProviderSettings` is verified by the task reviewer reading the diff, not by a runtime test — call this out explicitly in the task report so the reviewer knows it's a deliberate, precedented gap, not an oversight.

Run: `flutter test test/core/services/ai_settings_sync_service_test.dart`
Expected: 6/6 pass.

- [ ] **Step 3 done**

### Step 4: Finish updating `user_settings_notifier_test.dart` — push-on-change and `legacyPlaintextApiKey` tests

In `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`:

Add these imports alongside the existing ones:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lexi_core/core/services/ai_settings_sync_service.dart';
```

Replace the `makeContainer` helper:
```dart
Future<ProviderContainer> makeContainer(
    {Map<String, Object> initialValues = const {}}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}
```
with:
```dart
Future<ProviderContainer> makeContainer({
  Map<String, Object> initialValues = const {},
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    // Default to signed-out so existing tests below never touch real
    // FirebaseAuth (not initialized in plain unit tests). Tests that need
    // to exercise the push-on-change path override this explicitly.
    currentUidProvider.overrideWithValue(null),
    ...extraOverrides,
  ]);
}

class _FakeAiSettingsSyncService extends AiSettingsSyncService {
  // Explicitly pass a FakeFirebaseFirestore — the default constructor's
  // fallback (FirebaseFirestore.instance) throws immediately in a plain
  // unit test with no real Firebase app initialized.
  _FakeAiSettingsSyncService() : super(firestore: FakeFirebaseFirestore());

  int pushCount = 0;
  String? lastUid;
  AiProvider? lastActiveProvider;
  Language? lastTargetLanguage;

  @override
  Future<void> pushProviderSettings(
    String uid,
    AiProvider activeProvider,
    Map<AiProvider, ProviderConfig> providerConfigs,
    Language targetLanguage,
  ) async {
    pushCount++;
    lastUid = uid;
    lastActiveProvider = activeProvider;
    lastTargetLanguage = targetLanguage;
  }
}
```

Extend the "migrates old gemini_api_key..." test written in Task 1 (it currently ends its `expect` calls after `expect(state.activeConfig.model, 'gemini-2.5-flash');`, before the "Old key must be removed" comment) by inserting these lines directly after that `expect` and before the "Old key must be removed" comment:
```dart
        final notifier = container.read(userSettingsNotifierProvider.notifier);
        // It IS still recoverable as a legacy plaintext key — this is what
        // AiSettingsSyncService.bootstrapSync uses to encrypt and migrate it
        // on the next sign-in.
        expect(notifier.legacyPlaintextApiKey(AiProvider.gemini), 'old-key-xyz');
```

Add this new group at the end of the `UserSettingsNotifier` group, right before its closing `});`:
```dart
    group('Firestore push on change', () {
      test('setActiveProvider() pushes when signed in', () async {
        final fake = _FakeAiSettingsSyncService();
        final container = await makeContainer(extraOverrides: [
          currentUidProvider.overrideWithValue('uid-1'),
          aiSettingsSyncServiceProvider.overrideWithValue(fake),
        ]);
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setActiveProvider(AiProvider.groq);
        await Future<void>.delayed(Duration.zero);
        expect(fake.pushCount, 1);
        expect(fake.lastUid, 'uid-1');
        expect(fake.lastActiveProvider, AiProvider.groq);
      });

      test('setActiveProvider() does not push when signed out', () async {
        final fake = _FakeAiSettingsSyncService();
        final container = await makeContainer(extraOverrides: [
          aiSettingsSyncServiceProvider.overrideWithValue(fake),
        ]);
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setActiveProvider(AiProvider.groq);
        await Future<void>.delayed(Duration.zero);
        expect(fake.pushCount, 0);
      });

      test('setProviderConfig(sync: false) does not push (used by bootstrap merge)', () async {
        final fake = _FakeAiSettingsSyncService();
        final container = await makeContainer(extraOverrides: [
          currentUidProvider.overrideWithValue('uid-1'),
          aiSettingsSyncServiceProvider.overrideWithValue(fake),
        ]);
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setProviderConfig(
            AiProvider.gemini,
            const ProviderConfig(apiKeyCiphertext: 'c', model: 'gemini-2.5-flash'),
            sync: false);
        await Future<void>.delayed(Duration.zero);
        expect(fake.pushCount, 0);
      });

      test('setTargetLanguage() pushes when signed in', () async {
        final fake = _FakeAiSettingsSyncService();
        final container = await makeContainer(extraOverrides: [
          currentUidProvider.overrideWithValue('uid-1'),
          aiSettingsSyncServiceProvider.overrideWithValue(fake),
        ]);
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setTargetLanguage(Language.korean);
        await Future<void>.delayed(Duration.zero);
        expect(fake.pushCount, 1);
        expect(fake.lastTargetLanguage, Language.korean);
      });
    });

    group('legacyPlaintextApiKey', () {
      test('returns the raw key from a pre-migration JSON shape', () async {
        final container = await makeContainer(initialValues: {
          'ai_config_gemini': jsonEncode({'apiKey': 'old-plain-key', 'model': 'gemini-2.5-flash'}),
        });
        addTearDown(container.dispose);
        final notifier = container.read(userSettingsNotifierProvider.notifier);
        expect(notifier.legacyPlaintextApiKey(AiProvider.gemini), 'old-plain-key');
      });

      test('returns null once migrated to the ciphertext shape', () async {
        final container = await makeContainer(initialValues: {
          'ai_config_gemini': jsonEncode({'apiKeyCiphertext': 'cipher', 'model': 'gemini-2.5-flash'}),
        });
        addTearDown(container.dispose);
        final notifier = container.read(userSettingsNotifierProvider.notifier);
        expect(notifier.legacyPlaintextApiKey(AiProvider.gemini), isNull);
      });

      test('returns null when nothing is stored for the provider', () async {
        final container = await makeContainer();
        addTearDown(container.dispose);
        final notifier = container.read(userSettingsNotifierProvider.notifier);
        expect(notifier.legacyPlaintextApiKey(AiProvider.groq), isNull);
      });
    });
```

Run: `flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`
Expected: every test in the file passes now, including the "migrates old gemini_api_key..." test left red at the end of Task 1.

- [ ] **Step 4 done**

### Step 5: Wire `bootstrapSync` into the sign-in flow

In `lib/features/settings/presentation/screens/sign_in_screen.dart`, add this import:
```dart
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
```

Replace:
```dart
    if (mounted) setState(() => _step = _Step.migrating);
    try {
      final migration = HiveMigrationService();
      await migration.migrateIfNeeded(user.uid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _migrationError =
              'Không thể chuyển dữ liệu từ vựng cũ lên máy chủ. Vui lòng thử lại.';
        });
      }
      return;
    }

    if (mounted) context.go('/');
```
with:
```dart
    if (mounted) setState(() => _step = _Step.migrating);
    try {
      final migration = HiveMigrationService();
      await migration.migrateIfNeeded(user.uid);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.idle;
          _migrationError =
              'Không thể chuyển dữ liệu từ vựng cũ lên máy chủ. Vui lòng thử lại.';
        });
      }
      return;
    }

    // Best-effort: AiSettingsSyncService.bootstrapSync never throws (see its
    // class doc), so this deliberately has no try/catch and never blocks
    // navigation the way the Hive migration above does.
    await ref.read(aiSettingsSyncServiceProvider).bootstrapSync(
          user.uid,
          ref.read(userSettingsNotifierProvider.notifier),
        );

    if (mounted) context.go('/');
```

- [ ] **Step 5 done**

### Step 6: Full-repo check and commit

Run:
```
flutter analyze
```
Expected: no errors or warnings.

Run:
```
flutter test
```
Expected: the full suite passes, including every test in `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart` and the new `test/core/services/ai_settings_sync_service_test.dart`.

Commit:
```bash
git add lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart lib/core/services/ai_settings_sync_service.dart lib/features/settings/presentation/screens/sign_in_screen.dart test/features/dictionary/presentation/providers/user_settings_notifier_test.dart test/core/services/ai_settings_sync_service_test.dart
git commit -m "feat: sync Flutter AI settings with Firestore (bootstrap fetch/migrate + push on change)"
```

- [ ] **Step 6 done**

---

## After both tasks

Run the full suite once more (`flutter analyze && flutter test`) as a final sanity check, then proceed to the final whole-branch review per the subagent-driven-development skill.
