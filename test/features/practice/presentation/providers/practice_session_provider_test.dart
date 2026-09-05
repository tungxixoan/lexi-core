import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/data/sources/exercise_generator_source.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/domain/use_cases/generate_exercise_use_case.dart';
import 'package:lexi_core/features/practice/presentation/providers/practice_session_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

class MockExerciseGeneratorSource extends Mock
    implements ExerciseGeneratorSource {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

UserSettingsState _settings({required bool aiAvailable}) =>
    UserSettingsState.defaults.copyWith(providerConfigs: {
      AiProvider.gemini: ProviderConfig(
        apiKeyCiphertext: aiAvailable ? 'ck' : null,
        model: 'gemini-2.5-flash',
      ),
    });

VocabRecord _record({int sm2Repetitions = 1}) => VocabRecord(
      id: 'id1',
      headword: 'word',
      inputType: InputType.word,
      ipa: '',
      meaning: 'nghĩa',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      sm2Repetitions: sm2Repetitions,
    );

ProviderContainer _container({
  required bool aiAvailable,
  required MockExerciseGeneratorSource source,
}) =>
    ProviderContainer(overrides: [
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(_settings(aiAvailable: aiAvailable)),
      ),
      generateExerciseUseCaseProvider
          .overrideWithValue(GenerateExerciseUseCase(source)),
    ]);

void main() {
  setUpAll(() => registerFallbackValue(_record()));

  test('aiRatio 0 never calls the AI source even when AI is available',
      () async {
    final source = MockExerciseGeneratorSource();
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 3)], aiRatio: 0),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.aiRatio, 0);
    expect(state.exercises.single, isA<FlashcardExercise>());
    verifyNever(() => source.generate(any()));
  });

  test('aiRatio 1 calls the AI source for a reviewed word when AI is available',
      () async {
    final source = MockExerciseGeneratorSource();
    when(() => source.generate(any())).thenAnswer((_) async =>
        MultipleChoiceExercise(
          vocabRecord: _record(),
          question: 'q',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
        ));
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 3)], aiRatio: 1),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.aiRatio, 1);
    expect(state.exercises.single, isA<MultipleChoiceExercise>());
    verify(() => source.generate(any())).called(1);
  });

  test('a never-reviewed word stays flashcard even at aiRatio 1', () async {
    final source = MockExerciseGeneratorSource();
    final container = _container(aiAvailable: true, source: source);
    addTearDown(container.dispose);
    final notifier = container.read(practiceSessionNotifierProvider.notifier);

    await notifier.startSession(
      SessionConfig(words: [_record(sm2Repetitions: 0)], aiRatio: 1),
    );

    final state = container.read(practiceSessionNotifierProvider).value!;
    expect(state.exercises.single, isA<FlashcardExercise>());
    verifyNever(() => source.generate(any()));
  });
}
