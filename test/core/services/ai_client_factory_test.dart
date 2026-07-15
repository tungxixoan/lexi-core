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
