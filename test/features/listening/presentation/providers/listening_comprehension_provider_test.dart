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
      ListeningQuestion(question: 'Q1', options: ['a', 'b', 'c', 'd'], correctIndex: 0),
      ListeningQuestion(question: 'Q2', options: ['a', 'b', 'c', 'd'], correctIndex: 1),
      ListeningQuestion(question: 'Q3', options: ['a', 'b', 'c', 'd'], correctIndex: 2),
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
      () => mockTts.speak(any(), any(), pitch: any(named: 'pitch')),
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

  Future<void> generateFixed() => container
      .read(listeningComprehensionNotifierProvider.notifier)
      .generate(level: CEFRLevel.b1, context: AppContext.general, targetLanguage: Language.english);

  test('generate() populates state at turn 0 with all answers unselected', () async {
    await generateFixed();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.passage, same(fixedPassage));
    expect(state.currentTurnIndex, 0);
    expect(state.selectedAnswers, [null, null, null]);
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('playCurrentTurn() speaks the current turn with the correct pitch and resets isSpeaking on completion', () async {
    await generateFixed();
    await container.read(listeningComprehensionNotifierProvider.notifier).playCurrentTurn();
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0)).called(1);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.isSpeaking, false); // reset after the awaited speak() completes
  });

  test('nextTurn() advances currentTurnIndex and stops any playing audio', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.stop()).called(greaterThanOrEqualTo(1));
  });

  test('nextTurn() at the last turn does not go out of bounds', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.nextTurn(); // one extra call past the last index (2)
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 2);
  });

  test('previousTurn() at turn 0 does not go negative', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.previousTurn();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('replayFromStart() resets currentTurnIndex to 0', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.nextTurn();
    notifier.nextTurn();
    notifier.replayFromStart();
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0);
  });

  test('selectAnswer() records an answer without marking submitted', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 2);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers, [2, null, null]);
    expect(state.isSubmitted, false);
  });

  test('canSubmit is true only once all 3 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 1);
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 2);
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.isSubmitted, false);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 0);
    notifier.selectAnswer(2, 0);
    notifier.submit();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(listeningComprehensionNotifierProvider.notifier).reset();
    expect(container.read(listeningComprehensionNotifierProvider).valueOrNull, isNull);
  });
}
