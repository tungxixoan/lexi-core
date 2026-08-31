import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/data/repositories/dictionary_repository_impl.dart';
import 'package:lexi_core/features/dictionary/data/sources/free_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/data/sources/gemini_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/repositories/dictionary_repository.dart';

import 'dictionary_repository_impl_test.mocks.dart';

@GenerateMocks([GeminiDictionarySource, FreeDictionarySource])
void main() {
  late MockGeminiDictionarySource mockGemini;
  late MockFreeDictionarySource mockFree;
  late DictionaryRepositoryImpl repo;

  const wordResult = WordPhraseResult(
    headword: 'follow',
    inputType: InputType.word,
    ipa: '/ˈfɒl.oʊ/',
    meaning: 'Đi theo sau.',
    examples: ['She followed him.'],
    suggestedTopics: ['Daily Life'],
  );

  setUp(() {
    mockGemini = MockGeminiDictionarySource();
    mockFree = MockFreeDictionarySource();
    repo = DictionaryRepositoryImpl(
      geminiSource: mockGemini,
      freeDictionarySource: mockFree,
    );
    provideDummy<LookupResult>(const WordPhraseResult(
      headword: '',
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: [],
      suggestedTopics: [],
    ));
    provideDummy<WordPhraseResult>(const WordPhraseResult(
      headword: '',
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: [],
      suggestedTopics: [],
    ));
  });

  test('routes to Gemini when AI is enabled', () async {
    when(mockGemini.lookup(
      query: anyNamed('query'),
      inputType: anyNamed('inputType'),
      targetLanguage: anyNamed('targetLanguage'),
    )).thenAnswer((_) async => wordResult);

    await repo.lookup(
      query: 'follow',
      targetLanguage: Language.english,
      aiEnabled: true,
    );

    verify(mockGemini.lookup(
      query: 'follow',
      inputType: InputType.word,
      targetLanguage: Language.english,
    )).called(1);
    verifyNever(mockFree.lookup(any));
  });

  test('routes to FreeDictionary when AI disabled + English word', () async {
    when(mockFree.lookup(any)).thenAnswer((_) async => wordResult);

    await repo.lookup(
      query: 'follow',
      targetLanguage: Language.english,
      aiEnabled: false,
    );

    verify(mockFree.lookup('follow')).called(1);
    verifyNever(mockGemini.lookup(
      query: anyNamed('query'),
      inputType: anyNamed('inputType'),
      targetLanguage: anyNamed('targetLanguage'),
    ));
  });

  test('throws DictionaryException: AI disabled + non-English language', () {
    expect(
      () => repo.lookup(
        query: 'follow',
        targetLanguage: Language.korean,
        aiEnabled: false,
      ),
      throwsA(
        isA<DictionaryException>().having(
          (e) => e.message,
          'message',
          contains('AI must be enabled'),
        ),
      ),
    );
  });

  test('throws DictionaryException: AI disabled + sentence input', () {
    expect(
      () => repo.lookup(
        query: 'Can you follow up with me today',
        targetLanguage: Language.english,
        aiEnabled: false,
      ),
      throwsA(isA<DictionaryException>()),
    );
  });
}
