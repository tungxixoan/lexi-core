import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';

void main() {
  group('BilingualSentence', () {
    test('fromJson round-trips through toJson', () {
      const sentence = BilingualSentence(
        target: 'She showed great perseverance.',
        vietnamese: 'Cô ấy thể hiện sự kiên trì tuyệt vời.',
        vocabIds: ['id1', 'id2'],
      );
      final json = sentence.toJson();
      final decoded = BilingualSentence.fromJson(json);
      expect(decoded.target, sentence.target);
      expect(decoded.vietnamese, sentence.vietnamese);
      expect(decoded.vocabIds, sentence.vocabIds);
    });

    test('fromJson handles missing vocabIds gracefully', () {
      final json = <String, dynamic>{
        'target': 'Hello world.',
        'vietnamese': 'Xin chào thế giới.',
      };
      final sentence = BilingualSentence.fromJson(json);
      expect(sentence.vocabIds, isEmpty);
    });

    test('vocabWords round-trips through toJson (web reads this key)', () {
      const sentence = BilingualSentence(
        target: 'She showed great perseverance.',
        vietnamese: 'Cô ấy thể hiện sự kiên trì tuyệt vời.',
        vocabIds: ['id1'],
        vocabWords: ['perseverance'],
      );
      final json = sentence.toJson();
      expect(json['vocabWords'], ['perseverance']);
      expect(json['vocabIds'], ['id1']);
      final decoded = BilingualSentence.fromJson(json);
      expect(decoded.vocabWords, ['perseverance']);
      expect(decoded.vocabIds, ['id1']);
    });

    test('fromJson defaults vocabWords to empty when the key is absent', () {
      final sentence = BilingualSentence.fromJson(<String, dynamic>{
        'target': 'Hi.',
        'vietnamese': 'Chào.',
      });
      expect(sentence.vocabWords, isEmpty);
    });
  });

  group('ReadingPassage', () {
    final passage = ReadingPassage(
      id: 'test-id',
      sentences: const [
        BilingualSentence(
          target: 'First sentence.',
          vietnamese: 'Câu đầu tiên.',
          vocabIds: ['id1'],
        ),
        BilingualSentence(
          target: 'Second sentence.',
          vietnamese: 'Câu thứ hai.',
          vocabIds: ['id2'],
        ),
      ],
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 6),
    );

    test('has correct sentence count', () {
      expect(passage.sentences.length, 2);
    });

    test('vocabIds contains all sentence vocab IDs', () {
      expect(passage.vocabIds, containsAll(['id1', 'id2']));
    });

    test('fromJson round-trips through toJson', () {
      final original = ReadingPassage(
        id: 'p1',
        sentences: const [
          BilingualSentence(
            target: 'Hello.',
            vietnamese: 'Xin chào.',
            vocabIds: ['id1'],
          ),
        ],
        vocabIds: const ['id1'],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        generatedAt: DateTime(2026, 1, 1),
      );
      final json = original.toJson();
      final restored = ReadingPassage.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.sentences.length, 1);
      expect(restored.sentences[0].target, 'Hello.');
      expect(restored.vocabIds, ['id1']);
      expect(restored.level, CEFRLevel.b1);
      expect(restored.context, AppContext.general);
      expect(restored.targetLanguage, Language.english);
      expect(restored.generatedAt, original.generatedAt);
    });

    test('fromJson decodes a web-shaped bilingual passage sub-object', () {
      // Exactly what apps/web savedReadingExercises.ts writes for a bilingual
      // `passage`: only `sentences` (with `vocabWords`, no `vocabIds` per
      // sentence) + a top-level `vocabIds` — no id/level/context/
      // targetLanguage/generatedAt.
      final json = <String, dynamic>{
        'sentences': [
          {
            'target': 'Hi.',
            'vietnamese': 'Chào.',
            'vocabWords': ['hi']
          },
        ],
        'vocabIds': <String>[],
      };
      final decoded = ReadingPassage.fromJson(json);
      expect(decoded.sentences.single.target, 'Hi.');
      expect(decoded.sentences.single.vocabWords, ['hi']);
      expect(decoded.level, CEFRLevel.b1);
      expect(decoded.context, AppContext.general);
      expect(decoded.targetLanguage, Language.english);
      expect(decoded.id, '');
    });
  });
}
