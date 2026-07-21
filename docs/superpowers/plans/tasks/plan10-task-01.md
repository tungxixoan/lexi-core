# Plan 10 — Task 01: ListeningPassage Domain Entities

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** none (can start immediately)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Four immutable domain types for the comprehension feature: `ListeningKind` (enum: conversation | talk), `ListeningTurn` (one line of dialogue/monologue, with an optional speaker label), `ListeningQuestion` (one multiple-choice question, 4 options, a correct index), and `ListeningPassage` (the full generated exercise: kind + turns + exactly-3 questions + metadata).

## Files
- Create: `lib/features/listening/domain/entities/listening_passage.dart`
- Create: `test/features/listening/domain/entities/listening_passage_test.dart`

## Produces (used by Tasks 03–07)
- `enum ListeningKind { conversation, talk }`
- `ListeningTurn({String? speaker, required String text})`
- `ListeningQuestion({required String question, required List<String> options, required int correctIndex})`
- `ListeningPassage({required String id, required ListeningKind kind, required List<ListeningTurn> turns, required List<ListeningQuestion> questions, required CEFRLevel level, required AppContext context, required Language targetLanguage, required DateTime generatedAt})`

## Steps

- [ ] **Step 1: Write the failing test**

Create `test/features/listening/domain/entities/listening_passage_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';

void main() {
  group('ListeningTurn', () {
    test('holds speaker and text', () {
      const turn = ListeningTurn(speaker: 'A', text: 'Hello there.');
      expect(turn.speaker, 'A');
      expect(turn.text, 'Hello there.');
    });

    test('speaker can be null for a talk', () {
      const turn = ListeningTurn(text: 'Attention all passengers.');
      expect(turn.speaker, isNull);
    });
  });

  group('ListeningQuestion', () {
    test('holds question, 4 options, and correct index', () {
      const question = ListeningQuestion(
        question: 'What is the main topic?',
        options: ['Weather', 'Travel', 'Food', 'Sports'],
        correctIndex: 1,
      );
      expect(question.options.length, 4);
      expect(question.correctIndex, 1);
    });
  });

  group('ListeningPassage', () {
    final passage = ListeningPassage(
      id: 'test-id',
      kind: ListeningKind.conversation,
      turns: const [
        ListeningTurn(speaker: 'A', text: 'Can I help you?'),
        ListeningTurn(speaker: 'B', text: 'Yes, I am looking for a jacket.'),
      ],
      questions: const [
        ListeningQuestion(
          question: 'Where does this conversation take place?',
          options: ['A restaurant', 'A clothing store', 'An airport', 'A hospital'],
          correctIndex: 1,
        ),
        ListeningQuestion(
          question: 'What does the customer want?',
          options: ['A refund', 'Directions', 'A jacket', 'A discount'],
          correctIndex: 2,
        ),
        ListeningQuestion(
          question: 'What is implied about the customer?',
          options: ['They are in a hurry', 'They are shopping', 'They are lost', 'They are complaining'],
          correctIndex: 1,
        ),
      ],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026, 7, 19),
    );

    test('has correct turn count', () {
      expect(passage.turns.length, 2);
    });

    test('always has exactly 3 questions', () {
      expect(passage.questions.length, 3);
    });

    test('holds kind, level, context, targetLanguage', () {
      expect(passage.kind, ListeningKind.conversation);
      expect(passage.level, CEFRLevel.b1);
      expect(passage.context, AppContext.general);
      expect(passage.targetLanguage, Language.english);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/domain/entities/listening_passage_test.dart
```

Expected: FAIL — `listening_passage.dart` doesn't exist yet.

- [ ] **Step 3: Create the entity file**

Create `lib/features/listening/domain/entities/listening_passage.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum ListeningKind { conversation, talk }

final class ListeningTurn {
  const ListeningTurn({this.speaker, required this.text});

  final String? speaker; // 'A' or 'B' for a conversation; null for a talk
  final String text;
}

final class ListeningQuestion {
  const ListeningQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  final String question;
  final List<String> options; // always 4 items
  final int correctIndex; // 0-3
}

final class ListeningPassage {
  const ListeningPassage({
    required this.id,
    required this.kind,
    required this.turns,
    required this.questions,
    required this.level,
    required this.context,
    required this.targetLanguage,
    required this.generatedAt,
  });

  final String id;
  final ListeningKind kind;
  final List<ListeningTurn> turns;
  final List<ListeningQuestion> questions; // always 3 items
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
flutter test test/features/listening/domain/entities/listening_passage_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Analyze**

```bash
flutter analyze lib/features/listening/domain/entities/listening_passage.dart
```

Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/listening/domain/entities/listening_passage.dart \
        test/features/listening/domain/entities/listening_passage_test.dart
git commit -m "feat(plan10): add ListeningPassage domain entities"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
