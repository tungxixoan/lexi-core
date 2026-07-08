import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/reading/data/sources/reading_passage_source.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/domain/use_cases/generate_reading_passage_use_case.dart';

class MockReadingPassageSource extends Mock implements ReadingPassageSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  late MockReadingPassageSource mockSource;
  late GenerateReadingPassageUseCase useCase;

  setUp(() {
    mockSource = MockReadingPassageSource();
    useCase = GenerateReadingPassageUseCase(mockSource);
  });

  final words = List.generate(
    5,
    (i) => VocabRecord(
      id: 'id$i',
      headword: 'word$i',
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  final fakePassage = ReadingPassage(
    id: 'fake-id',
    sentences: const [],
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the passage', () async {
    when(
      () => mockSource.generate(
        words: any(named: 'words'),
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakePassage);

    final result = await useCase.execute(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakePassage));
    verify(
      () => mockSource.generate(
        words: words,
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      ),
    ).called(1);
  });
}
