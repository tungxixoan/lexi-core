import '../../../vocabulary/domain/entities/vocab_record.dart';

sealed class Exercise {
  const Exercise({required this.vocabRecord});
  final VocabRecord vocabRecord;
}

final class FlashcardExercise extends Exercise {
  const FlashcardExercise({required super.vocabRecord});
}

final class MultipleChoiceExercise extends Exercise {
  const MultipleChoiceExercise({
    required super.vocabRecord,
    required this.question,
    required this.options,
    required this.correctIndex,
  });
  final String question;
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
}

final class FillInBlankExercise extends Exercise {
  const FillInBlankExercise({
    required super.vocabRecord,
    required this.sentence,
    required this.answer,
  });
  final String sentence; // contains exactly one '___'
  final String answer; // lowercase expected answer
}

final class TranslationExercise extends Exercise {
  const TranslationExercise({
    required super.vocabRecord,
    required this.prompt,
    required this.answer,
  });
  final String
      prompt; // e.g. "Translate to Vietnamese: 'The ephemeral beauty...'"
  final String answer; // Gemini-provided answer key
}
