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
    test('backspaceCount defaults to 0', () {
      const result = SentenceResult(
        target: 'Hello world.',
        typed: 'Hello world.',
        correctChars: 12,
        totalChars: 12,
        durationMs: 5000,
      );
      expect(result.backspaceCount, 0);
    });

    test('totalBackspaceCount sums backspaceCount across all sentences', () {
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
            durationMs: 1000, backspaceCount: 3,
          ),
          SentenceResult(
            target: 'B.', typed: 'B.', correctChars: 2, totalChars: 2,
            durationMs: 1000, backspaceCount: 2,
          ),
        ],
        totalDuration: const Duration(seconds: 2),
      );
      expect(result.totalBackspaceCount, 5);
    });

    test('finalScore equals overallAccuracy when there are no backspaces', () {
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

    test('finalScore subtracts 1% per backspace from overallAccuracy', () {
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
            target: 'A.', typed: 'A.', correctChars: 2, totalChars: 2,
            durationMs: 1000, backspaceCount: 10,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.overallAccuracy, 1.0);
      expect(result.finalScore, closeTo(0.90, 0.0001)); // 1.0 - 10*0.01
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
            durationMs: 1000, backspaceCount: 200,
          ),
        ],
        totalDuration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 0.0);
    });
  });

  group('ReadingPracticeNotifier backspace tracking', () {
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

    test('typing without deleting does not increment currentBackspaceCount', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('H');
      notifier.updateTypedText('Hi');

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentBackspaceCount, 0);
    });

    test('deleting a character increments currentBackspaceCount by 1 per deletion', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix'); // typo
      notifier.updateTypedText('Hi'); // backspace 1
      notifier.updateTypedText('H'); // backspace 2

      final state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.currentBackspaceCount, 2);
    });

    test('completing a sentence records its backspaceCount and resets the counter for the next one',
        () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(readingPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hix');
      notifier.updateTypedText('Hi'); // backspace: 'Hix' (3) -> 'Hi' (2)
      notifier.updateTypedText('Hi.'); // retype the period to match the target

      var state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 1);
      expect(state.completedSentences.first.backspaceCount, 1);
      expect(state.currentBackspaceCount, 0); // reset for sentence 2
      expect(state.currentSentenceIndex, 1);

      notifier.updateTypedText('Byex');
      notifier.updateTypedText('Bye');
      notifier.updateTypedText('Bye.');

      state = c.read(readingPracticeNotifierProvider).value!;
      expect(state.completedSentences.length, 2);
      expect(state.completedSentences.last.backspaceCount, 1);
      expect(state.isComplete, true);
    });
  });
}
