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
            target: 'A.',
            typed: 'A.',
            correctChars: 2,
            totalChars: 2,
            durationMs: 1000,
            deletedChars: 3,
          ),
          SentenceResult(
            target: 'B.',
            typed: 'B.',
            correctChars: 2,
            totalChars: 2,
            durationMs: 1000,
            deletedChars: 2,
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
          sentences: const [
            BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
              target: 'A.',
              typed: 'A.',
              correctChars: 2,
              totalChars: 2,
              durationMs: 1000),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      expect(result.finalScore, 1.0);
    });

    test(
        'finalScore subtracts a penalty proportional to the deletion ratio (deletedChars / totalChars)',
        () {
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: const [
            BilingualSentence(
                target: 'A.........', vietnamese: 'A.', vocabIds: [])
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.........',
            typed: 'A.........',
            correctChars: 10,
            totalChars: 10,
            durationMs: 1000,
            deletedChars: 4,
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
          sentences: const [
            BilingualSentence(target: 'A.', vietnamese: 'A.', vocabIds: [])
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: const [
          SentenceResult(
            target: 'A.',
            typed: 'A.',
            correctChars: 0,
            totalChars: 2,
            durationMs: 1000,
            deletedChars: 200,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 0.0);
    });

    test(
        'a small amount of typo-correction relative to a long passage barely dents the score',
        () {
      // Regression test for the reported bug: finishing a long passage with
      // normal typo fixes should not zero out the score.
      final target = 'A' * 200;
      final result = ReadingSessionResult(
        passage: ReadingPassage(
          id: 'p1',
          sentences: [
            BilingualSentence(
                target: target, vietnamese: 'A.', vocabIds: const [])
          ],
          vocabIds: const [],
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        ),
        sentenceResults: [
          SentenceResult(
            target: target, typed: target, correctChars: 200, totalChars: 200,
            durationMs: 1000,
            deletedChars: 20, // 10% of the passage deleted/retyped
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
          BilingualSentence(
              target: 'Hello there friend.',
              vietnamese: 'Chào bạn.',
              vocabIds: []),
          BilingualSentence(
              target: 'Goodbye for now.',
              vietnamese: 'Tạm biệt.',
              vocabIds: []),
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
            generateReadingPassageUseCaseProvider
                .overrideWithValue(mockUseCase),
          ],
        );

    Future<void> generateSession(ReadingPracticeNotifier notifier) =>
        notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('typing without deleting does not increment currentDeletedChars',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('H');
      notifier.updateTypedText('Hi');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 0);
    });

    test(
        'deleting one character at a time increments currentDeletedChars by 1 per character',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      // Stay well under the 19-char target so nothing advances mid-edit.
      notifier.updateTypedText('Hellx'); // typo
      notifier.updateTypedText('Hell'); // deletes 1 char
      notifier.updateTypedText('Hel'); // deletes 1 char

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 2);
    });

    test(
        'deleting several characters in one edit increments currentDeletedChars by that many characters',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText(
          'Helloxxxx'); // typo (9 chars, under the 19-char target)
      notifier.updateTypedText(
          'Hell'); // deletes 5 chars in one go (e.g. select + delete)

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentDeletedChars, 5);
    });

    test(
        'advances to the next sentence when typed length reaches the target, '
        'recording a SentenceResult with correctChars < totalChars for a wrong char',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      // First target is 'Hello there friend.' (19 chars). Type to full length
      // with one wrong char ('x' where 'd' should be).
      notifier.updateTypedText('Hello there frienx.');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentSentenceIndex, 1);
      expect(state.completedSentences.single.correctChars,
          lessThan(state.completedSentences.single.totalChars));
    });

    test('advances even when the typed text overshoots the target length',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hello there friend. and then some');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentSentenceIndex, 1);
    });

    test(
        'completing a sentence records its deletedChars and resets the counter for the next one',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      // Sentence 1 target: 'Hello there friend.' (19 chars).
      notifier.updateTypedText('Hello therx'); // typo (11 chars)
      notifier.updateTypedText('Hello the'); // deletes 2 chars
      notifier.updateTypedText(
          'Hello there friend.'); // reaches full length -> advance

      var state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 1);
      expect(state.completedSentences.first.deletedChars, 2);
      expect(state.currentDeletedChars, 0); // reset for sentence 2
      expect(state.currentSentenceIndex, 1);

      // Sentence 2 target: 'Goodbye for now.' (16 chars).
      notifier.updateTypedText('Goodbye for nox'); // typo (15 chars)
      notifier.updateTypedText('Goodbye for n'); // deletes 2 chars
      notifier.updateTypedText(
          'Goodbye for now.'); // reaches full length -> advance

      state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 2);
      expect(state.completedSentences.last.deletedChars, 2);
      expect(state.isComplete, true);
    });
  });

  group('ReadingPracticeNotifier loadSaved / generationFilters', () {
    late MockGenerateReadingPassageUseCase mockUseCase;
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
          BilingualSentence(
              target: 'Hello there friend.',
              vietnamese: 'Chào bạn.',
              vocabIds: []),
          BilingualSentence(
              target: 'Goodbye for now.',
              vietnamese: 'Tạm biệt.',
              vocabIds: []),
        ],
        vocabIds: const [],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        generatedAt: DateTime(2026),
      );
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
            generateReadingPassageUseCaseProvider
                .overrideWithValue(mockUseCase),
          ],
        );

    test(
        'loadSaved populates state with the passage, isComplete false, '
        'index 0, and carries reusedFromId + generationFilters', () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);

      const filters = {
        'topicIds': ['t1'],
        'maxCefr': 'b1',
        'wordCount': 5,
      };
      notifier.loadSaved(
        fixedPassage,
        savedId: 'saved-1',
        generationFilters: filters,
      );

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.passage, fixedPassage);
      expect(state.isComplete, false);
      expect(state.currentSentenceIndex, 0);
      expect(state.typedText, '');
      expect(state.completedSentences, isEmpty);
      expect(state.reusedFromId, 'saved-1');
      expect(state.generationFilters, filters);
    });

    test('loadSaved leaves reusedFromId + generationFilters null when omitted',
        () {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);

      notifier.loadSaved(fixedPassage);

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.reusedFromId, isNull);
      expect(state.generationFilters, isNull);
    });

    test('generate with generationFilters carries the map onto the state',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);

      const filters = {
        'topicIds': <String>[],
        'maxCefr': 'b1',
        'wordCount': 8,
      };
      await notifier.generate(
        words: const [],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        generationFilters: filters,
      );

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.generationFilters, filters);
      expect(state.reusedFromId, isNull);
    });

    test('generate without generationFilters leaves it null', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);

      await notifier.generate(
        words: const [],
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.generationFilters, isNull);
    });
  });
}
