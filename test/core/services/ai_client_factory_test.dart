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
