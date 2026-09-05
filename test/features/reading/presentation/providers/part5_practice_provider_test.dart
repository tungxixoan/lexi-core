import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part5_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part5_practice_provider.dart';

class MockGeneratePart5SetUseCase extends Mock
    implements GeneratePart5SetUseCase {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  final fixedSet = Part5Set(
    id: 'p1',
    questions: List.generate(
      3,
      (i) => Part5Question(
        sentenceWithBlank: 'Sentence $i ___.',
        options: const ['a', 'b', 'c', 'd'],
        correctIndex: i % 4,
        explanation: 'Explanation $i',
      ),
    ),
    volumes: const {EconomyVolume.vol3},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart5SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart5SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [
        generatePart5SetUseCaseProvider.overrideWithValue(mockUseCase)
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() =>
      container.read(part5PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      );

  test('generate() populates state with all answers unselected', () async {
    await generateFixed();
    final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, [null, null, null]);
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('selectAnswer() records an answer without marking submitted', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.selectAnswer(0, 2);
    final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers, [2, null, null]);
    expect(state.isSubmitted, false);
  });

  test('canSubmit is true only once every answer is selected', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 1);
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.canSubmit,
        false);
    notifier.selectAnswer(2, 2);
    expect(container.read(part5PracticeNotifierProvider).valueOrNull!.canSubmit,
        true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part5PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(
        container.read(part5PracticeNotifierProvider).valueOrNull!.isSubmitted,
        false);
    notifier.selectAnswer(0, 0);
    notifier.selectAnswer(1, 0);
    notifier.selectAnswer(2, 0);
    notifier.submit();
    expect(
        container.read(part5PracticeNotifierProvider).valueOrNull!.isSubmitted,
        true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part5PracticeNotifierProvider.notifier).reset();
    expect(container.read(part5PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part5SessionResult.correctCount counts matching answers', () {
    final result = Part5SessionResult(
      set: fixedSet,
      selectedAnswers: const [
        0,
        1,
        3
      ], // question 0 & 1's correctIndex are 0 & 1; question 2's is 2
    );
    expect(result.correctCount, 2);
  });

  group('loadSaved / generationFilters', () {
    const filters = {
      'topicIds': ['t1'],
      'targetCefr': 'b1',
      'volumes': ['vol3'],
    };

    test(
        'loadSaved yields a not-started state carrying the set, index 0, empty '
        'answers, and reusedFromId + generationFilters', () {
      container
          .read(part5PracticeNotifierProvider.notifier)
          .loadSaved(fixedSet, savedId: 'saved-1', generationFilters: filters);

      final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
      expect(state.set, same(fixedSet));
      expect(state.selectedAnswers, [null, null, null]);
      expect(state.isSubmitted, false);
      expect(state.canSubmit, false);
      expect(state.reusedFromId, 'saved-1');
      expect(state.generationFilters, filters);
    });

    test('loadSaved leaves reusedFromId + generationFilters null when omitted',
        () {
      container
          .read(part5PracticeNotifierProvider.notifier)
          .loadSaved(fixedSet);
      final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
      expect(state.reusedFromId, isNull);
      expect(state.generationFilters, isNull);
    });

    test('generate(generationFilters:) carries the map onto the state',
        () async {
      await container.read(part5PracticeNotifierProvider.notifier).generate(
            context: AppContext.general,
            targetLanguage: Language.english,
            volumes: const {EconomyVolume.vol3},
            generationFilters: filters,
          );
      final state = container.read(part5PracticeNotifierProvider).valueOrNull!;
      expect(state.generationFilters, filters);
      expect(state.reusedFromId, isNull);
    });
  });
}
