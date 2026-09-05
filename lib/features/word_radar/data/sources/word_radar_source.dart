import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../../core/utils/input_detector.dart';
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/word_radar_ai_result.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart'
    show GenerativeModelClient;

class WordRadarSource {
  WordRadarSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  WordRadarSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;

  Future<WordRadarAiResult> scan({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
    bool includeTranslation = true,
  }) async {
    final prompt = _buildPrompt(
      text: text,
      targetLanguage: targetLanguage,
      targetCefrLevel: targetCefrLevel,
      knownHeadwords: knownHeadwords,
      includeTranslation: includeTranslation,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final responseText = response.text ?? '{"translation":"","suggestions":[]}';
    final json = parseAiJsonObject(responseText);
    final suggestions = (json['suggestions'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((item) =>
            item['headword'] is String &&
            (item['headword'] as String).isNotEmpty)
        .map((item) => _parseSuggestion(item))
        .toList();
    return WordRadarAiResult(
      translation: json['translation'] as String? ?? '',
      suggestions: suggestions,
    );
  }

  String _buildPrompt({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
    required List<String> knownHeadwords,
    required bool includeTranslation,
  }) {
    final levelClause = targetCefrLevel != null
        ? 'at ${targetCefrLevel.label} level'
        : 'at any level';
    final exclusionClause = knownHeadwords.isEmpty
        ? 'There are no already-known words to exclude.'
        : 'Do NOT suggest any of these already-known words: ${knownHeadwords.join(", ")}.';
    final task = includeTranslation
        ? 'do two things. First, translate the full text into Vietnamese. Second, suggest'
        : 'suggest';
    final translationField = includeTranslation
        ? '"translation":"Vietnamese translation of the full text",'
        : '';
    final translationReminder = includeTranslation
        ? ' If nothing in the text is worth learning, use an empty "suggestions" array — '
            'still always provide the "translation".'
        : ' If nothing in the text is worth learning, use an empty "suggestions" array.';
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. Given this text: "$text", $task '
        'up to 10 words or short phrases from the text that are worth '
        'learning $levelClause, for a Vietnamese speaker. $exclusionClause '
        'Any Vietnamese text in your response must use only Vietnamese script — '
        'never Chinese, Japanese, or other non-Vietnamese characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{$translationField'
        '"suggestions":[{"headword":"exact word or phrase from the text",'
        '"ipa":"IPA transcription","meaning":"Vietnamese definition",'
        '"definition":"English definition",'
        '"synonyms":["2-4 English synonyms, or empty array if none fit"],'
        '"examples":["one example sentence, ideally reusing context from the source text"],'
        '"suggestedTopics":["one topic from: Daily Life, Travel, Food & Drink, Business, '
        'Technology, Health, Education, Entertainment, Nature, Emotion, Academic, Idioms, '
        'Phrasal Verbs, Slang, Social/Casual, Sports, Art & Culture, Science, Law & Politics, Other"],'
        '"cefrLevel":"a1, a2, b1, b2, c1, or c2"}]}.$translationReminder';
  }

  WordPhraseResult _parseSuggestion(Map<String, dynamic> json) {
    final headword = json['headword'] as String;
    final detectedType = InputDetector.detect(headword);
    return WordPhraseResult(
      headword: headword,
      inputType:
          detectedType == InputType.word ? InputType.word : InputType.phrase,
      ipa: json['ipa'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      examples: _stringList(json['examples']),
      suggestedTopics: _stringList(json['suggestedTopics']),
      definition: json['definition'] as String? ?? '',
      synonyms: _stringList(json['synonyms']),
      cefrLevel: CEFRLevel.values
          .asNameMap()[(json['cefrLevel'] as String?)?.trim().toLowerCase()],
    );
  }

  /// The AI is asked for a JSON array but sometimes returns a bare string
  /// instead (e.g. `"suggestedTopics": "Business"`) — treat that as a
  /// single-item list rather than crashing the whole suggestion.
  List<String> _stringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }
}
