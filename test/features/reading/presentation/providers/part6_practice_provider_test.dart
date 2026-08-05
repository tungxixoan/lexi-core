import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part6_set_use_case.dart';
import 'package:lexi_core/features/reading/presentation/providers/part6_practice_provider.dart';

class MockGeneratePart6SetUseCase extends Mock implements GeneratePart6SetUseCase {}

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i (1)___ (2)___ (3)___ (4)___.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  final fixedSet = Part6Set(
    id: 'p1',
    passages: List.generate(3, _passage),
    volumes: const {EconomyVolume.vol4},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  late MockGeneratePart6SetUseCase mockUseCase;
  late ProviderContainer container;

  setUp(() {
    mockUseCase = MockGeneratePart6SetUseCase();
    when(
      () => mockUseCase.execute(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fixedSet);

    container = ProviderContainer(
      overrides: [generatePart6SetUseCaseProvider.overrideWithValue(mockUseCase)],
    );
    addTearDown(container.dispose);
  });

  Future<void> generateFixed() => container.read(part6PracticeNotifierProvider.notifier).generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      );

  test('generate() populates state with all 12 answers unselected', () async {
    await generateFixed();
    final state = container.read(part6PracticeNotifierProvider).valueOrNull!;
    expect(state.set, same(fixedSet));
    expect(state.selectedAnswers, List<int?>.filled(12, null));
    expect(state.isSubmitted, false);
    expect(state.canSubmit, false);
  });

  test('flatIndex maps (passageIndex, questionIndex) to passageIndex*4 + questionIndex', () {
    expect(Part6SessionState.flatIndex(0, 0), 0);
    expect(Part6SessionState.flatIndex(0, 3), 3);
    expect(Part6SessionState.flatIndex(1, 0), 4);
    expect(Part6SessionState.flatIndex(2, 3), 11);
  });

  test('selectAnswer() records an answer at the correct flat index', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    notifier.selectAnswer(1, 2, 3); // passage 1, question 2 -> flat index 6
    final state = container.read(part6PracticeNotifierProvider).valueOrNull!;
    expect(state.selectedAnswers[6], 3);
    expect(state.selectedAnswers.where((a) => a != null).length, 1);
  });

  test('canSubmit is true only once all 12 answers are selected', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    for (var p = 0; p < 3; p++) {
      for (var q = 0; q < 4; q++) {
        if (p == 2 && q == 3) continue; // leave the last one unanswered
        notifier.selectAnswer(p, q, 0);
      }
    }
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.canSubmit, false);
    notifier.selectAnswer(2, 3, 0);
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.canSubmit, true);
  });

  test('submit() is a no-op until canSubmit is true', () async {
    await generateFixed();
    final notifier = container.read(part6PracticeNotifierProvider.notifier);
    notifier.submit();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.isSubmitted, false);
    for (var p = 0; p < 3; p++) {
      for (var q = 0; q < 4; q++) {
        notifier.selectAnswer(p, q, 0);
      }
    }
    notifier.submit();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull!.isSubmitted, true);
  });

  test('reset() returns state to null', () async {
    await generateFixed();
    container.read(part6PracticeNotifierProvider.notifier).reset();
    expect(container.read(part6PracticeNotifierProvider).valueOrNull, isNull);
  });

  test('Part6SessionResult.correctCount counts matching answers across all passages', () {
    // Passage 0's correctIndexes are [0,1,2,3]; passage 1's are [0,1,2,3]; passage 2's are [0,1,2,3].
    // Answer everything with 0: passage 0 gets 1 right (q0), passage 1 gets 1 right (q0),
    // passage 2 gets 1 right (q0) -> 3 total.
    final result = Part6SessionResult(
      set: fixedSet,
      selectedAnswers: List<int?>.filled(12, 0),
    );
    expect(result.correctCount, 3);
  });
}
