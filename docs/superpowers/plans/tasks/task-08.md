# Task 8: Dictionary Repository Implementation

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 3, 5, 6, 7

## Interfaces From Prior Tasks
- `DictionaryRepository` interface from `lib/features/dictionary/domain/repositories/dictionary_repository.dart`
- `DictionaryException` from same file
- `GeminiDictionarySource` from `lib/features/dictionary/data/sources/gemini_dictionary_source.dart`
- `FreeDictionarySource` from `lib/features/dictionary/data/sources/free_dictionary_source.dart`
- `InputDetector.detect(String) → InputType` from `lib/core/utils/input_detector.dart`
- `Language.requiresAi` getter (returns `true` for Chinese, Korean, Japanese)

## What This Task Delivers
The repository implementation that routes to Gemini (AI on) or FreeDictionary (AI off, English only). Enforces constraints: non-English requires AI, sentences require AI.

## Files
- Create: `lib/features/dictionary/data/repositories/dictionary_repository_impl.dart`
- Create: `test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart`

## Produces (used by Task 10)
```dart
class DictionaryRepositoryImpl implements DictionaryRepository {
  const DictionaryRepositoryImpl({
    required GeminiDictionarySource geminiSource,
    required FreeDictionarySource freeDictionarySource,
  });
}
```

## Routing Logic
- `aiEnabled == true` → always use Gemini
- `aiEnabled == false && targetLanguage.requiresAi` → throw `DictionaryException('AI must be enabled...')`
- `aiEnabled == false && inputType == sentence` → throw `DictionaryException('AI must be enabled...')`
- `aiEnabled == false && English && word/phrase` → use FreeDictionary

## Steps

- [ ] **Step 1: Write failing tests**

```dart
// test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/data/repositories/dictionary_repository_impl.dart';
import 'package:lexi_core/features/dictionary/data/sources/free_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/data/sources/gemini_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
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
  });

  test('routes to Gemini when AI is enabled', () async {
    when(mockGemini.lookup(
      query: anyNamed('query'),
      inputType: anyNamed('inputType'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
    )).thenAnswer((_) async => wordResult);

    await repo.lookup(
      query: 'follow',
      targetLanguage: Language.english,
      context: AppContext.general,
      aiEnabled: true,
    );

    verify(mockGemini.lookup(
      query: 'follow',
      inputType: InputType.word,
      targetLanguage: Language.english,
      context: AppContext.general,
    )).called(1);
    verifyNever(mockFree.lookup(any));
  });

  test('routes to FreeDictionary when AI disabled + English word', () async {
    when(mockFree.lookup(any)).thenAnswer((_) async => wordResult);

    await repo.lookup(
      query: 'follow',
      targetLanguage: Language.english,
      context: AppContext.general,
      aiEnabled: false,
    );

    verify(mockFree.lookup('follow')).called(1);
    verifyNever(mockGemini.lookup(
      query: anyNamed('query'),
      inputType: anyNamed('inputType'),
      targetLanguage: anyNamed('targetLanguage'),
      context: anyNamed('context'),
    ));
  });

  test('throws DictionaryException: AI disabled + non-English language', () {
    expect(
      () => repo.lookup(
        query: 'follow',
        targetLanguage: Language.korean,
        context: AppContext.general,
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
        context: AppContext.general,
        aiEnabled: false,
      ),
      throwsA(isA<DictionaryException>()),
    );
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart
```

Expected: compile error — `DictionaryRepositoryImpl` not defined.

- [ ] **Step 4: Implement dictionary_repository_impl.dart**

```dart
// lib/features/dictionary/data/repositories/dictionary_repository_impl.dart
import '../../../../core/utils/input_detector.dart';
import '../../domain/entities/app_context.dart';
import '../../domain/entities/input_type.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../sources/free_dictionary_source.dart';
import '../sources/gemini_dictionary_source.dart';

class DictionaryRepositoryImpl implements DictionaryRepository {
  const DictionaryRepositoryImpl({
    required this.geminiSource,
    required this.freeDictionarySource,
  });

  final GeminiDictionarySource geminiSource;
  final FreeDictionarySource freeDictionarySource;

  @override
  Future<LookupResult> lookup({
    required String query,
    required Language targetLanguage,
    required AppContext context,
    required bool aiEnabled,
  }) async {
    final inputType = InputDetector.detect(query);

    if (aiEnabled) {
      return geminiSource.lookup(
        query: query,
        inputType: inputType,
        targetLanguage: targetLanguage,
        context: context,
      );
    }

    if (targetLanguage.requiresAi) {
      throw DictionaryException(
        'AI must be enabled for ${targetLanguage.label} lookups.',
      );
    }

    if (inputType == InputType.sentence) {
      throw const DictionaryException(
        'AI must be enabled to translate sentences.',
      );
    }

    return freeDictionarySource.lookup(query);
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dictionary/data/repositories/ \
        test/features/dictionary/data/repositories/
git commit -m "feat: add DictionaryRepositoryImpl with AI-on/off routing"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/features/dictionary/data/repositories/dictionary_repository_impl_test.dart`
Concerns: (if any)
