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
  Future<Map<String, dynamic>> call(
      String name, Map<String, dynamic> data) async {
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
    test(
        'remote wins: overwrites local provider config, active provider, and language',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .set({
        'activeProvider': 'groq',
        'providers': {
          'groq': {
            'model': 'remote-model',
            'apiKeyCiphertext': 'remote-cipher'
          },
        },
        'targetLanguage': 'chinese',
      });

      final container = await _makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode(
            {'apiKeyCiphertext': 'local-cipher', 'model': 'local-model'}),
      });
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );
      await service.bootstrapSync(_uid, notifier);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.activeProvider, AiProvider.groq);
      expect(state.providerConfigs[AiProvider.groq]?.apiKeyCiphertext,
          'remote-cipher');
      expect(state.providerConfigs[AiProvider.groq]?.model, 'remote-model');
      expect(state.targetLanguage, Language.chinese);
    });

    test(
        'a remote entry with a null apiKeyCiphertext does not blank an existing local key',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .set({
        'providers': {
          'gemini': {'model': 'gemini-2.5-flash', 'apiKeyCiphertext': null},
        },
      });

      final container = await _makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini': jsonEncode({
          'apiKeyCiphertext': 'local-real-cipher',
          'model': 'gemini-2.5-flash'
        }),
      });
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );
      await service.bootstrapSync(_uid, notifier);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs[AiProvider.gemini]?.apiKeyCiphertext,
          'local-real-cipher');
    });

    test(
        'local plaintext migrates when Firestore has nothing for that provider, and pushes the result',
        () async {
      final firestore =
          FakeFirebaseFirestore(); // no settings doc — first-ever bootstrap
      final caller = _FakeCaller(response: {'ciphertext': 'newly-encrypted'});
      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: caller),
      );

      final container = await _makeContainer(
        initialValues: {
          'ai_active_provider': 'gemini',
          // Pre-migration shape: plaintext under the old 'apiKey' field.
          'ai_config_gemini': jsonEncode(
              {'apiKey': 'plaintext-key', 'model': 'gemini-2.5-pro'}),
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
      expect(state.providerConfigs[AiProvider.gemini]?.apiKeyCiphertext,
          'newly-encrypted');
      expect(state.providerConfigs[AiProvider.gemini]?.model, 'gemini-2.5-pro');

      final doc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .get();
      expect(doc.data()?['providers']?['gemini']?['apiKeyCiphertext'],
          'newly-encrypted');
    });

    test('both empty: no-op, no crash', () async {
      final firestore = FakeFirebaseFirestore();
      final container = await _makeContainer();
      addTearDown(container.dispose);
      final notifier = container.read(userSettingsNotifierProvider.notifier);

      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );
      await expectLater(service.bootstrapSync(_uid, notifier), completes);

      final state = container.read(userSettingsNotifierProvider);
      expect(state.providerConfigs, isEmpty);
    });

    test(
        'an encryptApiKey failure during legacy migration is swallowed — key stays un-migrated, no crash',
        () async {
      final firestore = FakeFirebaseFirestore();
      final container = await _makeContainer(initialValues: {
        'ai_active_provider': 'gemini',
        'ai_config_gemini':
            jsonEncode({'apiKey': 'plaintext-key', 'model': 'gemini-2.5-pro'}),
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
      expect(
          state.providerConfigs[AiProvider.gemini]?.apiKeyCiphertext, isNull);
      expect(
          notifier.legacyPlaintextApiKey(AiProvider.gemini), 'plaintext-key');
    });
  });

  group('AiSettingsSyncService.pushProviderSettings', () {
    test('writes activeProvider/providers/targetLanguage to Firestore',
        () async {
      final firestore = FakeFirebaseFirestore();
      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );

      await service.pushProviderSettings(
        _uid,
        AiProvider.openRouter,
        {
          AiProvider.openRouter: const ProviderConfig(
              apiKeyCiphertext: 'cipher-or', model: 'model-or')
        },
        Language.japanese,
      );

      final doc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .get();
      final data = doc.data()!;
      expect(data['activeProvider'], 'openrouter');
      expect(data['providers']['openrouter'],
          {'model': 'model-or', 'apiKeyCiphertext': 'cipher-or'});
      expect(data['targetLanguage'], 'japanese');
    });

    test(
        'merges into an existing doc without clobbering unrelated fields (e.g. theme/fontSize)',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .set({'theme': 'dark', 'fontSize': 'large'});

      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );
      await service.pushProviderSettings(
        _uid,
        AiProvider.gemini,
        {
          AiProvider.gemini:
              const ProviderConfig(apiKeyCiphertext: 'c', model: 'm')
        },
        Language.english,
      );

      final doc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .get();
      final data = doc.data()!;
      expect(data['theme'], 'dark');
      expect(data['fontSize'], 'large');
      expect(data['activeProvider'], 'gemini');
    });

    test(
        'a local null apiKeyCiphertext does not clobber a real remote ciphertext',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .set({
        'providers': {
          'gemini': {
            'model': 'gemini-2.5-flash',
            'apiKeyCiphertext': 'remote-real-cipher'
          },
        },
      });

      final service = AiSettingsSyncService(
        firestore: firestore,
        encryptor: ApiKeyEncryptor(caller: _FakeCaller(response: {})),
      );
      await service.pushProviderSettings(
        _uid,
        AiProvider.gemini,
        {
          AiProvider.gemini: const ProviderConfig(
              apiKeyCiphertext: null, model: 'gemini-2.5-pro')
        },
        Language.english,
      );

      final doc = await firestore
          .collection('users')
          .doc(_uid)
          .collection('settings')
          .doc('config')
          .get();
      final data = doc.data()!;
      expect(data['providers']['gemini']['apiKeyCiphertext'],
          'remote-real-cipher');
      expect(data['providers']['gemini']['model'], 'gemini-2.5-pro');
    });
  });
}
