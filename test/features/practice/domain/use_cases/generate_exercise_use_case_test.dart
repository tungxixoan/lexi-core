import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/data/sources/exercise_generator_source.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/use_cases/generate_exercise_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

class MockExerciseGeneratorSource extends Mock implements ExerciseGeneratorSource {}

void main() {
  late MockExerciseGeneratorSource mockSource;
  late GenerateExerciseUseCase useCase;

  setUpAll(() {
    registerFallbackValue(VocabRecord(
      id: 'fallback',
      headword: 'fallback',
      inputType: InputType.word,
      ipa: '',
      meaning: '',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.a1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ));
  });

  final testRecord = VocabRecord(
    id: 'r1',
    headword: 'ephemeral',
    inputType: InputType.word,
    ipa: '/ɪˈfɛm.ər.əl/',
    meaning: 'lasting a very short time',
    examples: const ['ephemeral beauty'],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.b2,
    activeContext: AppContext.general,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() {
    mockSource = MockExerciseGeneratorSource();
    useCase = GenerateExerciseUseCase(mockSource);
  });

  group('GenerateExerciseUseCase', () {
    test('returns FlashcardExercise immediately when aiEnabled=false', () async {
      final result = await useCase.execute(testRecord, aiEnabled: false);
      expect(result, isA<FlashcardExercise>());
      verifyNever(() => mockSource.generate(any()));
    });

    test('calls source.generate() when aiEnabled=true', () async {
      final expected = MultipleChoiceExercise(
        vocabRecord: testRecord,
        question: 'What does ephemeral mean?',
        options: const ['short-lived', 'beautiful', 'ancient', 'massive'],
        correctIndex: 0,
      );
      when(() => mockSource.generate(any())).thenAnswer((_) async => expected);

      final result = await useCase.execute(testRecord, aiEnabled: true);
      expect(result, isA<MultipleChoiceExercise>());
      verify(() => mockSource.generate(any())).called(1);
    });

    test('falls back to FlashcardExercise if source throws', () async {
      when(() => mockSource.generate(any())).thenThrow(Exception('network error'));

      final result = await useCase.execute(testRecord, aiEnabled: true);
      expect(result, isA<FlashcardExercise>());
      expect((result as FlashcardExercise).vocabRecord.headword, 'ephemeral');
    });
  });
}
