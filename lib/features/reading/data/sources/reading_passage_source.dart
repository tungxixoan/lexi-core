// lib/features/reading/data/sources/reading_passage_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/domain/entities/user_settings_state.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/reading_passage.dart';

// Re-export so existing test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

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
    final wordMap = {for (final w in words) w.headword: w.id};
    final prompt = _buildPrompt(
      headwords: wordMap.keys.toList(),
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"sentences":[]}';
    final json = jsonDecode(text) as Map<String, dynamic>;
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
        'Write a short passage of 4 to 6 sentences in ${targetLanguage.label} at ${level.label} level. '
        'Context/register: ${context.label}. '
        'Naturally use as many of these vocabulary words as possible: $wordList. '
        'For each sentence, provide its Vietnamese translation and list which vocabulary words from the input appear in that sentence. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"sentences": [{"target": "sentence in ${targetLanguage.label}", '
        '"vietnamese": "Vietnamese translation", '
        '"vocabWords": ["only words from the provided list that appear in this sentence"]}]}';
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
      final vocabIds =
          vocabWords.map((w) => wordMap[w]).whereType<String>().toList();
      return BilingualSentence(
        target: sm['target'] as String,
        vietnamese: sm['vietnamese'] as String,
        vocabIds: vocabIds,
      );
    }).toList();

    final allVocabIds =
        sentences.expand((s) => s.vocabIds).toSet().toList();

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
