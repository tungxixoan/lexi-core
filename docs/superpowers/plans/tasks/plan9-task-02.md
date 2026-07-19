# Plan 9 — Task 02: DictationItem Domain Entity

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** none (can run in parallel with Task 01)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
A single immutable domain entity, `DictationItem` — one AI-generated sentence (target + Vietnamese translation) plus the Vocab Bank word IDs it uses. This is the single-sentence sibling of Reading's `ReadingPassage`/`BilingualSentence`, but flattened into one entity since a dictation session is always exactly one sentence.

## Files
- Create: `lib/features/listening/domain/entities/dictation_item.dart`
- Create: `test/features/listening/domain/entities/dictation_item_test.dart`

## Produces (used by Tasks 03–07)
- `DictationItem({required String id, required String target, required String vietnamese, required List<String> vocabIds, required CEFRLevel level, required AppContext context, required Language targetLanguage, required DateTime generatedAt})`

## Steps

- [ ] **Step 1: Write the failing test**

Create `test/features/listening/domain/entities/dictation_item_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';

void main() {
  test('holds all constructor fields', () {
    final item = DictationItem(
      id: 'item-1',
      target: 'She showed remarkable perseverance in her work.',
      vietnamese: 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.',
      vocabIds: const ['id1', 'id2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 19),
    );

    expect(item.id, 'item-1');
    expect(item.target, 'She showed remarkable perseverance in her work.');
    expect(item.vietnamese, 'Cô ấy thể hiện sự kiên trì đáng kể trong công việc.');
    expect(item.vocabIds, ['id1', 'id2']);
    expect(item.level, CEFRLevel.b1);
    expect(item.context, AppContext.general);
    expect(item.targetLanguage, Language.english);
    expect(item.generatedAt, DateTime(2026, 7, 19));
  });

  test('vocabIds can be empty', () {
    final item = DictationItem(
      id: 'item-2',
      target: 'Hello world.',
      vietnamese: 'Xin chào thế giới.',
      vocabIds: const [],
      level: CEFRLevel.a1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026),
    );
    expect(item.vocabIds, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/domain/entities/dictation_item_test.dart
```

Expected: FAIL — `dictation_item.dart` doesn't exist yet.

- [ ] **Step 3: Create the entity file**

Create `lib/features/listening/domain/entities/dictation_item.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

final class DictationItem {
  const DictationItem({
    required this.id,
    required this.target,
    required this.vietnamese,
    required this.vocabIds,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final String target;
  final String vietnamese;
  final List<String> vocabIds; // VocabRecord.id values used in this sentence
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/features/listening/domain/entities/dictation_item_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/features/listening/domain/entities/dictation_item.dart
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/listening/domain/entities/dictation_item.dart \
        test/features/listening/domain/entities/dictation_item_test.dart
git commit -m "feat(plan9): add DictationItem domain entity"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
