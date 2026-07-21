# Plan 10 — Task 03: ListeningPassageSource + GenerateListeningPassageUseCase

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Task 01 (`ListeningPassage`, `ListeningTurn`, `ListeningQuestion`, `ListeningKind` defined)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
`ListeningPassageSource` calls the active AI provider once (via `AiClientFactory`/`GenerativeModelClient`, exactly like `DictationSource`/`ReadingPassageSource` — never a hardcoded Gemini client) with a prompt that asks the model to randomly produce either a 2-speaker conversation or a 1-speaker talk (split into 2–4 turns), plus exactly 3 multiple-choice questions with 4 options each, and parses the JSON response into a `ListeningPassage`. Unlike `DictationSource`, this prompt takes **no vocabulary words** — content is a generic scenario shaped only by CEFR level and AppContext. `GenerateListeningPassageUseCase` wraps the source.

## Files
- Create: `lib/features/listening/data/sources/listening_passage_source.dart`
- Create: `lib/features/listening/domain/use_cases/generate_listening_passage_use_case.dart`
- Create: `test/features/listening/data/sources/listening_passage_source_test.dart`
- Create: `test/features/listening/domain/use_cases/generate_listening_passage_use_case_test.dart`

## Interfaces
- Consumes: `ListeningPassage`, `ListeningTurn`, `ListeningQuestion`, `ListeningKind` from Task 01; `CEFRLevel`, `AppContext`, `Language`, `UserSettingsState` from existing code; `AiClientFactory`/`GenerativeModelClient` from `lib/core/services/ai_client_factory.dart`
- Produces:
  - `ListeningPassageSource(UserSettingsState settings)` — production constructor
  - `ListeningPassageSource.withModel(GenerativeModelClient client)` — for testing
  - `ListeningPassageSource.generate({required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<ListeningPassage>`
  - `GenerateListeningPassageUseCase(ListeningPassageSource source)`
  - `GenerateListeningPassageUseCase.execute({required CEFRLevel level, required AppContext context, required Language targetLanguage}) → Future<ListeningPassage>`

## Steps

- [ ] **Step 1: Write the failing test for ListeningPassageSource**

Create `test/features/listening/data/sources/listening_passage_source_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/data/sources/listening_passage_source.dart';

class FakeGenerativeModelClient implements GenerativeModelClient {
  FakeGenerativeModelClient(this._responseText);
  final String _responseText;

  @override
  Future<GenerateContentResponse> generateContent(Iterable<Content> prompt) async {
    return GenerateContentResponse(
      [Candidate(Content.text(_responseText), null, null, null, null)],
      null,
    );
  }
}

void main() {
  final conversationJson = jsonEncode({
    'kind': 'conversation',
    'turns': [
      {'speaker': 'A', 'text': 'Can I help you find something?'},
      {'speaker': 'B', 'text': 'Yes, I am looking for a winter jacket.'},
    ],
    'questions': [
      {
        'question': 'Where does this conversation take place?',
        'options': ['A restaurant', 'A clothing store', 'An airport', 'A hospital'],
        'correctIndex': 1,
      },
      {
        'question': 'What is the customer looking for?',
        'options': ['A refund', 'Directions', 'A jacket', 'A discount'],
        'correctIndex': 2,
      },
      {
        'question': 'What time of year is implied?',
        'options': ['Summer', 'Winter', 'Spring', 'Fall'],
        'correctIndex': 1,
      },
    ],
  });

  test('parses a conversation response into a ListeningPassage', () async {
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(conversationJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.kind, ListeningKind.conversation);
    expect(passage.turns.length, 2);
    expect(passage.turns[0].speaker, 'A');
    expect(passage.turns[1].speaker, 'B');
    expect(passage.questions.length, 3);
    expect(passage.questions[0].options.length, 4);
    expect(passage.questions[0].correctIndex, 1);
    expect(passage.level, CEFRLevel.b1);
    expect(passage.targetLanguage, Language.english);
    expect(passage.id, isNotEmpty);
  });

  test('parses a talk response (null speaker) into a ListeningPassage', () async {
    final talkJson = jsonEncode({
      'kind': 'talk',
      'turns': [
        {'speaker': null, 'text': 'Attention all passengers.'},
        {'speaker': null, 'text': 'Flight 204 is now boarding at gate 12.'},
      ],
      'questions': [
        {
          'question': 'What is being announced?',
          'options': ['A delay', 'A boarding call', 'A cancellation', 'A gate change'],
          'correctIndex': 1,
        },
        {
          'question': 'What is the flight number?',
          'options': ['104', '204', '402', '240'],
          'correctIndex': 1,
        },
        {
          'question': 'Where should passengers go?',
          'options': ['Gate 12', 'Gate 21', 'Baggage claim', 'Security'],
          'correctIndex': 0,
        },
      ],
    });
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(talkJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.a2,
      context: AppContext.travel,
      targetLanguage: Language.english,
    );

    expect(passage.kind, ListeningKind.talk);
    expect(passage.turns.every((t) => t.speaker == null), isTrue);
    expect(passage.questions.length, 3);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/data/sources/listening_passage_source_test.dart
```

Expected: FAIL — `listening_passage_source.dart` doesn't exist.

- [ ] **Step 3: Create ListeningPassageSource**

Create `lib/features/listening/data/sources/listening_passage_source.dart`:

