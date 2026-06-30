# Task 6: Free Dictionary API Source

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 3, 5

## Interfaces From Prior Tasks
- `WordPhraseResult` from `lib/features/dictionary/domain/entities/lookup_result.dart`
- `InputDetector.detect(String) → InputType` from `lib/core/utils/input_detector.dart`
- `DictionaryException` from `lib/features/dictionary/domain/repositories/dictionary_repository.dart`

## What This Task Delivers
HTTP client for the Free Dictionary API (English only). Used as fallback when AI is disabled.

API base URL: `https://api.dictionaryapi.dev/api/v2/entries/en/{word}`

## Files
- Create: `lib/features/dictionary/data/sources/free_dictionary_source.dart`
- Create: `test/features/dictionary/data/sources/free_dictionary_source_test.dart`

## Produces (used by Task 8)
```dart
class FreeDictionarySource {
  FreeDictionarySource(http.Client client);
  Future<WordPhraseResult> lookup(String word);
}
```

## Steps

- [ ] **Step 1: Write failing tests**

```dart
// test/features/dictionary/data/sources/free_dictionary_source_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/data/sources/free_dictionary_source.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/repositories/dictionary_repository.dart';

import 'free_dictionary_source_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late FreeDictionarySource source;

  setUp(() {
    mockClient = MockClient();
    source = FreeDictionarySource(mockClient);
  });

  const successJson = '''[{
    "word": "follow",
    "phonetics": [{"text": "/ˈfɒl.oʊ/"}],
    "meanings": [{
      "partOfSpeech": "verb",
      "definitions": [{
        "definition": "Go or come after.",
        "example": "She followed him into the house."
      }]
    }]
  }]''';

  test('parses word, IPA, meaning, and examples from API response', () async {
    when(mockClient.get(any)).thenAnswer(
      (_) async => http.Response(successJson, 200),
    );

    final result = await source.lookup('follow');

    expect(result.headword, 'follow');
    expect(result.ipa, '/ˈfɒl.oʊ/');
    expect(result.meaning, 'Go or come after.');
    expect(result.examples, ['She followed him into the house.']);
    expect(result.inputType, InputType.word);
  });

  test('throws DictionaryException on non-200 response', () async {
    when(mockClient.get(any)).thenAnswer(
      (_) async => http.Response('Not Found', 404),
    );

    expect(
      () => source.lookup('xyznotaword'),
      throwsA(isA<DictionaryException>()),
    );
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: creates `test/features/dictionary/data/sources/free_dictionary_source_test.mocks.dart`

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/dictionary/data/sources/free_dictionary_source_test.dart
```

Expected: compile error — `FreeDictionarySource` not defined.

- [ ] **Step 4: Implement free_dictionary_source.dart**

```dart
// lib/features/dictionary/data/sources/free_dictionary_source.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/utils/input_detector.dart';
import '../../domain/entities/lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';

class FreeDictionarySource {
  FreeDictionarySource(this._client);

  final http.Client _client;
  static const _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en/';

  Future<WordPhraseResult> lookup(String word) async {
    final response = await _client.get(Uri.parse('$_baseUrl$word'));
    if (response.statusCode != 200) {
      throw DictionaryException('Word not found: $word');
    }
    final list = jsonDecode(response.body) as List;
    return _parse(list.first as Map<String, dynamic>, word);
  }

  WordPhraseResult _parse(Map<String, dynamic> data, String word) {
    final phonetics = (data['phonetics'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final ipa = phonetics.isNotEmpty
        ? (phonetics.first['text'] as String?) ?? ''
        : '';

    final meanings =
        (data['meanings'] as List?)?.whereType<Map<String, dynamic>>() ?? [];
    String meaning = '';
    final examples = <String>[];

    for (final m in meanings) {
      final defs = (m['definitions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      for (final d in defs) {
        if (meaning.isEmpty) meaning = (d['definition'] as String?) ?? '';
        final ex = d['example'] as String?;
        if (ex != null) examples.add(ex);
      }
    }

    return WordPhraseResult(
      headword: word,
      inputType: InputDetector.detect(word),
      ipa: ipa,
      meaning: meaning,
      examples: examples.take(3).toList(),
      suggestedTopics: const [],
    );
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
flutter test test/features/dictionary/data/sources/free_dictionary_source_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/dictionary/data/sources/free_dictionary_source.dart \
        test/features/dictionary/data/sources/
git commit -m "feat: add FreeDictionarySource with HTTP parsing"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/features/dictionary/data/sources/free_dictionary_source_test.dart`
Concerns: (if any)
