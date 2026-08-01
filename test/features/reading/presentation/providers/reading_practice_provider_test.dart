import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_reading_passage_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';

class MockGenerateReadingPassageUseCase extends Mock
    implements GenerateReadingPassageUseCase {}

void main() {
  group('SentenceResult/ReadingSessionResult scoring', () {
    test('deletedChars defaults to 0', () {
      const result = SentenceResult(
        target: 'Hello world.',
        typed: 'Hello world.',
        correctChars: 12,
        totalChars: 12,
        durationMs: 5000,
      );
      expect(result.deletedChars, 0);
    });

    test('totalDeletedChars sums deletedChars across all sentences', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [
            BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: []),
            BilingualSentence(target: 'B.', vietnamese: 'B.', vocabIds: []),
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2,
            durationMs: 1000, deletedChars: 3,
          ),
          SentenceResult(
            target: 'B.', typed: 'B.', correctChars: 2, totalChars: 2,
            durationMs: 1000, deletedChars: 2,
          ),
        ],
        totalDuration: const Duration(seconds: 2),
      );
      expect(result.totalDeletedChars, 5);
    });

    test('finalScore equals overallAccuracy when there are no deletions', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2, durationMs: 1000),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      expect(result.finalScore, 1.0);
    });

    test('finalScore subtracts a penalty proportional to the deletion ratio (deletedChars / totalChars)', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.........', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.........', typed: 'A.........', correctChars: 10, totalChars: 10,
            durationMs: 1000, deletedChars: 4,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      // deletionRatio = 4/10 = 0.4; penalty = 0.5 * 0.4 = 0.2
      expect(result.finalScore, closeTo(0.80, 0.0001));
    });

    test('finalScore never goes below 0', () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.', typed: 'A.', correctChars: 0, totalChars: 2,
            durationMs: 1000, deletedChars: 200,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 0.0);
    });

    test('a small amount of typo-correction relative to a long passage barely dents the score', () {
      // Regression test for the reported bug: finishing a long passage with
      // normal typo fixes should not zero out the score.
      final target = 'A' * 200;
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: [BilingualSentence(target: target, vietnamese: 'A.', vocabIds: const [])],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: [
          SentenceResult(
            target: target, typed: target, correctChars: 200, totalChars: 200,
            durationMs: 1000, deletedChars: 20, // 10% of the passage deleted/retyped
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      // deletionRatio = 20/200 = 0.1; penalty = 0.5 * 0.1 = 0.05
      expect(result.finalScore, closeTo(0.95, 0.0001));
    });
  });

  group('ReadingPracticeNotifier deletion tracking', () {
    late MockGenerateReadingPassageUseCase mockUseCase;
    late List<VocabRecord> words;
    late ReadingPassage fixedPassage;

    setUpAll(() {
      registerFallbackValue(CEFRLevel.a1);
      registerFallbackValue(AppContext.general);
      registerFallbackValue(Language.english);
    });

    setUp(() {
      mockUseCase = MockGenerateReadingPassageUseCase();
      fixedPassage = ReadingPassage(
        id: 'p1',
        sentences: const [
          BilingualSentence(target: 'Hi.', vietnamese: 'Chào.', vocabIds: []),
          BilingualSentence(target: 'Bye.', vietnamese: 'Tạm biệt.', vocabIds: []),
        ],
        vocabIds: const [],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        generatedAt: DateTime(2026),
      );
      words = const [];
      when(
        () => mockUseCase.execute(
          words: any(named: 'words'),
          level: any(named: 'level'),
          context: any(named: 'context'),
          targetLanguage: any(named: 'targetLanguage'),
        ),
      ).thenAnswer((_) async => fixedPassage);
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateReadingPassageUseCaseProvider.overrideWithValue(mockUseCase),
          ],
        );

    Future<void> generateSession(ReadingPracticeNotifier notifier) => notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('typing without deleting does not increment currentDeletedChars', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('H');
      notifier.updateTypedText('Hi');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 0);
    });

    test('deleting one character at a time increments currentDeletedChars by 1 per character', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix'); // typo
      notifier.updateTypedText('Hi'); // deletes 1 char
      notifier.updateTypedText('H'); // deletes 1 char

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 2);
    });

    test('deleting several characters in one edit increments currentDeletedChars by that many characters', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hixxxx'); // typo
      notifier.updateTypedText('H'); // deletes 5 chars in one go (e.g. select + delete)

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 5);
    });

    test('completing a sentence records its deletedChars and resets the counter for the next one',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix');
      notifier.updateTypedText('Hi'); // deletes 1 char: 'Hix' (3) -> 'Hi' (2)
      notifier.updateTypedText('Hi.'); // retype the period to match the target

      var state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 1);
      expect(state.completedSentences.first.deletedChars, 1);
      expect(state.currentDeletedChars, 0); // reset for sentence 2
      expect(state.currentSentenceIndex, 1);

      notifier.updateTypedText('Byex');
      notifier.updateTypedText('Bye');
      notifier.updateTypedText('Bye.');

      state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 2);
      expect(state.completedSentences.last.deletedChars, 1);
      expect(state.isComplete, true);
    });
  });
}
