import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';

void main() {
  group('Part5Question', () {
    test('holds sentence, 4 options, correct index, and explanation', () {
      const question = Part5Question(
        sentenceWithBlank: 'The report ___ by Friday.',
        options: ['finish', 'finished', 'will be finished', 'finishing'],
        correctIndex: 2,
        explanation: 'Cần thể bị động tương lai vì báo cáo được người khác hoàn thành.',
      );
      expect(question.sentenceWithBlank, contains('___'));
      expect(question.options.length, 4);
      expect(question.correctIndex, 2);
      expect(question.explanation, isNotEmpty);
    });
  });

  group('Part5Set', () {
    final set = Part5Set(
      id: 'test-id',
      questions: List.generate(
        15,
        (i) => Part5Question(
          sentenceWithBlank: 'Sentence $i ___.',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: i % 4,
          explanation: 'Explanation $i',
        ),
      ),
      volumes: const {EconomyVolume.vol3, EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 3),
    );

    test('always has exactly 15 questions', () {
      expect(set.questions.length, 15);
    });

    test('holds volumes, context, targetLanguage', () {
      expect(set.volumes, {EconomyVolume.vol3, EconomyVolume.vol4});
      expect(set.context, AppContext.business);
      expect(set.targetLanguage, Language.english);
    });
  });
}
