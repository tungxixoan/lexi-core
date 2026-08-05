import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/data/sources/part6_source.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_part6_set_use_case.dart';

class MockPart6Source extends Mock implements Part6Source {}

void main() {
  setUpAll(() {
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
    registerFallbackValue(<EconomyVolume>{});
  });

  late MockPart6Source mockSource;
  late GeneratePart6SetUseCase useCase;

  setUp(() {
    mockSource = MockPart6Source();
    useCase = GeneratePart6SetUseCase(mockSource);
  });

  final fakeSet = Part6Set(
    id: 'fake-id',
    passages: const [],
    volumes: const {EconomyVolume.vol4},
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
      volumes: const {EconomyVolume.vol4},
    );
    expect(result, same(fakeSet));
    verify(
      () => mockSource.generate(
        context: AppContext.general,
        targetLanguage: Language.english,
        volumes: const {EconomyVolume.vol4},
      ),
    ).called(1);
  });
}
