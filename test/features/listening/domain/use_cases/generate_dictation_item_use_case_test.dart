import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/listening/data/sources/dictation_source.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_dictation_item_use_case.dart';

class MockDictationSource extends Mock implements DictationSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  late MockDictationSource mockSource;
  late GenerateDictationItemUseCase useCase;

  setUp(() {
    mockSource = MockDictationSource();
    useCase = GenerateDictationItemUseCase(mockSource);
  });

  final words = List.generate(
    2,
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

  final fakeItem = DictationItem(
    id: 'fake-id',
    target: 'Hello world.',
    vietnamese: 'Xin chào thế giới.',
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the item', () async {
    when(
      () => mockSource.generate(
        words: any(named: 'words'),
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakeItem);

    final result = await useCase.execute(
      words: words,
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakeItem));
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
