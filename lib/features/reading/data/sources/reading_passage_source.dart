// lib/features/reading/data/sources/reading_passage_source.dart
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../core/utils/ai_json_parser.dart';
import '../../../../core/utils/normalize_typography.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

// Re-export so existing test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart'
    show GenerativeModelClient;

class ReadingPassageSource {
  ReadingPassageSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  ReadingPassageSource.withModel(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<ReadingPassage> generate({
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
    final text = response.text ?? '{"sentences":[]}';
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
    // Scale length with the word count so a 10- or 20-word selection isn't
    // crammed into a handful of sentences — bounded so a large/"all" selection
    // doesn't produce an unreasonably long typing session.
    final rawSentenceCount = (headwords.length * 0.75).ceil();
    final sentenceCount = rawSentenceCount < 6
        ? 6
        : (rawSentenceCount > 12 ? 12 : rawSentenceCount);
    return 'You are a language learning assistant helping a Vietnamese speaker learn '
        '${targetLanguage.label}. '
        'Write a passage of about $sentenceCount sentences in ${targetLanguage.label} at ${level.label} level. '
        'The sentences must connect into a single coherent narrative or description — '
        'not a list of unrelated example sentences. '
        'Context/register: ${context.label}. '
        'Naturally use as many of these vocabulary words as possible: $wordList. '
        'Use natural ${targetLanguage.label} capitalization for each word based on its position in the sentence — '
        'lowercase mid-sentence unless it is a proper noun; do not copy the capitalization of the word list. '
        'Also naturally include a few other ${level.label}-appropriate ${targetLanguage.label} '
        'vocabulary words beyond this list, to add variety and context. '
        'For each sentence, provide its Vietnamese translation and list which vocabulary words '
        'from the input list appear in that sentence, matched case-insensitively (only words from the input list, not the extra ones). '
        'Every Vietnamese translation must use only Vietnamese script — '
        'never Chinese, Japanese, or other non-Vietnamese characters. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"sentences": [{"target": "sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["words from the provided list that appear in this sentence (matched case-insensitively)"]}]}';
  }

  ReadingPassage _parse(
    Map<String, dynamic> json,
    Map<String, String> wordMap,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final sentences = (json['sentences'] as List? ?? []).map((s) {
      final sm = s as Map<String, dynamic>;
      final vocabWords = List<String>.from(sm['vocabWords'] as List? ?? []);
      final vocabIds = vocabWords
          .map((w) => wordMap[w.toLowerCase()])
          .whereType<String>()
          .toList();
      return BilingualSentence(
        target: normalizeTypography(sm['target'] as String),
        vietnamese: normalizeTypography(sm['vietnamese'] as String),
        vocabIds: vocabIds,
        vocabWords: vocabWords, // web's result screen highlights from this
      );
    }).toList();

    final allVocabIds = sentences.expand((s) => s.vocabIds).toSet().toList();

    return ReadingPassage(
      id: _uuid.v4(),
      sentences: sentences,
      vocabIds: allVocabIds,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
