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
