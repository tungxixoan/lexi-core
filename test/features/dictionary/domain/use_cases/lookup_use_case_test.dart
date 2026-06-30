import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/repositories/dictionary_repository.dart';
import 'package:lexi_core/features/dictionary/domain/use_cases/lookup_use_case.dart';

import 'lookup_use_case_test.mocks.dart';

@GenerateMocks([DictionaryRepository])
void main() {
  late MockDictionaryRepository mockRepo;
  late LookupUseCase useCase;

  const fakeResult = WordPhraseResult(
    headword: 'follow',
    inputType: InputType.word,
    ipa: '/ˈfɒl.oʊ/',
    meaning: 'Đi theo.',
    examples: [],
    suggestedTopics: [],
  );

  setUp(() {
    provideDummy<LookupResult>(fakeResult);
    mockRepo = MockDictionaryRepository();
    useCase = LookupUseCase(mockRepo);
  });

  test('trims whitespace and delegates to repository', () async {
    when(mockRepo.lookup(
      query: anyNamed('query'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
      aiEnabled: anyNamed('aiEnabled'),
    )).thenAnswer((_) async => fakeResult);

    await useCase.execute(
      query: '  follow  ',
      targetLanguage: Language.english,
      context: AppContext.general,
      aiEnabled: true,
    );

    verify(mockRepo.lookup(
      query: 'follow',
      targetLanguage: Language.english,
      context: AppContext.general,
      aiEnabled: true,
    )).called(1);
  });

  test('throws DictionaryException for blank query', () {
    expect(
      () => useCase.execute(
        query: '   ',
        targetLanguage: Language.english,
        context: AppContext.general,
        aiEnabled: true,
      ),
      throwsA(
        isA<DictionaryException>().having(
          (e) => e.message,
          'message',
          contains('empty'),
        ),
      ),
    );
    verifyNever(mockRepo.lookup(
      query: anyNamed('query'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
      aiEnabled: anyNamed('aiEnabled'),
    ));
  });
}
