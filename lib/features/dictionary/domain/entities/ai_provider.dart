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
        AiProvider.groq => 'llama-3.3-70b-versatile',
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
            'llama-3.3-70b-versatile',
            'llama-3.1-8b-instant',
            'gemma2-9b-it',
          ],
        AiProvider.openRouter => [
            'meta-llama/llama-3.3-70b-instruct',
            'google/gemini-2.5-flash',
            'anthropic/claude-haiku-4-5',
            'mistralai/mixtral-8x7b-instruct',
          ],
      };
}
