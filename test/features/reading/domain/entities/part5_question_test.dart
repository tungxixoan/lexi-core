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
        explanation:
            'Cần thể bị động tương lai vì báo cáo được người khác hoàn thành.',
      );
      expect(question.sentenceWithBlank, contains('___'));
      expect(question.options.length, 4);
      expect(question.correctIndex, 2);
      expect(question.explanation, isNotEmpty);
    });

    test('toJson / fromJson round-trips (keys match web Part5Question)', () {
      const question = Part5Question(
        sentenceWithBlank: 'The report ___ by Friday.',
        options: ['finish', 'finished', 'will be finished', 'finishing'],
        correctIndex: 2,
        explanation: 'Cần thể bị động tương lai.',
      );
      final json = question.toJson();
      expect(json.keys.toSet(),
          {'sentenceWithBlank', 'options', 'correctIndex', 'explanation'});
      final decoded = Part5Question.fromJson(json);
      expect(decoded.sentenceWithBlank, question.sentenceWithBlank);
      expect(decoded.options, question.options);
      expect(decoded.correctIndex, 2);
      expect(decoded.explanation, question.explanation);
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

    test('toJson / fromJson round-trips', () {
      final json = set.toJson();
      expect(json['questions'], hasLength(15));
      expect((json['volumes'] as List).toSet(), {'vol3', 'vol4'});
      expect(json['context'], 'business');
      expect(json['targetLanguage'], 'english');

      final decoded = Part5Set.fromJson(json);
      expect(decoded.id, set.id);
      expect(decoded.questions.length, 15);
      expect(decoded.questions[3].correctIndex, set.questions[3].correctIndex);
      expect(decoded.volumes, {EconomyVolume.vol3, EconomyVolume.vol4});
      expect(decoded.context, AppContext.business);
      expect(decoded.targetLanguage, Language.english);
      expect(decoded.generatedAt, set.generatedAt);
    });

    test('fromJson decodes a web-shaped passage sub-object without throwing',
        () {
      // apps/web savedReadingExercises.ts writes only the web `Part5Set` keys
      // (`questions`) — no id/volumes/context/targetLanguage/generatedAt.
      final json = <String, dynamic>{
        'questions': [
          {
            'sentenceWithBlank': 'The report is ___ complete.',
            'options': ['near', 'nearly', 'nearness', 'neared'],
            'correctIndex': 1,
            'explanation': 'adverb',
          },
        ],
      };
      final decoded = Part5Set.fromJson(json);
      expect(decoded.questions.single.correctIndex, 1);
      expect(decoded.targetLanguage, Language.english);
      expect(decoded.context, AppContext.general);
    });

    test('fromJson skips an unrecognized volume string instead of throwing',
        () {
      final json = <String, dynamic>{
        'questions': const <dynamic>[],
        'volumes': ['vol3', 'vol9'], // 'vol9' doesn't exist
      };
      final decoded = Part5Set.fromJson(json);
      expect(decoded.volumes, {EconomyVolume.vol3});
    });
  });
}
