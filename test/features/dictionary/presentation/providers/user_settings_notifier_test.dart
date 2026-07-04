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

    group('reminder settings', () {
      test('reminderEnabled defaults to false', () async {
        SharedPreferences.setMockInitialValues({});
        final container = await makeContainer();
        addTearDown(container.dispose);
        expect(container.read(userSettingsNotifierProvider).reminderEnabled, false);
      });

      test('setReminderEnabled persists to prefs and updates state', () async {
        SharedPreferences.setMockInitialValues({});
        final container = await makeContainer();
        addTearDown(container.dispose);
        container.read(userSettingsNotifierProvider.notifier).setReminderEnabled(enabled: true);
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getBool('reminder_enabled'), true);
        expect(container.read(userSettingsNotifierProvider).reminderEnabled, true);
      });

      test('reminderHour defaults to 20 and setReminderHour persists', () async {
        SharedPreferences.setMockInitialValues({});
        final container = await makeContainer();
        addTearDown(container.dispose);
        expect(container.read(userSettingsNotifierProvider).reminderHour, 20);
        container.read(userSettingsNotifierProvider.notifier).setReminderHour(8);
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getInt('reminder_hour'), 8);
        expect(container.read(userSettingsNotifierProvider).reminderHour, 8);
      });
    });
  });
}
