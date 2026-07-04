# Plan 3 — Task 03: ExerciseGeneratorSource + GenerateExerciseUseCase + Tests

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (Exercise sealed class), Plan 1 (google_generative_ai already in pubspec.yaml)

## Global Constraints
(see `plan3-global-constraints.md`)
- Tests use `mocktail` — `class MockExerciseGeneratorSource extends Mock implements ExerciseGeneratorSource {}`
- Gemini model: `gemini-2.5-flash`, `responseMimeType: 'application/json'`
- If `!aiEnabled` → return `FlashcardExercise` immediately (no API call)
- Fallback: if Gemini throws any exception → return `FlashcardExercise` (no crash)

## What This Task Delivers

Two classes:
1. `ExerciseGeneratorSource` — calls Gemini, parses JSON response into an `Exercise` subtype
2. `GenerateExerciseUseCase` — thin wrapper, handles `aiEnabled` check + exception fallback

## Files

- Create: `lib/features/practice/data/sources/exercise_generator_source.dart`
- Create: `lib/features/practice/domain/use_cases/generate_exercise_use_case.dart`
- Create: `test/features/practice/domain/use_cases/generate_exercise_use_case_test.dart`

## Interfaces

### ExerciseGeneratorSource

Declare a local `ExerciseGeneratorClient` interface (do NOT import from gemini_dictionary_source.dart):

```dart
abstract interface class ExerciseGeneratorClient {
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt);
}

class ExerciseGeneratorSource {
  ExerciseGeneratorSource({required String apiKey}); // uses real Gemini
  ExerciseGeneratorSource.withClient(ExerciseGeneratorClient client); // for tests
  Future<Exercise> generate(VocabRecord record);
}
```

JSON response shapes from Gemini:
```json
{"type":"multiple_choice","question":"...","options":["...","...","...","..."],"correctIndex":0}
{"type":"fill_in_blank","sentence":"A sentence with ___ here.","answer":"word"}
{"type":"translation","prompt":"Translate to Vietnamese: '...'","answer":"..."}
```
Unknown `type` → fall back to `FlashcardExercise(vocabRecord: record)`.

### GenerateExerciseUseCase

```dart
class GenerateExerciseUseCase {
  const GenerateExerciseUseCase(this._source);
  final ExerciseGeneratorSource _source;
  Future<Exercise> execute(VocabRecord record, {required bool aiEnabled});
}
```

Behavior:
- `!aiEnabled` → return `FlashcardExercise(vocabRecord: record)` immediately, no source call
- `aiEnabled` + success → return exercise from source
- `aiEnabled` + exception → catch any error, return `FlashcardExercise(vocabRecord: record)`

## Test Cases (3 tests minimum)

```dart
class MockExerciseGeneratorSource extends Mock implements ExerciseGeneratorSource {}

test('returns FlashcardExercise immediately when aiEnabled=false', ...)
test('calls source.generate() when aiEnabled=true and returns result', ...)
test('falls back to FlashcardExercise if source throws', ...)
```

## Produces (used by Task 04 DI, Task 05 session provider)

- `ExerciseGeneratorSource` class (injectable via `.withClient()`)
- `GenerateExerciseUseCase` class

## Run after implementing

```
flutter test test/features/practice/domain/use_cases/generate_exercise_use_case_test.dart
flutter test   # full suite, no regressions
flutter analyze lib/
```
