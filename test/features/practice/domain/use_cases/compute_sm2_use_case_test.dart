import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/use_cases/compute_sm2_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

void main() {
  const useCase = ComputeSm2UseCase();

  VocabRecord makeRecord({
    int sm2Repetitions = 0,
    double sm2EaseFactor = 2.5,
    int sm2Interval = 1,
  }) =>
      VocabRecord(
        id: 'test-id',
        headword: 'ephemeral',
        inputType: InputType.word,
        ipa: '/ɪˈfɛm.ər.əl/',
        meaning: 'lasting for a very short time',
        examples: const ['The ephemeral beauty of cherry blossoms.'],
        personalNotes: '',
        topicIds: const [],
        targetLanguage: Language.english,
        cefrLevel: CEFRLevel.b2,
        activeContext: AppContext.general,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        sm2Repetitions: sm2Repetitions,
        sm2EaseFactor: sm2EaseFactor,
        sm2Interval: sm2Interval,
      );

  group('ComputeSm2UseCase', () {
    group('quality < 3 (fail)', () {
      test('resets repetitions to 0', () {
        final r = makeRecord(sm2Repetitions: 3, sm2Interval: 15);
        final result = useCase.compute(r, 1);
        expect(result.sm2Repetitions, 0);
      });

      test('resets interval to 1', () {
        final r = makeRecord(sm2Repetitions: 3, sm2Interval: 15);
        final result = useCase.compute(r, 1);
        expect(result.sm2Interval, 1);
      });

      test('nextReviewAt is approximately 1 day from now', () {
        final before = DateTime.now();
        final result = useCase.compute(makeRecord(), 0);
        final after = DateTime.now();
        expect(result.nextReviewAt!.isAfter(before.add(const Duration(hours: 23))), isTrue);
        expect(result.nextReviewAt!.isBefore(after.add(const Duration(days: 1, seconds: 1))), isTrue);
      });

      test('quality=2 also fails (< 3 threshold)', () {
        final result = useCase.compute(makeRecord(sm2Repetitions: 2), 2);
        expect(result.sm2Repetitions, 0);
        expect(result.sm2Interval, 1);
      });
    });

    group('quality >= 3 (pass)', () {
      test('first repetition (rep=0): interval becomes 1', () {
        final result = useCase.compute(makeRecord(sm2Repetitions: 0), 5);
        expect(result.sm2Interval, 1);
        expect(result.sm2Repetitions, 1);
      });

      test('second repetition (rep=1): interval becomes 6', () {
        final result = useCase.compute(makeRecord(sm2Repetitions: 1, sm2Interval: 1), 5);
        expect(result.sm2Interval, 6);
        expect(result.sm2Repetitions, 2);
      });

      test('third repetition (rep=2): interval = round(6 * 2.5) = 15', () {
        final result = useCase.compute(makeRecord(sm2Repetitions: 2, sm2Interval: 6), 5);
        expect(result.sm2Interval, 15);
        expect(result.sm2Repetitions, 3);
      });

      test('quality=5 increases EF slightly', () {
        final r = makeRecord(sm2EaseFactor: 2.3);
        final result = useCase.compute(r, 5);
        // newEF = 2.3 + 0.1 - 0 * 0.08 = 2.4
        expect(result.sm2EaseFactor, closeTo(2.4, 0.001));
      });

      test('quality=3 decreases EF', () {
        final r = makeRecord(sm2EaseFactor: 2.5);
        final result = useCase.compute(r, 3);
        // newEF = 2.5 + 0.1 - (5-3)*0.08 = 2.5 + 0.1 - 0.16 = 2.44
        expect(result.sm2EaseFactor, closeTo(2.44, 0.001));
      });

      test('EF clamped at minimum 1.3', () {
        final r = makeRecord(sm2EaseFactor: 1.3, sm2Repetitions: 2, sm2Interval: 6);
        final result = useCase.compute(r, 3);
        expect(result.sm2EaseFactor, greaterThanOrEqualTo(1.3));
      });

      test('EF clamped at maximum 2.5', () {
        final r = makeRecord(sm2EaseFactor: 2.5);
        final result = useCase.compute(r, 5);
        expect(result.sm2EaseFactor, lessThanOrEqualTo(2.5));
      });

      test('nextReviewAt is in the future', () {
        final result = useCase.compute(makeRecord(), 5);
        expect(result.nextReviewAt!.isAfter(DateTime.now()), isTrue);
      });

      test('updatedAt is updated', () {
        final before = DateTime.now();
        final result = useCase.compute(makeRecord(), 5);
        expect(result.updatedAt.isAfter(before) || result.updatedAt.isAtSameMomentAs(before), isTrue);
      });
    });
  });
}
