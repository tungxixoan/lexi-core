import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/find_known_headwords_use_case.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

class MockFindKnownHeadwordsUseCase extends Mock
    implements FindKnownHeadwordsUseCase {}

class MockGenerateWordSuggestionsUseCase extends Mock
    implements GenerateWordSuggestionsUseCase {}

VocabRecord _record(String headword) => VocabRecord(
      id: headword,
      headword: headword,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $headword',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late MockFindKnownHeadwordsUseCase mockFindKnown;
  late MockGenerateWordSuggestionsUseCase mockGenerate;
  late GetVocabSuggestionsForTextUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  setUp(() {
    mockFindKnown = MockFindKnownHeadwordsUseCase();
    mockGenerate = MockGenerateWordSuggestionsUseCase();
    useCase = GetVocabSuggestionsForTextUseCase(mockFindKnown, mockGenerate);
  });

  test(
      'finds known headwords in the text first, then excludes them when generating suggestions',
      () async {
    when(() => mockFindKnown.execute(
          text: any(named: 'text'),
          language: any(named: 'language'),
        )).thenAnswer((_) async => [_record('cat'), _record('dog')]);
    const expected = WordRadarAiResult(translation: '', suggestions: []);
    when(() => mockGenerate.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
          knownHeadwords: any(named: 'knownHeadwords'),
        )).thenAnswer((_) async => expected);

    final result = await useCase.execute(
      text: 'The cat chased the dog.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.b1,
    );

    expect(result, same(expected));
    verify(() => mockFindKnown.execute(
          text: 'The cat chased the dog.',
          language: Language.english,
        )).called(1);
    verify(() => mockGenerate.execute(
          text: 'The cat chased the dog.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
          knownHeadwords: ['cat', 'dog'],
        )).called(1);
  });
}
