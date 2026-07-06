# Plan 7 — Task 01: Domain Entities (ReadingPassage + BilingualSentence)

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 6 complete

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
Two immutable domain entities with JSON serialization: `BilingualSentence` (one sentence in target language + Vietnamese translation + vocab IDs used) and `ReadingPassage` (a full 4–6 sentence passage with metadata).

## Files
- Create: `lib/features/reading/domain/entities/reading_passage.dart`
- Create: `test/features/reading/domain/entities/reading_passage_test.dart`

## Produces (used by Tasks 02–06)
- `BilingualSentence({required String target, required String vietnamese, required List<String> vocabIds})`
- `BilingualSentence.fromJson(Map<String, dynamic>)` / `toJson()`
- `ReadingPassage({required String id, required List<BilingualSentence> sentences, required List<String> vocabIds, required CEFRLevel level, required AppContext context, required Language targetLanguage, required DateTime generatedAt})`

## Steps

- [ ] **Step 1: Write the failing test**

Create `test/features/reading/domain/entities/reading_passage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';

void main() {
  group('BilingualSentence', () {
    test('fromJson round-trips through toJson', () {
      const sentence = BilingualSentence(
        target: 'She showed great perseverance.',
        vietnamese: 'Cô ấy thể hiện sự kiên trì tuyệt vời.',
        vocabIds: ['id1', 'id2'],
      );
      final json = sentence.toJson();
      final decoded = BilingualSentence.fromJson(json);
      expect(decoded.target, sentence.target);
      expect(decoded.vietnamese, sentence.vietnamese);
      expect(decoded.vocabIds, sentence.vocabIds);
    });

    test('fromJson handles missing vocabIds gracefully', () {
      final json = <String, dynamic>{
        'target': 'Hello world.',
        'vietnamese': 'Xin chào thế giới.',
      };
      final sentence = BilingualSentence.fromJson(json);
      expect(sentence.vocabIds, isEmpty);
    });
  });

  group('ReadingPassage', () {
    final passage = ReadingPassage(
      id: 'test-id',
      sentences: const [
        BilingualSentence(
          target: 'First sentence.',
          vietnamese: 'Câu đầu tiên.',
          vocabIds: ['id1'],
        ),
        BilingualSentence(
          target: 'Second sentence.',
          vietnamese: 'Câu thứ hai.',
          vocabIds: ['id2'],
        ),
      ],
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 6),
    );

    test('has correct sentence count', () {
      expect(passage.sentences.length, 2);
    });

    test('vocabIds contains all sentence vocab IDs', () {
      expect(passage.vocabIds, containsAll(['id1', 'id2']));
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/reading/domain/entities/reading_passage_test.dart
```

Expected: FAIL — `reading_passage.dart` doesn't exist yet.

- [ ] **Step 3: Create the entity file**

Create `lib/features/reading/domain/entities/reading_passage.dart`:

```dart
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';

final class BilingualSentence {
  const BilingualSentence({
    required this.target,
    required this.vietnamese,
    required this.vocabIds,
  });

  final String target;
  final String vietnamese;
  final List<String> vocabIds; // VocabRecord.id values used in this sentence

  factory BilingualSentence.fromJson(Map<String, dynamic> json) =>
      BilingualSentence(
        target: json['target'] as String,
        vietnamese: json['vietnamese'] as String,
        vocabIds: List<String>.from(json['vocabIds'] as List? ?? []),
      );

  Map<String, dynamic> toJson() => {
        'target': target,
        'vietnamese': vietnamese,
        'vocabIds': vocabIds,
      };
}

final class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.sentences,
    required this.vocabIds,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final List<BilingualSentence> sentences;
  final List<String> vocabIds; // union of all sentence.vocabIds
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/features/reading/domain/entities/reading_passage_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/features/reading/domain/entities/reading_passage.dart
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/reading/domain/entities/reading_passage.dart \
        test/features/reading/domain/entities/reading_passage_test.dart
git commit -m "feat(plan7): add ReadingPassage + BilingualSentence domain entities"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
