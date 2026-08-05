import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part5_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part5_set_use_case.dart';

class MockPart5Source extends Mock implements Part5Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  late MockPart5Source mockSource;
  late GeneratePart5SetUseCase useCase;

  setUp(() {
    mockSource = MockPart5Source();
    useCase = GeneratePart5SetUseCase(mockSource);
  });

  final fakeSet = Part5Set(
    id: 'fake-id',
    questions: const [],
    volumes: const {EconomyVolume.vol3},
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the set', () async {
    when(
      () => mockSource.generate(
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
        volumes: any(named: 'volumes'),
      ),
    ).thenAnswer((_) async => fakeSet);

    final result = await useCase.execute(
      context: AppContext.general,
      targetLanguage: Language.english,
      volumes: const {EconomyVolume.vol3},
    );
    expect(result, same(fakeSet));
    verify(
      () => mockSource.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol3},
      ),
    ).called(1);
  });
}
