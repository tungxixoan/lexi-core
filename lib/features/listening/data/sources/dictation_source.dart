import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/dictation_item.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class DictationSource {
  DictationSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  DictationSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<DictationItem> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    final wordMap = {for (final w in words) w.headword.toLowerCase(): w.id};
    final prompt = _buildPrompt(
      headwords: words.map((w) => w.headword).toList(),
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"target":"","vietnamese":"","vocabWords":[]}';
    final json = parseAiJsonObject(text);
    return _parse(json, wordMap, level, context, targetLanguage);
  }

  String _buildPrompt({
    required List<String> headwords,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) {
    final wordList = headwords.join(', ');
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. '
        'Write exactly one natural sentence of medium length (10 to 18 words) in '
        '${targetLanguage.label} at ${level.label} level. '
        'Context/register: ${context.label}. '
        'Naturally use these vocabulary words in the sentence: $wordList. '
        'Provide the sentence\'s Vietnamese translation and list which vocabulary '
        'words from the input actually appear in it. '
        'The Vietnamese translation must use only Vietnamese script — '
        'never Chinese, Japanese, or other non-Vietnamese characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"target": "the sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}';
  }

  DictationItem _parse(
    Map<String, dynamic> json,
    Map<String, String> wordMap,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final vocabWords = List<String>.from(json['vocabWords'] as List? ?? []);
    final vocabIds = vocabWords
        .map((w) => wordMap[w.toLowerCase()])
        .whereType<String>()
        .toList();

    return DictationItem(
      id: _uuid.v4(),
      target: json['target'] as String? ?? '',
      vietnamese: json['vietnamese'] as String? ?? '',
      vocabIds: vocabIds,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
