import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

VocabRecord _record({int sm2Repetitions = 1}) => VocabRecord(
      id: 'id1',
      headword: 'word',
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sm2Repetitions: sm2Repetitions,
    );

void main() {
  group('shouldUseFlashcard', () {
    test('a never-reviewed word is always flashcard, any aiRatio/roll', () {
      expect(shouldUseFlashcard(_record(sm2Repetitions: 0), true, 1.0, 0.99),
          isTrue);
    });

    test('no AI available is always flashcard, any aiRatio/roll', () {
      expect(shouldUseFlashcard(_record(), false, 1.0, 0.99), isTrue);
    });

    test('aiRatio 0 is always flashcard for an eligible word', () {
      expect(shouldUseFlashcard(_record(), true, 0.0, 0.99), isTrue);
      expect(shouldUseFlashcard(_record(), true, 0.0, 0.0), isTrue);
    });

    test('aiRatio 1 is never flashcard for an eligible word', () {
      expect(shouldUseFlashcard(_record(), true, 1.0, 0.99), isFalse);
      expect(shouldUseFlashcard(_record(), true, 1.0, 0.0), isFalse);
    });

    test('reproduces the historical 30/70 split at aiRatio 0.7', () {
      // flashcardProb = 1 - 0.7 = 0.3
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.2), isTrue); // < 0.3
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.3),
          isFalse); // boundary: not flashcard
      expect(shouldUseFlashcard(_record(), true, 0.7, 0.5), isFalse);
    });
  });

  group('drawSessionAiRatio', () {
    test('roll 0 maps to the low end of the range', () {
      expect(drawSessionAiRatio(0.0), 0.20);
    });

    test('roll approaching 1 maps to the high end of the range', () {
      expect(drawSessionAiRatio(1.0), 0.80);
    });

    test('roll 0.5 maps to the midpoint', () {
      expect(drawSessionAiRatio(0.5), 0.50);
    });
  });
}
