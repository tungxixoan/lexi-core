enum AiProvider { gemini, groq, openRouter }

extension AiProviderX on AiProvider {
  String get label => switch (this) {
        AiProvider.gemini => 'Gemini',
        AiProvider.groq => 'Groq',
        AiProvider.openRouter => 'OpenRouter',
      };

  String get baseUrl => switch (this) {
        AiProvider.gemini => '',
        AiProvider.groq => 'https://api.groq.com/openai/v1',
        AiProvider.openRouter => 'https://openrouter.ai/api/v1',
      };

  String get defaultModel => switch (this) {
        AiProvider.gemini => 'gemini-2.5-flash',
        AiProvider.groq => 'openai/gpt-oss-120b',
        AiProvider.openRouter => 'meta-llama/llama-3.3-70b-instruct',
      };

  List<String> get modelPresets => switch (this) {
        AiProvider.gemini => [
            'gemini-2.5-flash',
            'gemini-2.5-pro',
            'gemini-2.0-flash',
            'gemini-1.5-flash',
          ],
        AiProvider.groq => [
            'openai/gpt-oss-120b',
            'openai/gpt-oss-20b',
          ],
        AiProvider.openRouter => [
            'meta-llama/llama-3.3-70b-instruct',
            'google/gemini-2.5-flash',
            'anthropic/claude-haiku-4-5',
            'mistralai/mixtral-8x7b-instruct',
          ],
      };

  /// The lowercase provider id the `generateContent`/`encryptApiKey` Cloud
  /// Functions and the shared `users/{uid}/settings/config` Firestore
  /// document expect (functions/src/generateContent.ts,
  /// apps/web/src/lib/settings.ts). Deliberately NOT `.name` — that
  /// produces `"openRouter"` (Dart camelCase) for [AiProvider.openRouter],
  /// which does not match the Cloud Function's `"openrouter"`.
  String get cloudId => switch (this) {
        AiProvider.gemini => 'gemini',
        AiProvider.groq => 'groq',
        AiProvider.openRouter => 'openrouter',
      };
}

/// Reverse lookup for [AiProviderX.cloudId] — used when parsing the
/// `activeProvider` field back out of Firestore. Returns null for an
/// unrecognized id (malformed/future remote data) rather than throwing.
AiProvider? aiProviderFromCloudId(String id) {
  for (final provider in AiProvider.values) {
    if (provider.cloudId == id) return provider;
  }
  return null;
}
