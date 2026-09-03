import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';

void main() {
  test('defaults to system theme preference', () {
    expect(UserSettingsState.defaults.themePreference, ThemeMode.system);
  });

  test('copyWith updates themePreference', () {
    final next =
        UserSettingsState.defaults.copyWith(themePreference: ThemeMode.dark);
    expect(next.themePreference, ThemeMode.dark);
  });

  test('copyWith leaves themePreference unchanged when omitted', () {
    final start =
        UserSettingsState.defaults.copyWith(themePreference: ThemeMode.light);
    final next = start.copyWith(reminderEnabled: true);
    expect(next.themePreference, ThemeMode.light);
  });

  test('aiAvailable is false with no key, true once a ciphertext is set', () {
    expect(UserSettingsState.defaults.aiAvailable, isFalse);
    final withKey = UserSettingsState.defaults.copyWith(providerConfigs: {
      AiProvider.gemini: const ProviderConfig(
          apiKeyCiphertext: 'abc', model: 'gemini-2.5-flash'),
    });
    expect(withKey.aiAvailable, isTrue);
  });

  test('aiAvailable is false when the active provider has an empty ciphertext',
      () {
    final withEmpty = UserSettingsState.defaults.copyWith(providerConfigs: {
      AiProvider.gemini:
          const ProviderConfig(apiKeyCiphertext: '', model: 'gemini-2.5-flash'),
    });
    expect(withEmpty.aiAvailable, isFalse);
  });
}
