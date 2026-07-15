// lib/core/services/ai_client_factory.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:http/http.dart' as http;
import '../../features/dictionary/domain/entities/ai_provider.dart';
import '../../features/dictionary/domain/entities/user_settings_state.dart';

/// Shared AI client interface used by all three AI sources.
abstract interface class GenerativeModelClient {
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
}

class AiClientFactory {
  const AiClientFactory._();

  /// Builds the correct [GenerativeModelClient] for [settings.activeProvider].
  ///
  /// [httpClient] is injected for testing; production code omits it.
  static GenerativeModelClient buildClient(
    UserSettingsState settings, {
    http.Client? httpClient,
  }) {
    final config = settings.activeConfig;
    return switch (settings.activeProvider) {
      AiProvider.gemini => _GeminiClient(
          apiKey: config.apiKey,
          model: config.model,
        ),
      AiProvider.groq || AiProvider.openRouter => _OpenAiClient(
          apiKey: config.apiKey,
          model: config.model,
          baseUrl: settings.activeProvider.baseUrl,
          httpClient: httpClient,
        ),
    };
  }
}

final class _GeminiClient implements GenerativeModelClient {
  _GeminiClient({required String apiKey, required String model})
      : _model = GenerativeModel(
          model: model,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
          ),
        );

  final GenerativeModel _model;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) =>
      _model.generateContent(prompt);
}

final class _OpenAiClient implements GenerativeModelClient {
  _OpenAiClient({
    required String apiKey,
    required String model,
    required String baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _model = model,
        _baseUrl = baseUrl,
        _http = httpClient ?? http.Client();

  final String _apiKey;
  final String _model;
  final String _baseUrl;
  final http.Client _http;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    final text = prompt
        .expand((c) => c.parts)
        .whereType<TextPart>()
        .map((p) => p.text)
        .join('\n');

    final response = await _http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': text},
        ],
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'AI API error ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final raw =
        (json['choices'] as List).first['message']['content'] as String;
    // Strip markdown fences defensively — some models ignore json_object mode.
    final content = _stripFences(raw);
    return GenerateContentResponse(
      [Candidate(Content.text(content), null, null, null, null)],
      null,
    );
  }

  /// Strips ` ```json ` or ` ``` ` fences from [s] if present.
  String _stripFences(String s) {
    final trimmed = s.trim();
    final String? start;
    if (trimmed.startsWith('```json')) {
      start = trimmed.substring(7);
    } else if (trimmed.startsWith('```')) {
      start = trimmed.substring(3);
    } else {
      return trimmed;
    }
    final end = start.lastIndexOf('```');
    return end == -1 ? start.trim() : start.substring(0, end).trim();
  }
}
