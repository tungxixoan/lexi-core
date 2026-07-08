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
  });
}
