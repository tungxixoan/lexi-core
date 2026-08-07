import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Question $i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'Double question $q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Double explanation $q',
        ),
      ),
    );

void main() {
  group('Part7Question', () {
    test('holds question, 4 options, correct index, and explanation', () {
      const question = Part7Question(
        question: 'What is the main purpose of this notice?',
        options: ['To announce a delay', 'To request feedback', 'To advertise a sale', 'To confirm a booking'],
        correctIndex: 0,
        explanation: 'Thông báo nói rõ về việc trì hoãn.',
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 0);
      expect(question.explanation, isNotEmpty);
    });
  });

  group('Part7PassageGroup', () {
    test('a single-passage group has exactly 1 document', () {
      expect(_singleGroup(0, 3).documents.length, 1);
    });

    test('a double-passage group has exactly 2 documents', () {
      expect(_doubleGroup().documents.length, 2);
    });

    test('question count can vary per group (3, 4, or 5)', () {
      expect(_singleGroup(0, 3).questions.length, 3);
      expect(_singleGroup(1, 4).questions.length, 4);
      expect(_doubleGroup().questions.length, 5);
    });
  });

  group('Part7Set', () {
    final set = Part7Set(
      id: 'test-id',
      passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
      volumes: const {EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 7),
    );

    test('always has exactly 3 passage groups', () {
      expect(set.passageGroups.length, 3);
    });

    test('holds volumes, context, targetLanguage', () {
      expect(set.volumes, {EconomyVolume.vol4});
      expect(set.context, AppContext.business);
      expect(set.targetLanguage, Language.english);
    });
  });
}
