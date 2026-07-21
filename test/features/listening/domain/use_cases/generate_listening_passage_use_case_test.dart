import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/data/sources/listening_passage_source.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_listening_passage_use_case.dart';

class MockListeningPassageSource extends Mock implements ListeningPassageSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  late MockListeningPassageSource mockSource;
  late GenerateListeningPassageUseCase useCase;

  setUp(() {
    mockSource = MockListeningPassageSource();
    useCase = GenerateListeningPassageUseCase(mockSource);
  });

  final fakePassage = ListeningPassage(
    id: 'fake-id',
    kind: ListeningKind.talk,
    turns: const [],
    questions: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the passage', () async {
    when(
      () => mockSource.generate(
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakePassage);

    final result = await useCase.execute(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakePassage));
    verify(
      () => mockSource.generate(
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      ),
    ).called(1);
  });
}
