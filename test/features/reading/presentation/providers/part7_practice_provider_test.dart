import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part7_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';

class MockGeneratePart7SetUseCase extends Mock implements GeneratePart7SetUseCase {}

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'E$i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'DQ$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'DE$q',
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  // Group sizes are [3, 4, 5] -> 12 total questions, deliberately non-uniform
  // to prove flatIndex is computed dynamically, not via a fixed multiplier.
  final fixedSet = Part7Set(
    id: 'p1',
    passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
    volumes: const {EconomyVolume.vol4},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart7SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart7SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [generatePart7SetUseCaseProvider.overrideWithValue(mockUseCase)],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container.read(part7PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      );

  test('generate() populates state with all 12 answers unselected (3+4+5)', () async {
    await generateFixed();
    final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, List<int?>.filled(12, null));
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('flatIndex sums each preceding group\'s actual question count, not a fixed multiplier', () {
    final groups = fixedSet.passageGroups;
    expect(Part7SessionState.flatIndex(groups, 0, 0), 0);
    expect(Part7SessionState.flatIndex(groups, 0, 2), 2);
    expect(Part7SessionState.flatIndex(groups, 1, 0), 3); // group 0 has 3 questions, not 4
    expect(Part7SessionState.flatIndex(groups, 1, 3), 6);
    expect(Part7SessionState.flatIndex(groups, 2, 0), 7); // groups 0+1 = 3+4 = 7
    expect(Part7SessionState.flatIndex(groups, 2, 4), 11);
  });

  test('selectAnswer() records an answer at the correct dynamically-computed flat index', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    notifier.selectAnswer(1, 2, 3); // group 1 (offset 3), question 2 -> flat index 5
    final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers[5], 3);
    expect(state.selectedAnswers.where((a) => a != null).length, 1);
  });

  test('canSubmit is true only once all 12 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    final groups = fixedSet.passageGroups;
    for (var g = 0; g < groups.length; g++) {
      for (var q = 0; q < groups[g].questions.length; q++) {
        if (g == 2 && q == 4) continue; // leave the very last one unanswered
        notifier.selectAnswer(g, q, 0);
      }
    }
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 4, 0);
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part7PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.isSubmitted, false);
    final groups = fixedSet.passageGroups;
    for (var g = 0; g < groups.length; g++) {
      for (var q = 0; q < groups[g].questions.length; q++) {
        notifier.selectAnswer(g, q, 0);
      }
    }
    notifier.submit();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part7PracticeNotifierProvider.notifier).reset();
    expect(container.read(part7PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part7SessionResult.correctCount counts matching answers across non-uniform groups', () {
    // Every group's correctIndexes cycle 0,1,2,3,0(,1). Answer everything with 0:
    // group0 (3 Q) gets 1 right (q0); group1 (4 Q) gets 1 right (q0); group2 (5 Q)
    // gets 2 right (q0 and q4, since correctIndex cycles back to 0 at q4) -> 4 total.
    final result = Part7SessionResult(
      set: fixedSet,
      selectedAnswers: List<int?>.filled(12, 0),
    );
    expect(result.correctCount, 4);
  });

  group('loadSaved / generationFilters', () {
    const filters = {
      'topicIds': ['t1'],
      'targetCefr': 'b1',
      'volumes': ['vol4'],
    };

    test(
        'loadSaved yields a not-started state carrying the set, empty answers '
        'sized to the dynamic question count, and reusedFromId + generationFilters',
        () {
      container
          .read(part7PracticeNotifierProvider.notifier)
          .loadSaved(fixedSet, savedId: 'saved-7', generationFilters: filters);

      final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
      expect(state.set, same(fixedSet));
      expect(state.selectedAnswers, List<int?>.filled(12, null)); // 3+4+5
      expect(state.isSubmitted, false);
      expect(state.canSubmit, false);
      expect(state.reusedFromId, 'saved-7');
      expect(state.generationFilters, filters);
    });

    test('loadSaved leaves reusedFromId + generationFilters null when omitted', () {
      container.read(part7PracticeNotifierProvider.notifier).loadSaved(fixedSet);
      final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
      expect(state.reusedFromId, isNull);
      expect(state.generationFilters, isNull);
    });

    test('generate(generationFilters:) carries the map onto the state', () async {
      await container.read(part7PracticeNotifierProvider.notifier).generate(
            context: AppContext.general,
            targetLanguage: Language.english,
            volumes: const {EconomyVolume.vol4},
            generationFilters: filters,
          );
      final state = container.read(part7PracticeNotifierProvider).valueOrNull!;
      expect(state.generationFilters, filters);
      expect(state.reusedFromId, isNull);
    });
  });
}
