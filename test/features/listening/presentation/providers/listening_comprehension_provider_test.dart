import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_listening_passage_use_case.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockGenerateListeningPassageUseCase extends Mock
    implements GenerateListeningPassageUseCase {}

class MockTtsService extends Mock implements TtsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  final fixedPassage = ListeningPassage(
    id: 'p1',
    kind: ListeningKind.conversation,
    turns: const [
      ListeningTurn(speaker: 'A', text: 'Hello, can I help you?'),
      ListeningTurn(speaker: 'B', text: 'Yes, I need a room for tonight.'),
      ListeningTurn(speaker: 'A', text: 'Sure, for how many guests?'),
    ],
    questions: const [
      ListeningQuestion(
          question: 'Q1', options: ['a', 'b', 'c', 'd'], correctIndex: 0),
      ListeningQuestion(
          question: 'Q2', options: ['a', 'b', 'c', 'd'], correctIndex: 1),
      ListeningQuestion(
          question: 'Q3', options: ['a', 'b', 'c', 'd'], correctIndex: 2),
    ],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGenerateListeningPassageUseCase mockUseCase;
  late MockTtsService mockTts;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGenerateListeningPassageUseCase();
    mockTts = MockTtsService();
    when(
      () => mockUseCase.execute(
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fixedPassage);
    when(
      () => mockTts.synthesize(any(), any(),
          voice: any(named: 'voice'), rate: any(named: 'rate')),
    ).thenAnswer((_) async {});
    when(() => mockTts.stop()).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        generateListeningPassageUseCaseProvider.overrideWithValue(mockUseCase),
        ttsServiceProvider.overrideWithValue(mockTts),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() =>
      container.read(listeningComprehensionNotifierProvider.notifier).generate(
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english);

  test('generate() populates state at turn 0 with all answers unselected',
      () async {
    await generateFixed();
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.passage, same(fixedPassage));
    expect(state.currentTurnIndex, 0);
    expect(state.selectedAnswers, [null, null, null]);
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test(
      'playCurrentTurn() speaks the current turn with the correct voice and resets isSpeaking on completion',
      () async {
    await generateFixed();
    await container
        .read(listeningComprehensionNotifierProvider.notifier)
        .playCurrentTurn();
    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
        voice: 'female1', rate: 1.0)).called(1);
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.isSpeaking,
        false); // reset after the awaited synthesize() completes
  });

  test('playCurrentTurn() auto-continues through every turn until the last one',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.playCurrentTurn();

    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
        voice: 'female1', rate: 1.0)).called(1);
    verify(() => mockTts.synthesize(
        'Yes, I need a room for tonight.', Language.english,
        voice: 'female2', rate: 1.0)).called(1);
    verify(() => mockTts.synthesize(
        'Sure, for how many guests?', Language.english,
        voice: 'female1', rate: 1.0)).called(1);
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 2); // last turn
    expect(state.isSpeaking, false);
  });

  test(
      'interrupting playback via stopPlayback() cancels the auto-continue chain',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    final completer = Completer<void>();
    when(() => mockTts.synthesize(any(), any(),
        voice: any(named: 'voice'),
        rate: any(named: 'rate'))).thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn();
    await notifier.stopPlayback(); // supersedes the in-flight turn 0 playback
    completer.complete(); // let the original (now-superseded) speak() resolve
    await playFuture;

    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0); // stopPlayback() doesn't change turns
    verify(() => mockTts.synthesize(any(), any(),
        voice: any(named: 'voice'),
        rate: any(named: 'rate'))).called(1); // no auto-continue
  });

  test('nextTurn() advances currentTurnIndex and stops any playing audio',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.stop()).called(greaterThanOrEqualTo(1));
  });

  test('nextTurn() at the last turn does not go out of bounds', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.nextTurn(); // one extra call past the last index (2)
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 2);
  });

  test('previousTurn() at turn 0 does not go negative', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.previousTurn();
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('replayFromStart() resets currentTurnIndex to 0', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.replayFromStart();
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('selectAnswer() records an answer without marking submitted', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 2);
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers, [2, null, null]);
    expect(state.isSubmitted, false);
  });

  test('canSubmit is true only once all 3 answers are selected', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 1);
    expect(
        container
            .read(listeningComprehensionNotifierProvider)
            .valueOrNull!
            .canSubmit,
        false);
    notifier.selectAnswer(2, 2);
    expect(
        container
            .read(listeningComprehensionNotifierProvider)
            .valueOrNull!
            .canSubmit,
        true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.submit();
    expect(
        container
            .read(listeningComprehensionNotifierProvider)
            .valueOrNull!
            .isSubmitted,
        false);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 0);
    notifier.selectAnswer(2, 0);
    notifier.submit();
    expect(
        container
            .read(listeningComprehensionNotifierProvider)
            .valueOrNull!
            .isSubmitted,
        true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(listeningComprehensionNotifierProvider.notifier).reset();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull,
        isNull);
  });

  test('totalWordsOf sums word counts across all turns', () async {
    await generateFixed();
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    // Turn 0 "Hello, can I help you?" = 5 words; turn 1 "Yes, I need a room for
    // tonight." = 7 words; turn 2 "Sure, for how many guests?" = 5 words.
    expect(totalWordsOf(state.passage), 17);
  });

  test(
      'seekToWord within the first turn speaks from that word to the end of the turn',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(2); // turn 0, word index 2: "I"

    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
    verify(() => mockTts.synthesize('I help you?', Language.english,
        voice: 'female1', rate: 1.0)).called(1);
  });

  test(
      "seekToWord crossing into a later turn switches currentTurnIndex and uses that turn's voice",
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(
        5); // turn 0 has 5 words (indices 0-4), so this is turn 1 word 0

    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.synthesize(
        'Yes, I need a room for tonight.', Language.english,
        voice: 'female2', rate: 1.0)).called(1);
  });

  test('seekToWord with an out-of-range index is a no-op', () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(-1);
    await notifier.seekToWord(17); // total is 17, valid indices are 0-16

    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
    verifyNever(() => mockTts.synthesize(any(), any(),
        voice: any(named: 'voice'), rate: any(named: 'rate')));
  });

  test('setSpeed() while idle only updates speedMultiplier and plays nothing',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(0.75);

    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
    expect(state.isSpeaking, false);
    verifyNever(() => mockTts.synthesize(any(), any(),
        voice: any(named: 'voice'), rate: any(named: 'rate')));
    verifyNever(() => mockTts.stop());
  });

  test(
      'setSpeed() while speaking stops the current turn and replays it at the new rate',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    final completer = Completer<void>();
    when(() => mockTts.synthesize(any(), any(),
        voice: any(named: 'voice'),
        rate: any(named: 'rate'))).thenAnswer((_) => completer.future);

    final playFuture =
        notifier.playCurrentTurn(); // hangs on completer for turn 0
    final speedFuture = notifier.setSpeed(0.75);
    completer.complete(); // let every hung/future speak() call resolve
    await playFuture;
    await speedFuture;

    verify(() => mockTts.stop()).called(1);
    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
            voice: 'female1', rate: 0.75))
        .called(1); // the setSpeed()-triggered restart, at the new 0.75x rate
    final state =
        container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
  });

  test(
      'setSpeed() passes 0.75x/1x/1.25x straight through as the playback rate for the next playCurrentTurn()',
      () async {
    await generateFixed();
    final notifier =
        container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(1.25); // idle: just stores the choice
    await notifier.playCurrentTurn();

    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
        voice: 'female1', rate: 1.25)).called(1);
  });

  test('disposing the provider (e.g. navigating away mid-playback) stops TTS',
      () async {
    final localContainer = ProviderContainer(
      overrides: [
        generateListeningPassageUseCaseProvider.overrideWithValue(mockUseCase),
        ttsServiceProvider.overrideWithValue(mockTts),
      ],
    );
    await localContainer
        .read(listeningComprehensionNotifierProvider.notifier)
        .generate(
            level: CEFRLevel.b1,
            context: AppContext.general,
            targetLanguage: Language.english);

    localContainer.dispose();

    verify(() => mockTts.stop()).called(1);
  });

  group('loadSaved / generationFilters', () {
    const filters = {
      'level': 'b1',
      'context': 'general',
    };

    test(
        'loadSaved yields a not-started state at turn 0 carrying the passage, '
        'empty answers, and reusedFromId + generationFilters', () {
      container.read(listeningComprehensionNotifierProvider.notifier).loadSaved(
          fixedPassage,
          savedId: 'saved-c',
          generationFilters: filters);

      final state =
          container.read(listeningComprehensionNotifierProvider).valueOrNull!;
      expect(state.passage, same(fixedPassage));
      expect(state.currentTurnIndex, 0);
      expect(state.isSpeaking, false);
      expect(state.playToken, 0);
      expect(state.selectedAnswers, [null, null, null]);
      expect(state.isSubmitted, false);
      expect(state.canSubmit, false);
      expect(state.reusedFromId, 'saved-c');
      expect(state.generationFilters, filters);
    });

    test('loadSaved leaves reusedFromId + generationFilters null when omitted',
        () {
      container
          .read(listeningComprehensionNotifierProvider.notifier)
          .loadSaved(fixedPassage);
      final state =
          container.read(listeningComprehensionNotifierProvider).valueOrNull!;
      expect(state.reusedFromId, isNull);
      expect(state.generationFilters, isNull);
    });

    test('generate(generationFilters:) carries the map onto the state',
        () async {
      await container
          .read(listeningComprehensionNotifierProvider.notifier)
          .generate(
            level: CEFRLevel.b1,
            context: AppContext.general,
            targetLanguage: Language.english,
            generationFilters: filters,
          );
      final state =
          container.read(listeningComprehensionNotifierProvider).valueOrNull!;
      expect(state.generationFilters, filters);
      expect(state.reusedFromId, isNull);
    });
  });
}
