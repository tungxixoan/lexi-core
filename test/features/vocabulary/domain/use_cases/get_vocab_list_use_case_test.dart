import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockVocabRepository extends Mock implements VocabRepository {}

VocabRecord _makeRecord(String id, CEFRLevel level) => VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: [],
      personalNotes: '',
      topicIds: [],
      targetLanguage: Language.english,
      cefrLevel: level,
      activeContext: AppContext.general,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

void main() {
  late MockVocabRepository repo;
  late GetVocabListUseCase useCase;

  setUp(() {
    repo = MockVocabRepository();
    useCase = GetVocabListUseCase(repo);
  });

  test('execute() with no maxCefrLevel passes null to repo', () async {
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => []);

    await useCase.execute();

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: null,
        )).called(1);
  });

  test('execute() passes maxCefrLevel to repo and returns its result', () async {
    final records = [_makeRecord('word1', CEFRLevel.b1)];
    when(() => repo.getAll(
          topicId: any(named: 'topicId'),
          inputType: any(named: 'inputType'),
          language: any(named: 'language'),
          maxCefrLevel: any(named: 'maxCefrLevel'),
        )).thenAnswer((_) async => records);

    final result = await useCase.execute(maxCefrLevel: CEFRLevel.b2);

    verify(() => repo.getAll(
          topicId: null,
          inputType: null,
          language: null,
          maxCefrLevel: CEFRLevel.b2,
        )).called(1);
    expect(result, records);
  });

  test('execute with dueOnly=true passes dueOnly to repository', () async {
    when(() => repo.getAll(dueOnly: true)).thenAnswer((_) async => []);
    await useCase.execute(dueOnly: true);
    verify(() => repo.getAll(dueOnly: true)).called(1);
  });
}
