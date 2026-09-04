import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i text with (1)___ (2)___ (3)___ (4)___ blanks.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

void main() {
  group('Part6Question', () {
    test('holds 4 options, correct index, and explanation', () {
      const question = Part6Question(
        options: ['increase', 'increased', 'increasing', 'will increase'],
        correctIndex: 3,
        explanation: 'Cần thì tương lai vì mệnh đề chỉ kế hoạch sắp tới.',
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 3);
      expect(question.explanation, isNotEmpty);
    });

    test('toJson / fromJson round-trips (keys match web Part6Question)', () {
      const question = Part6Question(
        options: ['increase', 'increased', 'increasing', 'will increase'],
        correctIndex: 3,
        explanation: 'Cần thì tương lai.',
      );
      final json = question.toJson();
      expect(json.keys.toSet(), {'options', 'correctIndex', 'explanation'});
      final decoded = Part6Question.fromJson(json);
      expect(decoded.options, question.options);
      expect(decoded.correctIndex, 3);
      expect(decoded.explanation, question.explanation);
    });
  });

  group('Part6Passage', () {
    test('always has exactly 4 questions', () {
      expect(_passage(0).questions.length, 4);
    });

    test('passageText contains all 4 numbered blank markers', () {
      final text = _passage(0).passageText;
      expect(text, contains('(1)___'));
      expect(text, contains('(2)___'));
      expect(text, contains('(3)___'));
      expect(text, contains('(4)___'));
    });

    test('toJson / fromJson round-trips (keys match web Part6Passage)', () {
      final passage = _passage(2);
      final json = passage.toJson();
      expect(json.keys.toSet(), {'passageText', 'questions'});
      final decoded = Part6Passage.fromJson(json);
      expect(decoded.passageText, passage.passageText);
      expect(decoded.questions.length, 4);
      expect(
          decoded.questions[1].explanation, passage.questions[1].explanation);
    });
  });

  group('Part6Set', () {
    final set = Part6Set(
      id: 'test-id',
      passages: List.generate(3, _passage),
      volumes: const {EconomyVolume.vol4},
      context: AppContext.business,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 8, 3),
    );

    test('always has exactly 3 passages', () {
      expect(set.passages.length, 3);
    });

    test('holds volumes, context, targetLanguage', () {
      expect(set.volumes, {EconomyVolume.vol4});
      expect(set.context, AppContext.business);
      expect(set.targetLanguage, Language.english);
    });

    test('toJson / fromJson round-trips', () {
      final json = set.toJson();
      expect(json['passages'], hasLength(3));
      expect((json['volumes'] as List).toSet(), {'vol4'});

      final decoded = Part6Set.fromJson(json);
      expect(decoded.id, set.id);
      expect(decoded.passages.length, 3);
      expect(decoded.passages[0].questions.length, 4);
      expect(decoded.volumes, {EconomyVolume.vol4});
      expect(decoded.context, AppContext.business);
      expect(decoded.targetLanguage, Language.english);
      expect(decoded.generatedAt, set.generatedAt);
    });

    test('fromJson decodes a web-shaped passage sub-object without throwing', () {
      final json = <String, dynamic>{
        'passages': [
          {
            'passageText': 'We (1)___ to inform you.',
            'questions': [
              {
                'options': ['are pleased', 'pleasing', 'pleased', 'please'],
                'correctIndex': 0,
                'explanation': 'x',
              },
            ],
          },
        ],
      };
      final decoded = Part6Set.fromJson(json);
      expect(decoded.passages.single.passageText, 'We (1)___ to inform you.');
      expect(decoded.targetLanguage, Language.english);
      expect(decoded.context, AppContext.general);
    });
  });
}
