// test/core/services/ai_client_factory_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:http/http.dart' as http;
import 'package:lexi_core/core/services/ai_client_factory.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserSettingsState _settingsFor(AiProvider provider, String model) =>
    UserSettingsState.defaults.copyWith(
      activeProvider: provider,
      providerConfigs: {
        provider: ProviderConfig(apiKey: 'test-key', model: model),
      },
    );

/// Minimal fake HTTP client: intercepts every request and returns the
/// response produced by [handler].
class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);
  final Future<http.Response> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

/// Builds a 200 response whose `choices[0].message.content` equals [content].
http.Response _okResponse(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
          }
        ],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AiClientFactory.buildClient — type checks', () {
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
        _settingsFor(
            AiProvider.openRouter, 'meta-llama/llama-3.3-70b-instruct'),
      );
      expect(client, isA<GenerativeModelClient>());
    });
  });

  group('_OpenAiClient.generateContent — behavioral', () {
    final groqSettings =
        _settingsFor(AiProvider.groq, 'llama-3.3-70b-versatile');

    test('normal 200 response: returns GenerateContentResponse with correct text',
        () async {
      const payload = '{"word": "hello"}';
      final fake = _FakeHttpClient((_) async => _okResponse(payload));

      final client = AiClientFactory.buildClient(
        groqSettings,
        httpClient: fake,
      );
      final result = await client.generateContent([Content.text('prompt')]);

      expect(result.text, equals(payload));
    });

    test('401 error response: throws Exception', () async {
      final fake = _FakeHttpClient(
        (_) async => http.Response('{"error": "Unauthorized"}', 401),
      );

      final client = AiClientFactory.buildClient(
        groqSettings,
        httpClient: fake,
      );

      await expectLater(
        () => client.generateContent([Content.text('prompt')]),
        throwsA(isA<Exception>()),
      );
    });

    test('fenced response (```json...```): strips fences before returning',
        () async {
      const inner = '{"word": "hello"}';
      const fenced = '```json\n$inner\n```';
      final fake = _FakeHttpClient((_) async => _okResponse(fenced));

      final client = AiClientFactory.buildClient(
        groqSettings,
        httpClient: fake,
      );
      final result = await client.generateContent([Content.text('prompt')]);

      expect(result.text, equals(inner));
    });

    test('request body includes response_format json_object', () async {
      Map<String, dynamic>? capturedBody;
      final fake = _FakeHttpClient((request) async {
        capturedBody =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        return _okResponse('{"word": "ok"}');
      });

      final client = AiClientFactory.buildClient(
        groqSettings,
        httpClient: fake,
      );
      await client.generateContent([Content.text('test')]);

      expect(
        capturedBody?['response_format'],
        equals({'type': 'json_object'}),
      );
    });
  });
}
