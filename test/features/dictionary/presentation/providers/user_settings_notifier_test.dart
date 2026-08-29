// test/features/dictionary/presentation/providers/user_settings_notifier_test.dart
import 'dart:convert';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/services/ai_settings_sync_service.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/core/services/encrypt_api_key.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error}); // ignore: unused_element_parameter
  Map<String, dynamic>? response;
  Object? error;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    if (error != null) throw error!;
    return response!;
  }
}

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
  // Explicitly pass a FakeFirebaseFirestore and a fake encryptor — the
  // default constructor's fallback (FirebaseFirestore.instance) throws
  // immediately in a plain unit test with no real Firebase app initialized.
  _FakeAiSettingsSyncService()
      : super(
          firestore: FakeFirebaseFirestore(),
          encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
        );

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
      expect(state.activeConfig.apiKeyCiphertext, isNull);
      expect(state.activeConfig.model, 'gemini-2.5-flash');
      expect(state.targetCefrLevel, isNull);
    });

    test('build() loads persisted provider and config from SharedPreferences', () async {
      final container = await makeContainer(initialValues: {
        'target_language': 'chinese',
        'active_context': 'business',
        'ai_enabled': true,
        'ai_active_provider': 'groq',
        'ai_config_groq': jsonEncode({'apiKeyCiphertext': 'cipher_gsk_test', 'model': 'llama-3.3-70b-versatile'}),
        'target_cefr_level': 'b2',
      });
      addTearDown(container.dispose);
      final state = container.read(userSettingsNotifierProvider);
      expect(state.targetLanguage, Language.chinese);
      expect(state.activeContext, AppContext.business);
      expect(state.aiEnabled, true);
      expect(state.activeProvider, AiProvider.groq);
      expect(state.activeConfig.apiKeyCiphertext, 'cipher_gsk_test');
      expect(state.activeConfig.model, 'llama-3.3-70b-versatile');
      expect(state.targetCefrLevel, CEFRLevel.b2);
    });

    group('migration from old gemini_api_key', () {
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

        final notifier = container.read(userSettingsNotifierProvider.notifier);
        // It IS still recoverable as a legacy plaintext key — this is what
        // AiSettingsSyncService.bootstrapSync uses to encrypt and migrate it
        // on the next sign-in.
        expect(notifier.legacyPlaintextApiKey(AiProvider.gemini), 'old-key-xyz');

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
    });

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
  });
}
