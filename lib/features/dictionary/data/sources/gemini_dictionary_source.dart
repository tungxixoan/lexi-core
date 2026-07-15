// lib/features/dictionary/data/sources/gemini_dictionary_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/entities/user_settings_state.dart';

// Re-export so existing test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class GeminiDictionarySource {
  GeminiDictionarySource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  /// Constructor for testing — inject any [GenerativeModelClient] fake.
  GeminiDictionarySource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  Future<LookupResult> lookup({
    required String query,
    required InputType inputType,
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt = inputType == InputType.sentence
        ? _sentencePrompt(query)
        : _wordPhrasePrompt(query, inputType, targetLanguage, context);

    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;

    if (inputType == InputType.sentence) {
      return SentenceResult(
        original: query,
        translation: json['translation'] as String,
      );
    }

    return WordPhraseResult(
      headword: json['headword'] as String,
      inputType: inputType,
      ipa: json['ipa'] as String,
      meaning: json['meaning'] as String,
      examples: (json['examples'] as List).cast<String>(),
      suggestedTopics: (json['suggestedTopics'] as List).cast<String>(),
    );
  }

  Future<String> discoverWord({
    required Language targetLanguage,
    required AppContext context,
  }) async {
    final prompt =
        'Suggest one ${targetLanguage.label} vocabulary word for an intermediate learner. '
        'Context: ${context.label}. '
        'Respond with JSON only: {"word": "the word"}';
    final response = await _client.generateContent([Content.text(prompt)]);
    final json = jsonDecode(response.text ?? '{}') as Map<String, dynamic>;
    return json['word'] as String;
  }

  String _wordPhrasePrompt(
    String query,
    InputType inputType,
    Language targetLanguage,
    AppContext context,
  ) =>
      'You are a language learning assistant helping a Vietnamese speaker learn ${targetLanguage.label}. '
      'Look up "$query" and respond with JSON only (no markdown, no code fences): '
      '{"headword":"exact word or phrase","ipa":"IPA transcription",'
      '"meaning":"Vietnamese definition",'
      '"examples":["example 1 in ${targetLanguage.label}","example 2"],'
      '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"]} '
      'Shape examples for context: ${context.label}.';

  String _sentencePrompt(String sentence) =>
      'Translate this sentence to Vietnamese: "$sentence" '
      'Respond with JSON only: {"translation":"translated sentence"}';
}
