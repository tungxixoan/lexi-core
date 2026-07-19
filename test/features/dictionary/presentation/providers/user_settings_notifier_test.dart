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
  });
}
