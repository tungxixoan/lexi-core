import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
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

      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
          .thenAnswer((_) async {});
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
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
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
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage))
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
}