```dart
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' hide Language;
import 'package:uuid/uuid.dart';
import '../../../../core/services/ai_client_factory.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/domain/entities/user_settings_state.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/listening_passage.dart';

// Re-export so test imports (from this file) continue to resolve.
export '../../../../core/services/ai_client_factory.dart' show GenerativeModelClient;

class ListeningPassageSource {
  ListeningPassageSource(UserSettingsState settings)
      : _client = AiClientFactory.buildClient(settings);

  ListeningPassageSource.withModel(GenerativeModelClient client) : _client = client;

  final GenerativeModelClient _client;
  static const _uuid = Uuid();

  Future<ListeningPassage> generate({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) async {
    final prompt = _buildPrompt(
      level: level,
      context: context,
      targetLanguage: targetLanguage,
    );
    final response = await _client.generateContent([Content.text(prompt)]);
    final text = response.text ?? '{"kind":"talk","turns":[],"questions":[]}';
    final json = jsonDecode(text) as Map<String, dynamic>;
    return _parse(json, level, context, targetLanguage);
  }

  String _buildPrompt({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) {
    return 'You are creating a TOEIC-style listening exercise for a Vietnamese speaker '
        'learning ${targetLanguage.label}, at ${level.label} level, in a ${context.label} '
        'register/setting. '
        'Randomly choose ONE of these two formats: '
        '(1) a CONVERSATION between exactly two speakers labeled "A" and "B" only '
        '(e.g. at an office, store, or while traveling), with 3 to 6 turns alternating '
        'between "A" and "B"; or '
        '(2) a TALK by a single speaker (e.g. an announcement, advertisement, or set of '
        'instructions), split into 2 to 4 turns, each with speaker set to null. '
        'Then write exactly 3 multiple-choice questions in ${targetLanguage.label} about '
        'the passage, each with exactly 4 answer options in ${targetLanguage.label}, '
        'testing the main idea, a specific detail, or an implied meaning — never a '
        'fill-in-the-blank question. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"kind": "conversation" or "talk", '
        '"turns": [{"speaker": "A" or "B" or null, "text": "..."}], '
        '"questions": [{"question": "...", "options": ["...", "...", "...", "..."], '
        '"correctIndex": 0}]}';
  }

  ListeningPassage _parse(
    Map<String, dynamic> json,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final kind = json['kind'] == 'conversation'
        ? ListeningKind.conversation
        : ListeningKind.talk;

    final turns = (json['turns'] as List? ?? []).map((t) {
      final tm = t as Map<String, dynamic>;
      return ListeningTurn(
        speaker: tm['speaker'] as String?,
        text: tm['text'] as String? ?? '',
      );
    }).toList();

    final questions = (json['questions'] as List? ?? []).map((q) {
      final qm = q as Map<String, dynamic>;
      return ListeningQuestion(
        question: qm['question'] as String? ?? '',
        options: List<String>.from(qm['options'] as List? ?? []),
        correctIndex: qm['correctIndex'] as int? ?? 0,
      );
    }).toList();

    return ListeningPassage(
      id: _uuid.v4(),
      kind: kind,
      turns: turns,
      questions: questions,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
}
```

- [ ] **Step 4: Run the source test**

```bash
flutter test test/features/listening/data/sources/listening_passage_source_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Write the use case test**

Create `test/features/listening/domain/use_cases/generate_listening_passage_use_case_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/data/sources/listening_passage_source.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/domain/use_cases/generate_listening_passage_use_case.dart';

class MockListeningPassageSource extends Mock implements ListeningPassageSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(CEFRLevel.a1);
    registerFallbackValue(AppContext.general);
    registerFallbackValue(Language.english);
  });

  late MockListeningPassageSource mockSource;
  late GenerateListeningPassageUseCase useCase;

  setUp(() {
    mockSource = MockListeningPassageSource();
    useCase = GenerateListeningPassageUseCase(mockSource);
  });

  final fakePassage = ListeningPassage(
    id: 'fake-id',
    kind: ListeningKind.talk,
    turns: const [],
    questions: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  );

  test('delegates to source.generate() and returns the passage', () async {
    when(
      () => mockSource.generate(
        level: any(named: 'level'),
        context: any(named: 'context'),
        targetLanguage: any(named: 'targetLanguage'),
      ),
    ).thenAnswer((_) async => fakePassage);

    final result = await useCase.execute(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );
    expect(result, same(fakePassage));
    verify(
      () => mockSource.generate(
        level: CEFRLevel.b1,
        context: AppContext.general,
        targetLanguage: Language.english,
      ),
    ).called(1);
  });
}
```

- [ ] **Step 6: Create the use case**

Create `lib/features/listening/domain/use_cases/generate_listening_passage_use_case.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../data/sources/listening_passage_source.dart';
import '../entities/listening_passage.dart';

class GenerateListeningPassageUseCase {
  const GenerateListeningPassageUseCase(this._source);
  final ListeningPassageSource _source;

  Future<ListeningPassage> execute({
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
  }) =>
      _source.generate(
        level: level,
        context: context,
        targetLanguage: targetLanguage,
      );
}
```

- [ ] **Step 7: Run all listening tests**

```bash
flutter test test/features/listening/
```

Expected: all tests pass.

- [ ] **Step 8: Analyze**

```bash
flutter analyze lib/features/listening/
```

Expected: no issues.

- [ ] **Step 9: Commit**

```bash
git add lib/features/listening/data/sources/listening_passage_source.dart \
        lib/features/listening/domain/use_cases/generate_listening_passage_use_case.dart \
        test/features/listening/data/sources/listening_passage_source_test.dart \
        test/features/listening/domain/use_cases/generate_listening_passage_use_case_test.dart
git commit -m "feat(plan10): add ListeningPassageSource + GenerateListeningPassageUseCase"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
