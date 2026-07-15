// lib/features/practice/data/sources/exercise_generator_source.dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import '../../../../core/services/ai_client_factory.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';

class ExerciseGeneratorSource {
  ExerciseGeneratorSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  /// For testing — inject any [GenerativeModelClient].
  ExerciseGeneratorSource.withClient(GenerativeModelClient client)
      : _client = client;

  final GenerativeModelClient _client;

  Future<Exercise> generate(VocabRecord record) async {
    final prompt = _buildPrompt(record);
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parseExercise(json, record);
  }

  Exercise _parseExercise(Map<String, dynamic> json, VocabRecord record) {
    final type = json['type'] as String? ?? '';
    return switch (type) {
      'multiple_choice' => MultipleChoiceExercise(
          vocabRecord: record,
          question: json['question'] as String,
          options: (json['options'] as List).cast<String>(),
          correctIndex: json['correctIndex'] as int,
        ),
      'fill_in_blank' => FillInBlankExercise(
          vocabRecord: record,
          sentence: json['sentence'] as String,
          answer: (json['answer'] as String).toLowerCase().trim(),
        ),
      'translation' => TranslationExercise(
          vocabRecord: record,
          prompt: json['prompt'] as String,
          answer: json['answer'] as String,
        ),
      _ => FlashcardExercise(vocabRecord: record),
    };
  }

  String _buildPrompt(VocabRecord record) {
    final examples = record.examples.take(2).join('; ');
    return '''
Generate a vocabulary exercise for a learner studying ${record.targetLanguage.label}.
Word: "${record.headword}"
Meaning: "${record.meaning}"
Examples: "$examples"
CEFR level: ${record.cefrLevel.label}

Choose ONE exercise type appropriate for this CEFR level:
- A1/A2: prefer "multiple_choice"
- B1/B2: prefer "fill_in_blank" or "multiple_choice"
- C1/C2: prefer "translation" or "fill_in_blank"

Respond with JSON only (no markdown), exactly one of these shapes:
{"type":"multiple_choice","question":"What does '${record.headword}' mean?","options":["...","...","...","..."],"correctIndex":0}
{"type":"fill_in_blank","sentence":"A sentence with ___ replacing the word.","answer":"${record.headword}"}
{"type":"translation","prompt":"Translate to Vietnamese: 'A short sentence using ${record.headword}'","answer":"Vietnamese translation here"}
''';
  }
}
