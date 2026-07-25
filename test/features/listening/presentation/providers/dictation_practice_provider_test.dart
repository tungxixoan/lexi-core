import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_dictation_item_use_case.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockGenerateDictationItemUseCase extends Mock
    implements GenerateDictationItemUseCase {}

class MockTtsService extends Mock implements TtsService {}

DictationItem _item(String target) => DictationItem(
      id: 'item-1',
      target: target,
      vietnamese: '',
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026),
    );

void main() {
  group('seekPenaltyFraction', () {
    test('returns the 1% floor when reheardRatio is at or below 20%', () {
      expect(seekPenaltyFraction(wordIndex: 8, totalWords: 10), closeTo(0.01, 0.0001)); // ratio 0.2 exactly
      expect(seekPenaltyFraction(wordIndex: 9, totalWords: 10), closeTo(0.01, 0.0001)); // ratio 0.1
    });

    test('scales linearly from 1% to 5% as reheardRatio grows from 20% to 100%', () {
      expect(seekPenaltyFraction(wordIndex: 5, totalWords: 10), closeTo(0.025, 0.0001)); // ratio 0.5
      expect(seekPenaltyFraction(wordIndex: 0, totalWords: 10), closeTo(0.05, 0.0001)); // ratio 1.0
    });

    test('returns 0 when totalWords is 0 (guards against division by zero)', () {
      expect(seekPenaltyFraction(wordIndex: 0, totalWords: 0), 0.0);
    });
  });

  group('DictationSessionResult scoring', () {
    test('charAccuracy is 1.0 for an exact match', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 0,
        duration: const Duration(seconds: 5),
      );
      expect(result.charAccuracy, 1.0);
      expect(result.finalScore, 1.0);
      expect(result.sm2Quality, 5);
    });

    test('charAccuracy counts only matching positions', () {
      // 'Hxllo world.' vs 'Hello world.' — 1 mismatch out of 12 chars.
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hxllo world.',
        replayCount: 0,
        duration: const Duration(seconds: 5),
      );
      expect(result.totalChars, 12);
      expect(result.correctChars, 11);
      expect(result.charAccuracy, closeTo(11 / 12, 0.0001));
    });

    test('finalScore subtracts 5% per replay beyond the first listen', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 2,
        duration: const Duration(seconds: 5),
      );
      expect(result.charAccuracy, 1.0);
      expect(result.finalScore, closeTo(0.90, 0.0001)); // 1.0 - 2*0.05
    });

    test('finalScore also subtracts seekPenaltyTotal on top of the replay penalty', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 1,
        duration: const Duration(seconds: 5),
        seekPenaltyTotal: 0.03,
      );
      expect(result.finalScore, closeTo(0.92, 0.0001)); // 1.0 - 0.05 - 0.03
    });

    test('finalScore never goes below 0', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: '',
        replayCount: 100,
        duration: const Duration(seconds: 5),
      );
      expect(result.finalScore, 0.0);
    });

    test('sm2Quality maps finalScore to the 0-5 SM-2 scale', () {
      DictationSessionResult withScoreInputs(int replayCount) => DictationSessionResult(
            item: _item('Hello world.'),
            typed: 'Hello world.',
            replayCount: replayCount,
            duration: const Duration(seconds: 5),
          );

      expect(withScoreInputs(0).sm2Quality, 5); // finalScore 1.00 >= 0.95
      expect(withScoreInputs(3).sm2Quality, 4); // finalScore 0.85 >= 0.80
      expect(withScoreInputs(6).sm2Quality, 3); // finalScore 0.70 >= 0.60
      expect(withScoreInputs(9).sm2Quality, 2); // finalScore 0.55 >= 0.40
      expect(withScoreInputs(20).sm2Quality, 0); // finalScore 0.00
    });

    test('charAccuracy is 1.0 when target is empty', () {
      final result = DictationSessionResult(
        item: _item(''),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.charAccuracy, 1.0);
    });
  });

  group('DictationSessionResult blank-based scoring (Dễ/Trung bình)', () {
    // "The quick brown fox jumps" — 5 words, indices 0-4.
    final easyItem = _item('The quick brown fox jumps');
    const easyBlanks = [
      BlankSpan(startWordIndex: 1, wordCount: 1), // "quick"
      BlankSpan(startWordIndex: 3, wordCount: 1), // "fox"
    ];

    test('blockAccuracy is 1.0 when blanks is empty (default/hard)', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.blockAccuracy, 1.0);
    });

    test('isBlankCorrect matches case-insensitively and trims whitespace', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['  QUICK ', 'fox'],
      );
      expect(result.isBlankCorrect(0), isTrue);
      expect(result.isBlankCorrect(1), isTrue);
    });

    test('blockAccuracy counts correct blanks out of total', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'wrong'],
      );
      expect(result.isBlankCorrect(0), isTrue);
      expect(result.isBlankCorrect(1), isFalse);
      expect(result.blockAccuracy, 0.5);
    });

    test('finalScore uses blockAccuracy (not charAccuracy) when difficulty is not hard', () {
      final result = DictationSessionResult(
        item: easyItem,
        typed: 'completely different text that would score low on charAccuracy',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'fox'], // both correct
      );
      expect(result.blockAccuracy, 1.0);
      expect(result.finalScore, 1.0); // ignores the garbage `typed` field entirely
    });

    test('finalScore still uses charAccuracy when difficulty is hard (default), '
        'even if blanks/blankAnswers happen to be set', () {
      final result = DictationSessionResult(
        item: _item('Hello world.'),
        typed: 'Hello world.',
        replayCount: 0,
        duration: const Duration(seconds: 1),
      );
      expect(result.finalScore, 1.0); // via charAccuracy, unaffected by this task
    });

    test('sm2Quality maps blockAccuracy-derived finalScore using the same thresholds', () {
      final allCorrect = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'fox'],
      );
      expect(allCorrect.sm2Quality, 5); // blockAccuracy 1.0

      final halfCorrect = DictationSessionResult(
        item: easyItem,
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: easyBlanks,
        blankAnswers: const ['quick', 'wrong'],
      );
      expect(halfCorrect.sm2Quality, 2); // blockAccuracy 0.5 >= 0.40
    });

    test('isBlankCorrect strips trailing punctuation attached to the target word', () {
      // "fox," has a comma glued on by whitespace-only tokenization; typing
      // "fox" without the comma should still be graded correct.
      final result = DictationSessionResult(
        item: _item('The quick brown fox, jumps'),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: const [BlankSpan(startWordIndex: 3, wordCount: 1)], // "fox,"
        blankAnswers: const ['fox'],
      );
      expect(result.isBlankCorrect(0), isTrue);
    });

    test('isBlankCorrect strips leading/trailing quotes and sentence-ending periods', () {
      final quoted = DictationSessionResult(
        item: _item('She said "hello" loudly'),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: const [BlankSpan(startWordIndex: 2, wordCount: 1)], // '"hello"'
        blankAnswers: const ['hello'],
      );
      expect(quoted.isBlankCorrect(0), isTrue);

      final sentenceEnd = DictationSessionResult(
        item: _item('Hello world.'),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: const [BlankSpan(startWordIndex: 1, wordCount: 1)], // "world."
        blankAnswers: const ['World'],
      );
      expect(sentenceEnd.isBlankCorrect(0), isTrue);
    });

    test('isBlankCorrect does NOT strip internal punctuation (apostrophes/hyphens)', () {
      // Target word itself is "don't" — an answer missing the apostrophe
      // must still be marked incorrect, proving we only strip edges.
      final result = DictationSessionResult(
        item: _item("I don't know"),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: const [BlankSpan(startWordIndex: 1, wordCount: 1)], // "don't"
        blankAnswers: const ['dont'],
      );
      expect(result.isBlankCorrect(0), isFalse);

      final exactMatch = DictationSessionResult(
        item: _item("I don't know"),
        typed: '',
        replayCount: 0,
        duration: const Duration(seconds: 1),
        difficulty: DictationDifficulty.easy,
        blanks: const [BlankSpan(startWordIndex: 1, wordCount: 1)], // "don't"
        blankAnswers: const ["don't"],
      );
      expect(exactMatch.isBlankCorrect(0), isTrue);
    });
  });

  group('DictationPracticeNotifier lifecycle', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('Hello world.');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);

      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider
                .overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    Future<void> generateSession(DictationPracticeNotifier notifier) =>
        notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('generate() populates a fresh session state', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);

      await generateSession(notifier);

      final state = c.read(dictationPracticeNotifierProvider).value;
      expect(state, isNotNull);
      expect(state!.item, same(fixedItem));
      expect(state.typedText, '');
      expect(state.replayCount, 0);
      expect(state.hasPlayedOnce, false);
      expect(state.isComplete, false);
    });

    test(
        'first play() sets hasPlayedOnce without incrementing replayCount, '
        'and speaks the item once', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.play();

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, true);
      expect(state.replayCount, 0);
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1);
    });

    test(
        'second play() increments replayCount and keeps hasPlayedOnce true, '
        'and speaks the item again', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.play();
      await notifier.play();

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, true);
      expect(state.replayCount, 1);
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(2);
    });

    test('updateTypedText() updates typedText without completing', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.updateTypedText('Hello wor');

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.typedText, 'Hello wor');
      expect(state.isComplete, false);
    });

    test('submit() marks the session complete', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      notifier.submit();

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.isComplete, true);
    });

    test('reset() returns state to AsyncData(null)', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);
      notifier.submit();

      notifier.reset();

      expect(
        c.read(dictationPracticeNotifierProvider),
        const AsyncValue<DictationSessionState?>.data(null),
      );
    });
  });

  group('DictationPracticeNotifier difficulty/blanks', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('The quick brown fox jumps over the lazy dog again');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    test('generate() without difficulty defaults to hard with no blanks', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);

      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      );

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.difficulty, DictationDifficulty.hard);
      expect(state.blanks, isEmpty);
      expect(state.blankAnswers, isEmpty);
      expect(state.isClozeMode, isFalse);
    });

    test('generate() with difficulty: easy populates exactly 2 blanks and matching blankAnswers', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);

      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.difficulty, DictationDifficulty.easy);
      expect(state.blanks.length, 2);
      expect(state.blankAnswers, ['', '']);
      expect(state.isClozeMode, isTrue);
    });

    test('updateBlankAnswer() updates only the targeted blank without completing', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      notifier.updateBlankAnswer(0, 'quick');

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.blankAnswers[0], 'quick');
      expect(state.blankAnswers[1], '');
      expect(state.isComplete, false);
    });

    test('updateBlankAnswer() with an out-of-range blankIndex is a no-op', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      expect(() => notifier.updateBlankAnswer(-1, 'quick'), returnsNormally);
      expect(() => notifier.updateBlankAnswer(2, 'quick'), returnsNormally);

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.blankAnswers, ['', '']);
      expect(state.isComplete, false);
    });

    test('allBlanksFilled is true only once every blank has non-empty text', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await notifier.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
        difficulty: DictationDifficulty.easy,
      );

      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isFalse);

      notifier.updateBlankAnswer(0, 'quick');
      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isFalse);

      notifier.updateBlankAnswer(1, 'fox');
      expect(c.read(dictationPracticeNotifierProvider).value!.allBlanksFilled, isTrue);
    });
  });

  group('DictationPracticeNotifier seekTo', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUpAll(() {
      registerFallbackValue(Language.english);
    });

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('Hello world.');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
      when(() => mockTts.speak(any(), any(), rate: any(named: 'rate')))
          .thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    Future<void> generateSession(DictationPracticeNotifier notifier) =>
        notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('first seekTo() sets hasPlayedOnce and seekCount without adding a penalty', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(1); // "world."

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, true);
      expect(state.seekCount, 1);
      expect(state.seekPenaltyTotal, 0.0);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.speak('world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
    });

    test('seekTo() after the first listen adds the correct penalty fraction', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(1); // first listen via seek: free
      await notifier.seekTo(0); // "Hello world." — wordsReheard 2/2 = 100% ratio -> max 5%

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.seekCount, 2);
      expect(state.seekPenaltyTotal, closeTo(0.05, 0.0001));
      verify(() => mockTts.speak('Hello world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
    });

    test('seekTo() with an out-of-range wordIndex is a no-op', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.seekTo(-1);
      await notifier.seekTo(2); // only indices 0-1 are valid for a 2-word sentence

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.hasPlayedOnce, false);
      expect(state.seekCount, 0);
      expect(state.seekPenaltyTotal, 0.0);
      verifyNever(() => mockTts.speak(any(), any(), rate: any(named: 'rate')));
    });
  });

  group('DictationPracticeNotifier setSpeed', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('Hello world.');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
      when(() => mockTts.stop()).thenAnswer((_) async {});
    });

    ProviderContainer makeContainer() => ProviderContainer(
          overrides: [
            generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
        );

    Future<void> generateSession(DictationPracticeNotifier notifier) =>
        notifier.generate(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        );

    test('setSpeed() while idle only updates speedMultiplier, plays nothing, '
        'and does not touch hasPlayedOnce/replayCount', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      await notifier.setSpeed(0.75);

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.hasPlayedOnce, false);
      expect(state.replayCount, 0);
      verifyNever(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
          rate: any(named: 'rate')));
      verifyNever(() => mockTts.stop());
    });

    test('setSpeed() while speaking stops, replays the sentence at the new rate, '
        'and counts as a replay', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);

      final completer = Completer<void>();
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) => completer.future);
      when(() => mockTts.stop()).thenAnswer((_) async {});

      final playFuture = notifier.play(); // starts speaking, hangs on completer
      final speedFuture = notifier.setSpeed(0.75);
      completer.complete(); // let both hung speak() calls resolve
      await playFuture;
      await speedFuture;

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.replayCount, 1);
      expect(state.isSpeaking, false);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1); // the original play(), at the default 1x rate
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.375))
          .called(1); // the setSpeed()-triggered replay, at the new 0.75x rate
    });

    test('setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next play()', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});

      await notifier.setSpeed(1.25); // idle: just stores the choice
      await notifier.play();

      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.625))
          .called(1);
    });
  });

  group('DictationPracticeNotifier disposal', () {
    late MockGenerateDictationItemUseCase mockUseCase;
    late MockTtsService mockTts;
    late DictationItem fixedItem;
    late List<VocabRecord> words;

    setUp(() {
      mockUseCase = MockGenerateDictationItemUseCase();
      mockTts = MockTtsService();
      fixedItem = _item('Hello world.');
      words = [
        VocabRecord(
          id: 'id1',
          headword: 'hello',
          inputType: InputType.word,
          ipa: '',
          meaning: '',
          examples: const [],
          personalNotes: '',
          topicIds: const [],
          targetLanguage: Language.english,
          cefrLevel: CEFRLevel.b1,
          activeContext: AppContext.general,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];
      when(
        () => mockUseCase.execute(
          words: words,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
        ),
      ).thenAnswer((_) async => fixedItem);
      when(() => mockTts.stop()).thenAnswer((_) async {});
    });

    test('disposing the provider (e.g. navigating away mid-playback) stops TTS', () async {
      final container = ProviderContainer(
        overrides: [
          generateDictationItemUseCaseProvider.overrideWithValue(mockUseCase),
          ttsServiceProvider.overrideWithValue(mockTts),
        ],
      );
      await container.read(dictationPracticeNotifierProvider.notifier).generate(
            words: words,
            level: CEFRLevel.b1,
            context: AppContext.general,
            targetLanguage: Language.english,
          );

      container.dispose();

      verify(() => mockTts.stop()).called(1);
    });
  });
}
