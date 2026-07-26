import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/data/sources/word_radar_source.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/generate_word_suggestions_use_case.dart';

class MockWordRadarSource extends Mock implements WordRadarSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.a1);
  });

  late MockWordRadarSource mockSource;
  late GenerateWordSuggestionsUseCase useCase;

  setUp(() {
    mockSource = MockWordRadarSource();
    useCase = GenerateWordSuggestionsUseCase(mockSource);
  });

  const fakeResult = WordRadarAiResult(
    translation: 'Điện thoại thông minh có mặt khắp nơi.',
    suggestions: [
      WordPhraseResult(
        headword: 'ubiquitous',
        inputType: InputType.word,
        ipa: '/juːˈbɪkwɪtəs/',
        meaning: 'có mặt khắp nơi',
        examples: [],
        suggestedTopics: [],
        cefrLevel: CEFRLevel.c1,
      ),
    ],
  );

  test('delegates to source.scan() and returns its result', () async {
    when(
      () => mockSource.scan(
        text: any(named: 'text'),
        targetLanguage: any(named: 'targetLanguage'),
        targetCefrLevel: any(named: 'targetCefrLevel'),
        knownHeadwords: any(named: 'knownHeadwords'),
      ),
    ).thenAnswer((_) async => fakeResult);

    final result = await useCase.execute(
      text: 'Smartphones are everywhere now.',
      targetLanguage: Language.english,
      targetCefrLevel: CEFRLevel.c1,
      knownHeadwords: const ['phone'],
    );

    expect(result, same(fakeResult));
    verify(
      () => mockSource.scan(
        text: 'Smartphones are everywhere now.',
        targetLanguage: Language.english,
        targetCefrLevel: CEFRLevel.c1,
        knownHeadwords: const ['phone'],
      ),
    ).called(1);
  });
}
