# Task 9: Lookup Use Case

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 5, 8

## Interfaces From Prior Tasks
- `DictionaryRepository` interface: `lookup({query, targetLanguage, context, aiEnabled}) → Future<LookupResult>`
- `DictionaryException(String message)` — throw for empty query
- `AppContext`, `Language`, `LookupResult` from `lib/features/dictionary/domain/entities/`

## What This Task Delivers
The domain use case that trims the query, validates it's non-empty, then delegates to the repository.

## Files
- Create: `lib/features/dictionary/domain/use_cases/lookup_use_case.dart`
- Create: `test/features/dictionary/domain/use_cases/lookup_use_case_test.dart`

## Produces (used by Task 10)
```dart
class LookupUseCase {
  const LookupUseCase(DictionaryRepository repository);

  Future<LookupResult> execute({
    required String query,       // trimmed before passing to repo
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  });
}
```

## Steps

- [ ] **Step 1: Write failing tests**

```dart
// test/features/dictionary/domain/use_cases/lookup_use_case_test.dart
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
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/dictionary/domain/use_cases/lookup_use_case_test.dart
```

Expected: compile error.

- [ ] **Step 4: Implement lookup_use_case.dart**

```dart
// lib/features/dictionary/domain/use_cases/lookup_use_case.dart
import '../entities/app_context.dart';
import '../entities/language.dart';
import '../entities/lookup_result.dart';
import '../repositories/dictionary_repository.dart';

class LookupUseCase {
  const LookupUseCase(this._repository);

  final DictionaryRepository _repository;

  Future<LookupResult> execute({
    required String query,
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      throw const DictionaryException('Query cannot be empty.');
    }
    return _repository.lookup(
      query: trimmed,
      targetLanguage: targetLanguage,
      context: context,
      aiEnabled: aiEnabled,
    );
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/dictionary/domain/use_cases/lookup_use_case_test.dart
```

- [ ] **Step 6: Run full suite — no regressions**

```bash
flutter test
```

Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dictionary/domain/use_cases/ \
        test/features/dictionary/domain/use_cases/
git commit -m "feat: add LookupUseCase with empty-query guard and trim"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test`
Concerns: (if any)
