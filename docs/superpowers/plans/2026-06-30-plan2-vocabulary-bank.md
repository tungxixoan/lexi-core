# LexiCore — Plan 2: Vocabulary Bank + Topic System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Task files split:** Individual task briefs live in `docs/superpowers/plans/tasks/plan2-task-{01..10}.md`.
> Navigation index + progress ledger: `docs/superpowers/plans/tasks/plan2-INDEX.md`
> **Do NOT read this full plan file per-task** — read `plan2-INDEX.md` first, then dispatch each subagent with only their task file.

**Goal:** Let users save looked-up words/phrases to a personal Vocabulary Bank, organize them by topic (20 predefined + custom), and view/edit entries — using Hive for offline-first local storage.

**Architecture:** New `vocabulary` feature module following the same Clean Architecture pattern as `dictionary`. VocabRecord entities stored in Hive as JSON strings (no code generation). Topics seeded on first run. Bottom navigation bar added via GoRouter ShellRoute to expose the Vocab Bank alongside the existing Dictionary screen.

**Tech Stack:** hive 2.2.3, hive_flutter 1.1.0, uuid 4.5.1 (added to existing Flutter/Riverpod/GoRouter stack)

**This is Plan 2 of 4:**

- Plan 1 ✅: Foundation + Dictionary Lookup
- Plan 2 (this): Vocabulary Bank + Topic System
- Plan 3: Spaced Repetition + Auto Exercises
- Plan 4: Firebase Sync + Settings Screen + Level Auto-Adjust

## Global Constraints

- Flutter SDK: >=3.22.0 · Dart SDK: >=3.4.0
- State management: Riverpod 2.x with `@riverpod` annotation — no StateNotifier, no ChangeNotifier
- Navigation: GoRouter only — no `Navigator.push`
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- Hive storage: `Box<String>` with `jsonEncode/jsonDecode` — no Hive code generation
- Topic constraint: each VocabRecord max **2** topic tags
- Sentences are **never** saved to VocabBank (only word/phrase InputType)
- Predefined 20 topics: cannot be deleted; words in a deleted custom topic → auto-reassigned to `'other'`
- Gemini model: `gemini-2.5-flash`
- Working directory: `d:/Flutter/lexi-core`

---

## File Map

```text
lib/
├── core/
│   ├── di/app_providers.dart           MODIFY — add vocab DI providers
│   ├── router/app_router.dart          MODIFY — add ShellRoute + vocab routes
│   └── widgets/app_shell.dart          CREATE — NavigationBar wrapper
├── features/
│   ├── dictionary/
│   │   └── presentation/widgets/
│   │       ├── word_result_widget.dart MODIFY — add Save button
│   │       └── save_vocab_sheet.dart   CREATE — bottom sheet for save/edit
│   └── vocabulary/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── cefr_level.dart     CREATE
│       │   │   ├── vocab_record.dart   CREATE
│       │   │   └── topic.dart          CREATE
│       │   ├── repositories/
│       │   │   └── vocab_repository.dart   CREATE
│       │   └── use_cases/
│       │       ├── save_vocab_use_case.dart
│       │       ├── get_vocab_list_use_case.dart
│       │       ├── update_vocab_use_case.dart
│       │       ├── delete_vocab_use_case.dart
│       │       ├── get_topics_use_case.dart
│       │       ├── add_topic_use_case.dart
│       │       └── delete_topic_use_case.dart
│       ├── data/repositories/
│       │   └── vocab_repository_impl.dart  CREATE
│       └── presentation/
│           ├── providers/
│           │   ├── vocab_bank_provider.dart   CREATE
│           │   └── topics_provider.dart        CREATE
│           └── screens/
│               ├── vocab_bank_screen.dart      CREATE
│               └── vocab_detail_screen.dart    CREATE

test/
└── features/vocabulary/
    └── domain/use_cases/
        └── vocab_use_cases_test.dart   CREATE
```

---

## Tasks (summary — full briefs in task files)

| # | Task | Output |
| --- | --- | --- |
| 01 | Hive + UUID setup | pubspec deps, async main.dart init |
| 02 | Domain entities | CEFRLevel, VocabRecord, Topic (with predefined list) |
| 03 | VocabRepository interface | abstract interface + VocabException |
| 04 | VocabRepositoryImpl | Hive JSON storage + predefined topic seeding |
| 05 | Use cases | 7 use cases — SaveVocab (validates ≤2 topics), Get, Update, Delete, GetTopics, AddTopic, DeleteTopic |
| 06 | Riverpod providers + DI | VocabBankNotifier, TopicsNotifier, app_providers wiring |
| 07 | Save button + SaveVocabSheet | Save/Saved toggle in WordResultWidget; bottom sheet with editable fields + topic picker |
| 08 | App shell + bottom nav | ShellRoute in GoRouter; AppShell NavigationBar |
| 09 | VocabBankScreen | List with topic filter chips, search, empty state |
| 10 | VocabDetailScreen | View + edit meaning/examples/notes/topics; delete |

**Full task briefs:** `docs/superpowers/plans/tasks/plan2-task-{01..10}.md`
**Progress ledger:** `docs/superpowers/plans/tasks/plan2-INDEX.md`

---

## Task 1: Hive + UUID Setup

**Files:**

- Modify: `pubspec.yaml`
- Modify: `lib/main.dart`

**Interfaces:**

- Produces: `Hive.box<String>('vocab_records')` and `Hive.box<String>('topics')` open and ready

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add under `dependencies:`:

```yaml
hive: ^2.2.3
hive_flutter: ^1.1.0
uuid: ^4.5.1
```

- [ ] **Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: resolves without error.

- [ ] **Step 3: Update main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<String>('vocab_records');
  await Hive.openBox<String>('topics');
  runApp(const ProviderScope(child: LexiCoreApp()));
}

class LexiCoreApp extends StatelessWidget {
  const LexiCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LexiCore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
```

- [ ] **Step 4: Verify build**

```bash
flutter analyze lib/main.dart
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "feat: add Hive + uuid dependencies, async Hive init in main"
```

---

## Task 2: Domain Entities

**Files:**

- Create: `lib/features/vocabulary/domain/entities/cefr_level.dart`
- Create: `lib/features/vocabulary/domain/entities/topic.dart`
- Create: `lib/features/vocabulary/domain/entities/vocab_record.dart`

**Interfaces:**

- Produces: `CEFRLevel` enum, `Topic` with `predefined` list + `toJson/fromJson`, `VocabRecord` with `toJson/fromJson/copyWith`

- [ ] **Step 1: Create cefr_level.dart**

```dart
// lib/features/vocabulary/domain/entities/cefr_level.dart
enum CEFRLevel {
  a1, a2, b1, b2, c1, c2;

  String get label => name.toUpperCase();
}
```

- [ ] **Step 2: Create topic.dart**

```dart
// lib/features/vocabulary/domain/entities/topic.dart

final class Topic {
  const Topic({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isPredefined,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final bool isPredefined;
  final DateTime createdAt;

  Topic copyWith({String? name, String? emoji}) => Topic(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        isPredefined: isPredefined,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'isPredefined': isPredefined,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Topic.fromJson(Map<String, dynamic> json) => Topic(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '📌',
        isPredefined: json['isPredefined'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  static final predefined = <Topic>[
    Topic(id: 'daily-life',    name: 'Daily Life',     emoji: '🏠', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'travel',        name: 'Travel',          emoji: '✈️', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'food-drink',    name: 'Food & Drink',    emoji: '🍜', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'business',      name: 'Business',        emoji: '💼', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'technology',    name: 'Technology',      emoji: '💻', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'health',        name: 'Health',          emoji: '🏥', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'education',     name: 'Education',       emoji: '📚', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'entertainment', name: 'Entertainment',   emoji: '🎭', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'nature',        name: 'Nature',          emoji: '🌿', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'emotion',       name: 'Emotion',         emoji: '💭', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'academic',      name: 'Academic',        emoji: '🎓', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'idioms',        name: 'Idioms',          emoji: '💬', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'phrasal-verbs', name: 'Phrasal Verbs',   emoji: '🔗', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'slang',         name: 'Slang',           emoji: '😎', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'social',        name: 'Social/Casual',   emoji: '🗣️', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'sports',        name: 'Sports',          emoji: '⚽', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'art-culture',   name: 'Art & Culture',   emoji: '🎨', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'science',       name: 'Science',         emoji: '🔬', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'law-politics',  name: 'Law & Politics',  emoji: '⚖️', isPredefined: true, createdAt: DateTime(2026)),
    Topic(id: 'other',         name: 'Other',           emoji: '📌', isPredefined: true, createdAt: DateTime(2026)),
  ];
}
```

- [ ] **Step 3: Create vocab_record.dart**

```dart
// lib/features/vocabulary/domain/entities/vocab_record.dart
import '../../.../../dictionary/domain/entities/app_context.dart';
import '../../.../../dictionary/domain/entities/input_type.dart';
import '../../.../../dictionary/domain/entities/language.dart';
import 'cefr_level.dart';

final class VocabRecord {
  const VocabRecord({
    required this.id,
    required this.headword,
    required this.inputType,
    required this.ipa,
    required this.meaning,
    required this.examples,
    required this.personalNotes,
    required this.topicIds,
    required this.targetLanguage,
    required this.cefrLevel,
    required this.activeContext,
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.sm2Repetitions = 0,
    this.sm2EaseFactor = 2.5,
    this.sm2Interval = 1,
  });

  final String id;
  final String headword;
  final InputType inputType; // word or phrase only
  final String ipa;
  final String meaning;
  final List<String> examples;
  final String personalNotes;
  final List<String> topicIds; // max 2
  final Language targetLanguage;
  final CEFRLevel cefrLevel;
  final AppContext activeContext;
  final DateTime createdAt;
  final DateTime updatedAt;
  // SM-2 fields (used in Plan 3)
  final DateTime? nextReviewAt;
  final int sm2Repetitions;
  final double sm2EaseFactor;
  final int sm2Interval;

  VocabRecord copyWith({
    String? meaning,
    List<String>? examples,
    String? personalNotes,
    List<String>? topicIds,
    DateTime? updatedAt,
    DateTime? nextReviewAt,
    int? sm2Repetitions,
    double? sm2EaseFactor,
    int? sm2Interval,
  }) =>
      VocabRecord(
        id: id,
        headword: headword,
        inputType: inputType,
        ipa: ipa,
        meaning: meaning ?? this.meaning,
        examples: examples ?? this.examples,
        personalNotes: personalNotes ?? this.personalNotes,
        topicIds: topicIds ?? this.topicIds,
        targetLanguage: targetLanguage,
        cefrLevel: cefrLevel,
        activeContext: activeContext,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        sm2Repetitions: sm2Repetitions ?? this.sm2Repetitions,
        sm2EaseFactor: sm2EaseFactor ?? this.sm2EaseFactor,
        sm2Interval: sm2Interval ?? this.sm2Interval,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'headword': headword,
        'inputType': inputType.name,
        'ipa': ipa,
        'meaning': meaning,
        'examples': examples,
        'personalNotes': personalNotes,
        'topicIds': topicIds,
        'targetLanguage': targetLanguage.name,
        'cefrLevel': cefrLevel.name,
        'activeContext': activeContext.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'nextReviewAt': nextReviewAt?.toIso8601String(),
        'sm2Repetitions': sm2Repetitions,
        'sm2EaseFactor': sm2EaseFactor,
        'sm2Interval': sm2Interval,
      };

  factory VocabRecord.fromJson(Map<String, dynamic> json) => VocabRecord(
        id: json['id'] as String,
        headword: json['headword'] as String,
        inputType: InputType.values.byName(json['inputType'] as String),
        ipa: json['ipa'] as String,
        meaning: json['meaning'] as String,
        examples: List<String>.from(json['examples'] as List),
        personalNotes: json['personalNotes'] as String? ?? '',
        topicIds: List<String>.from(json['topicIds'] as List),
        targetLanguage: Language.values.byName(json['targetLanguage'] as String),
        cefrLevel: CEFRLevel.values.byName(json['cefrLevel'] as String),
        activeContext: AppContext.values.byName(json['activeContext'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        nextReviewAt: json['nextReviewAt'] != null
            ? DateTime.parse(json['nextReviewAt'] as String)
            : null,
        sm2Repetitions: json['sm2Repetitions'] as int? ?? 0,
        sm2EaseFactor: (json['sm2EaseFactor'] as num?)?.toDouble() ?? 2.5,
        sm2Interval: json['sm2Interval'] as int? ?? 1,
      );
}
```

Note: fix the import path — relative to `lib/features/vocabulary/domain/entities/vocab_record.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import 'cefr_level.dart';
```

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/vocabulary/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/vocabulary/domain/entities/
git commit -m "feat: add VocabRecord, Topic, CEFRLevel domain entities"
```

---

## Task 3: VocabRepository Interface

**Files:**

- Create: `lib/features/vocabulary/domain/repositories/vocab_repository.dart`

**Interfaces:**

- Consumes: `VocabRecord`, `Topic`, `InputType`, `Language`
- Produces: `VocabRepository` abstract interface, `VocabException`

- [ ] **Step 1: Create vocab_repository.dart**

```dart
// lib/features/vocabulary/domain/repositories/vocab_repository.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/topic.dart';
import '../entities/vocab_record.dart';

class VocabException implements Exception {
  const VocabException(this.message);
  final String message;

  @override
  String toString() => 'VocabException: $message';
}

abstract interface class VocabRepository {
  Future<void> save(VocabRecord record);
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
  });
  Future<VocabRecord?> getById(String id);
  Future<void> update(VocabRecord record);
  Future<void> delete(String id);
  Future<bool> existsByHeadword(String headword, Language language);
  Future<List<Topic>> getTopics();
  Future<void> addTopic(Topic topic);
  Future<void> deleteTopic(String id); // auto-moves words to 'other'
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/vocabulary/domain/repositories/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/domain/repositories/
git commit -m "feat: add VocabRepository interface and VocabException"
```

---

## Task 4: VocabRepositoryImpl

**Files:**

- Create: `lib/features/vocabulary/data/repositories/vocab_repository_impl.dart`

**Interfaces:**

- Consumes: `VocabRepository`, `VocabRecord`, `Topic`
- Produces: `VocabRepositoryImpl implements VocabRepository`
  - Constructor: `const VocabRepositoryImpl()`
  - Uses `Hive.box<String>('vocab_records')` and `Hive.box<String>('topics')`

- [ ] **Step 1: Create vocab_repository_impl.dart**

```dart
// lib/features/vocabulary/data/repositories/vocab_repository_impl.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../../domain/repositories/vocab_repository.dart';
import '../../../../features/dictionary/domain/entities/input_type.dart';
import '../../../../features/dictionary/domain/entities/language.dart';

class VocabRepositoryImpl implements VocabRepository {
  const VocabRepositoryImpl();

  static const _vocabBoxName = 'vocab_records';
  static const _topicsBoxName = 'topics';

  Box<String> get _vocabBox => Hive.box<String>(_vocabBoxName);
  Box<String> get _topicsBox => Hive.box<String>(_topicsBoxName);

  @override
  Future<void> save(VocabRecord record) async {
    await _vocabBox.put(record.id, jsonEncode(record.toJson()));
  }

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
  }) async {
    var records = _vocabBox.values
        .map((s) => VocabRecord.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    if (topicId != null) {
      records = records.where((r) => r.topicIds.contains(topicId)).toList();
    }
    if (inputType != null) {
      records = records.where((r) => r.inputType == inputType).toList();
    }
    if (language != null) {
      records = records.where((r) => r.targetLanguage == language).toList();
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  @override
  Future<VocabRecord?> getById(String id) async {
    final raw = _vocabBox.get(id);
    if (raw == null) return null;
    return VocabRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> update(VocabRecord record) async {
    await _vocabBox.put(record.id, jsonEncode(record.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    await _vocabBox.delete(id);
  }

  @override
  Future<bool> existsByHeadword(String headword, Language language) async {
    return _vocabBox.values.any((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      return map['headword'] == headword &&
          map['targetLanguage'] == language.name;
    });
  }

  @override
  Future<List<Topic>> getTopics() async {
    if (_topicsBox.isEmpty) {
      await _seedTopics();
    }
    final topics = _topicsBox.values
        .map((s) => Topic.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    topics.sort((a, b) {
      if (a.isPredefined && !b.isPredefined) return -1;
      if (!a.isPredefined && b.isPredefined) return 1;
      return a.name.compareTo(b.name);
    });
    return topics;
  }

  @override
  Future<void> addTopic(Topic topic) async {
    await _topicsBox.put(topic.id, jsonEncode(topic.toJson()));
  }

  @override
  Future<void> deleteTopic(String id) async {
    // Move all words with this topic to 'other'
    final all = await getAll();
    for (final record in all) {
      if (record.topicIds.contains(id)) {
        final newTopicIds = record.topicIds.where((t) => t != id).toList();
        if (newTopicIds.isEmpty) newTopicIds.add('other');
        await update(record.copyWith(
          topicIds: newTopicIds,
          updatedAt: DateTime.now(),
        ));
      }
    }
    await _topicsBox.delete(id);
  }

  Future<void> _seedTopics() async {
    for (final topic in Topic.predefined) {
      await _topicsBox.put(topic.id, jsonEncode(topic.toJson()));
    }
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/vocabulary/data/
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/data/
git commit -m "feat: add VocabRepositoryImpl with Hive JSON storage and topic seeding"
```

---

## Task 5: Use Cases

**Files:**

- Create: `lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/update_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/get_topics_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/add_topic_use_case.dart`
- Create: `lib/features/vocabulary/domain/use_cases/delete_topic_use_case.dart`
- Create: `test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart`

**Interfaces:**

- Consumes: `VocabRepository`, `VocabRecord`, `Topic`
- Produces: 7 use case classes (see below)

**Produces:**

```dart
class SaveVocabUseCase {
  const SaveVocabUseCase(VocabRepository repository);
  // Validates topicIds.length <= 2 and inputType != sentence
  Future<void> execute(VocabRecord record);
}

class GetVocabListUseCase {
  const GetVocabListUseCase(VocabRepository repository);
  Future<List<VocabRecord>> execute({String? topicId, InputType? inputType, Language? language});
}

class UpdateVocabUseCase {
  const UpdateVocabUseCase(VocabRepository repository);
  // Validates topicIds.length <= 2; sets updatedAt = now
  Future<void> execute(VocabRecord record);
}

class DeleteVocabUseCase {
  const DeleteVocabUseCase(VocabRepository repository);
  Future<void> execute(String id);
}

class GetTopicsUseCase {
  const GetTopicsUseCase(VocabRepository repository);
  Future<List<Topic>> execute();
}

class AddTopicUseCase {
  const AddTopicUseCase(VocabRepository repository);
  // Validates name not empty; creates Topic with uuid
  Future<Topic> execute({required String name, required String emoji});
}

class DeleteTopicUseCase {
  const DeleteTopicUseCase(VocabRepository repository);
  // Throws VocabException if topic.isPredefined
  Future<void> execute(String topicId, {required bool isPredefined});
}
```

- [ ] **Step 1: Write failing tests**

```dart
// test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/update_vocab_use_case.dart';

import 'vocab_use_cases_test.mocks.dart';

@GenerateMocks([VocabRepository])
void main() {
  late MockVocabRepository mockRepo;

  final now = DateTime(2026, 6, 30);

  VocabRecord makeRecord({List<String> topicIds = const ['daily-life'], InputType type = InputType.word}) =>
      VocabRecord(
        id: 'abc',
        headword: 'allow',
        inputType: type,
        ipa: '/əˈlaʊ/',
        meaning: 'cho phép',
        examples: const ['She allowed him to go.'],
        personalNotes: '',
        topicIds: topicIds,
        targetLanguage: Language.english,
        cefrLevel: CEFRLevel.b1,
        activeContext: AppContext.general,
        createdAt: now,
        updatedAt: now,
      );

  setUp(() {
    mockRepo = MockVocabRepository();
    when(mockRepo.save(any)).thenAnswer((_) async {});
    when(mockRepo.update(any)).thenAnswer((_) async {});
    when(mockRepo.deleteTopic(any)).thenAnswer((_) async {});
    when(mockRepo.addTopic(any)).thenAnswer((_) async {});
  });

  group('SaveVocabUseCase', () {
    test('saves valid word record', () async {
      final useCase = SaveVocabUseCase(mockRepo);
      await useCase.execute(makeRecord());
      verify(mockRepo.save(any)).called(1);
    });

    test('throws if topicIds length > 2', () async {
      final useCase = SaveVocabUseCase(mockRepo);
      expect(
        () => useCase.execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });

    test('throws if inputType is sentence', () async {
      final useCase = SaveVocabUseCase(mockRepo);
      expect(
        () => useCase.execute(makeRecord(type: InputType.sentence)),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.save(any));
    });
  });

  group('UpdateVocabUseCase', () {
    test('throws if topicIds > 2', () async {
      final useCase = UpdateVocabUseCase(mockRepo);
      expect(
        () => useCase.execute(makeRecord(topicIds: ['a', 'b', 'c'])),
        throwsA(isA<VocabException>()),
      );
    });

    test('updates with fresh updatedAt', () async {
      final useCase = UpdateVocabUseCase(mockRepo);
      final record = makeRecord();
      await useCase.execute(record);
      final captured = verify(mockRepo.update(captureAny)).captured.first as VocabRecord;
      expect(captured.updatedAt.isAfter(now) || captured.updatedAt == now, isTrue);
    });
  });

  group('DeleteTopicUseCase', () {
    test('throws when deleting a predefined topic', () {
      final useCase = DeleteTopicUseCase(mockRepo);
      expect(
        () => useCase.execute('daily-life', isPredefined: true),
        throwsA(isA<VocabException>()),
      );
      verifyNever(mockRepo.deleteTopic(any));
    });

    test('allows deleting custom topic', () async {
      final useCase = DeleteTopicUseCase(mockRepo);
      await useCase.execute('my-custom', isPredefined: false);
      verify(mockRepo.deleteTopic('my-custom')).called(1);
    });
  });

  group('AddTopicUseCase', () {
    test('throws if name is empty', () {
      final useCase = AddTopicUseCase(mockRepo);
      expect(
        () => useCase.execute(name: '   ', emoji: '⭐'),
        throwsA(isA<VocabException>()),
      );
    });

    test('creates topic with non-empty UUID id', () async {
      final useCase = AddTopicUseCase(mockRepo);
      final topic = await useCase.execute(name: 'My Topic', emoji: '⭐');
      expect(topic.id, isNotEmpty);
      expect(topic.name, 'My Topic');
      expect(topic.isPredefined, isFalse);
    });
  });
}
```

- [ ] **Step 2: Generate mocks**

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: Run tests — expect FAIL**

```bash
flutter test test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
```

Expected: compile error — use case classes not defined.

- [ ] **Step 4: Implement use cases**

**save_vocab_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/save_vocab_use_case.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class SaveVocabUseCase {
  const SaveVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.inputType == InputType.sentence) {
      throw const VocabException('Sentences cannot be saved to Vocabulary Bank.');
    }
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.save(record);
  }
}
```

**get_vocab_list_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class GetVocabListUseCase {
  const GetVocabListUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<VocabRecord>> execute({
    String? topicId,
    InputType? inputType,
    Language? language,
  }) =>
      _repo.getAll(topicId: topicId, inputType: inputType, language: language);
}
```

**update_vocab_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/update_vocab_use_case.dart
import '../entities/vocab_record.dart';
import '../repositories/vocab_repository.dart';

class UpdateVocabUseCase {
  const UpdateVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(VocabRecord record) {
    if (record.topicIds.length > 2) {
      throw const VocabException('A word can have at most 2 topic tags.');
    }
    return _repo.update(record.copyWith(updatedAt: DateTime.now()));
  }
}
```

**delete_vocab_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/delete_vocab_use_case.dart
import '../repositories/vocab_repository.dart';

class DeleteVocabUseCase {
  const DeleteVocabUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String id) => _repo.delete(id);
}
```

**get_topics_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/get_topics_use_case.dart
import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class GetTopicsUseCase {
  const GetTopicsUseCase(this._repo);
  final VocabRepository _repo;

  Future<List<Topic>> execute() => _repo.getTopics();
}
```

**add_topic_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/add_topic_use_case.dart
import 'package:uuid/uuid.dart';
import '../entities/topic.dart';
import '../repositories/vocab_repository.dart';

class AddTopicUseCase {
  const AddTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<Topic> execute({required String name, required String emoji}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const VocabException('Topic name cannot be empty.');
    }
    final topic = Topic(
      id: const Uuid().v4(),
      name: trimmed,
      emoji: emoji.isEmpty ? '📌' : emoji,
      isPredefined: false,
      createdAt: DateTime.now(),
    );
    await _repo.addTopic(topic);
    return topic;
  }
}
```

**delete_topic_use_case.dart:**

```dart
// lib/features/vocabulary/domain/use_cases/delete_topic_use_case.dart
import '../repositories/vocab_repository.dart';

class DeleteTopicUseCase {
  const DeleteTopicUseCase(this._repo);
  final VocabRepository _repo;

  Future<void> execute(String topicId, {required bool isPredefined}) {
    if (isPredefined) {
      throw const VocabException('Predefined topics cannot be deleted.');
    }
    return _repo.deleteTopic(topicId);
  }
}
```

- [ ] **Step 5: Run tests — expect PASS**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/features/vocabulary/domain/use_cases/vocab_use_cases_test.dart
```

Expected: all tests pass.

- [ ] **Step 6: Run full suite**

```bash
flutter test
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lib/features/vocabulary/domain/use_cases/ \
        test/features/vocabulary/domain/use_cases/
git commit -m "feat: add 7 vocab use cases with validation (max 2 topics, no sentences)"
```

---

## Task 6: Riverpod Providers + DI

**Files:**

- Create: `lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart`
- Create: `lib/features/vocabulary/presentation/providers/topics_provider.dart`
- Modify: `lib/core/di/app_providers.dart`

**Interfaces:**

- Consumes: `VocabRepositoryImpl`, all 7 use cases
- Produces:
  - `vocabRepositoryProvider` → `VocabRepository`
  - `vocabBankNotifierProvider` → `AsyncValue<List<VocabRecord>>`
  - `VocabBankNotifier` methods: `save(VocabRecord)`, `update(VocabRecord)`, `delete(String)`
  - `topicsNotifierProvider` → `AsyncValue<List<Topic>>`
  - `TopicsNotifier` methods: `addTopic(String name, String emoji)`, `deleteTopic(String id, bool isPredefined)`

- [ ] **Step 1: Create vocab_bank_provider.dart**

```dart
// lib/features/vocabulary/presentation/providers/vocab_bank_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/vocab_record.dart';

part 'vocab_bank_provider.g.dart';

@riverpod
class VocabBankNotifier extends _$VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() =>
      ref.read(getVocabListUseCaseProvider).execute();

  Future<void> save(VocabRecord record) async {
    await ref.read(saveVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> update(VocabRecord record) async {
    await ref.read(updateVocabUseCaseProvider).execute(record);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(deleteVocabUseCaseProvider).execute(id);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 2: Create topics_provider.dart**

```dart
// lib/features/vocabulary/presentation/providers/topics_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/topic.dart';

part 'topics_provider.g.dart';

@riverpod
class TopicsNotifier extends _$TopicsNotifier {
  @override
  Future<List<Topic>> build() =>
      ref.read(getTopicsUseCaseProvider).execute();

  Future<void> addTopic(String name, String emoji) async {
    await ref.read(addTopicUseCaseProvider).execute(name: name, emoji: emoji);
    ref.invalidateSelf();
  }

  Future<void> deleteTopic(String id, {required bool isPredefined}) async {
    await ref.read(deleteTopicUseCaseProvider).execute(id, isPredefined: isPredefined);
    ref.invalidateSelf();
    ref.invalidate(vocabBankNotifierProvider);
  }
}
```

- [ ] **Step 3: Update app_providers.dart**

Add to the existing `lib/core/di/app_providers.dart` (keep all existing providers, append these):

```dart
// --- Vocabulary ---
import '../../features/vocabulary/data/repositories/vocab_repository_impl.dart';
import '../../features/vocabulary/domain/repositories/vocab_repository.dart';
import '../../features/vocabulary/domain/use_cases/add_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_topic_use_case.dart';
import '../../features/vocabulary/domain/use_cases/delete_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_topics_use_case.dart';
import '../../features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import '../../features/vocabulary/domain/use_cases/save_vocab_use_case.dart';
import '../../features/vocabulary/domain/use_cases/update_vocab_use_case.dart';
import '../../features/vocabulary/presentation/providers/topics_provider.dart';
import '../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';

@riverpod
VocabRepository vocabRepository(VocabRepositoryRef ref) =>
    const VocabRepositoryImpl();

@riverpod
SaveVocabUseCase saveVocabUseCase(SaveVocabUseCaseRef ref) =>
    SaveVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetVocabListUseCase getVocabListUseCase(GetVocabListUseCaseRef ref) =>
    GetVocabListUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
UpdateVocabUseCase updateVocabUseCase(UpdateVocabUseCaseRef ref) =>
    UpdateVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteVocabUseCase deleteVocabUseCase(DeleteVocabUseCaseRef ref) =>
    DeleteVocabUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
GetTopicsUseCase getTopicsUseCase(GetTopicsUseCaseRef ref) =>
    GetTopicsUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
AddTopicUseCase addTopicUseCase(AddTopicUseCaseRef ref) =>
    AddTopicUseCase(ref.watch(vocabRepositoryProvider));

@riverpod
DeleteTopicUseCase deleteTopicUseCase(DeleteTopicUseCaseRef ref) =>
    DeleteTopicUseCase(ref.watch(vocabRepositoryProvider));
```

- [ ] **Step 4: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generates `.g.dart` files with no errors.

- [ ] **Step 5: Verify**

```bash
flutter analyze lib/features/vocabulary/presentation/providers/ lib/core/di/
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add lib/features/vocabulary/presentation/providers/ \
        lib/core/di/app_providers.dart
git commit -m "feat: add VocabBankNotifier, TopicsNotifier, DI vocab providers"
```

---

## Task 7: Save Button + SaveVocabSheet

**Files:**

- Create: `lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart`
- Modify: `lib/features/dictionary/presentation/widgets/word_result_widget.dart`

**Interfaces:**

- Consumes:
  - `vocabBankNotifierProvider.notifier.save(VocabRecord)`
  - `topicsNotifierProvider` → `AsyncValue<List<Topic>>`
  - `userSettingsNotifierProvider` → `UserSettingsState` (for targetLanguage, cefrLevel, activeContext)
  - `WordPhraseResult` fields: headword, inputType, ipa, meaning, examples, suggestedTopics
  - `VocabRecord` entity

- [ ] **Step 1: Create save_vocab_sheet.dart**

```dart
// lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/topics_provider.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

class SaveVocabSheet extends ConsumerStatefulWidget {
  const SaveVocabSheet({super.key, required this.result});
  final WordPhraseResult result;

  @override
  ConsumerState<SaveVocabSheet> createState() => _SaveVocabSheetState();
}

class _SaveVocabSheetState extends ConsumerState<SaveVocabSheet> {
  late final TextEditingController _meaningCtrl;
  late final TextEditingController _notesCtrl;
  late List<String> _selectedTopicIds;
  late List<TextEditingController> _exampleCtrls;

  @override
  void initState() {
    super.initState();
    _meaningCtrl = TextEditingController(text: widget.result.meaning);
    _notesCtrl = TextEditingController();
    _exampleCtrls = widget.result.examples
        .map((e) => TextEditingController(text: e))
        .toList();
    _selectedTopicIds = [];
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _exampleCtrls) c.dispose();
    super.dispose();
  }

  void _toggleTopic(String id) {
    setState(() {
      if (_selectedTopicIds.contains(id)) {
        _selectedTopicIds.remove(id);
      } else if (_selectedTopicIds.length < 2) {
        _selectedTopicIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    final settings = ref.read(userSettingsNotifierProvider);
    final record = VocabRecord(
      id: const Uuid().v4(),
      headword: widget.result.headword,
      inputType: widget.result.inputType,
      ipa: widget.result.ipa,
      meaning: _meaningCtrl.text.trim(),
      examples: _exampleCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
      personalNotes: _notesCtrl.text.trim(),
      topicIds: _selectedTopicIds,
      targetLanguage: settings.targetLanguage,
      cefrLevel: CEFRLevel.b1,
      activeContext: settings.activeContext,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(vocabBankNotifierProvider.notifier).save(record);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Save "${widget.result.headword}"',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Meaning', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                TextField(
                  controller: _meaningCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Text('Examples', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                ..._exampleCtrls.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: e.value,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _exampleCtrls.removeAt(e.key)),
                          ),
                        ]),
                      ),
                    ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add example'),
                  onPressed: () => setState(() => _exampleCtrls.add(TextEditingController())),
                ),
                const SizedBox(height: 16),
                Text('Topics (max 2)', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                topicsAsync.when(
                  data: (topics) {
                    // pre-select topics matching Gemini suggestions
                    if (_selectedTopicIds.isEmpty && widget.result.suggestedTopics.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          for (final suggestion in widget.result.suggestedTopics) {
                            final match = topics.where(
                              (t) => t.name.toLowerCase() == suggestion.toLowerCase(),
                            );
                            if (match.isNotEmpty && _selectedTopicIds.length < 2) {
                              _selectedTopicIds.add(match.first.id);
                            }
                          }
                        });
                      });
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topics.map((topic) {
                        final selected = _selectedTopicIds.contains(topic.id);
                        final disabled = !selected && _selectedTopicIds.length >= 2;
                        return FilterChip(
                          label: Text('${topic.emoji} ${topic.name}'),
                          selected: selected,
                          onSelected: disabled ? null : (_) => _toggleTopic(topic.id),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text(e.toString()),
                ),
                const SizedBox(height: 16),
                Text('Personal notes', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Add a note...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Save to Vocab Bank'),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Modify word_result_widget.dart**

Read the existing file first, then add a Save button at the bottom of the Card. The widget needs to:
1. Check if the headword is already saved via `vocabBankNotifierProvider`
2. Show "Save" button if not saved, "Saved ✓" (disabled) if saved
3. On tap: open `SaveVocabSheet` via `showModalBottomSheet`

Add these to the bottom of the existing Column in `WordResultWidget`:

```dart
// Add after the suggestedTopics Wrap block:
const SizedBox(height: 8),
_SaveButton(result: result),
```

And add this widget class (private, defined in the same file):

```dart
class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.result});
  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final settings = ref.read(userSettingsNotifierProvider);

    final isSaved = vocabAsync.valueOrNull?.any(
          (r) => r.headword == result.headword &&
              r.targetLanguage == settings.targetLanguage,
        ) ??
        false;

    if (isSaved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green),
          SizedBox(width: 4),
          Text('Saved', style: TextStyle(color: Colors.green)),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
        label: const Text('Save'),
        onPressed: () async {
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SaveVocabSheet(result: result),
          );
        },
      ),
    );
  }
}
```

Don't forget to add the import at the top of `word_result_widget.dart`:

```dart
import '../../../../core/di/app_providers.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'save_vocab_sheet.dart';
```

- [ ] **Step 3: Verify compilation**

```bash
flutter analyze lib/features/dictionary/presentation/widgets/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/dictionary/presentation/widgets/save_vocab_sheet.dart \
        lib/features/dictionary/presentation/widgets/word_result_widget.dart
git commit -m "feat: add Save button to WordResultWidget and SaveVocabSheet bottom sheet"
```

---

## Task 8: App Shell + Bottom Navigation

**Files:**

- Create: `lib/core/widgets/app_shell.dart`
- Modify: `lib/core/router/app_router.dart`

**Interfaces:**

- Consumes: GoRouter `ShellRoute`; `LookupScreen`, `VocabBankScreen`
- Produces: `AppShell` widget; updated `appRouter` with ShellRoute and `/vocab`, `/vocab/:id` paths

- [ ] **Step 1: Create app_shell.dart**

```dart
// lib/core/widgets/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/vocab')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/vocab');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Dictionary',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Vocab Bank',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update app_router.dart**

```dart
// lib/core/router/app_router.dart
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LookupScreen(),
        ),
        GoRoute(
          path: '/vocab',
          builder: (context, state) => const VocabBankScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => VocabDetailScreen(
                id: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);
```

Note: `VocabBankScreen` and `VocabDetailScreen` will be created in Tasks 9 & 10. Create placeholder implementations now:

Placeholder `vocab_bank_screen.dart`:
```dart
import 'package:flutter/material.dart';
class VocabBankScreen extends StatelessWidget {
  const VocabBankScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Vocab Bank — coming soon')));
}
```

Placeholder `vocab_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';
class VocabDetailScreen extends StatelessWidget {
  const VocabDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: Center(child: Text('Detail: $id')));
}
```

- [ ] **Step 3: Verify build**

```bash
flutter analyze lib/core/
flutter analyze lib/features/vocabulary/presentation/screens/
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/core/widgets/ lib/core/router/app_router.dart \
        lib/features/vocabulary/presentation/screens/
git commit -m "feat: add AppShell with bottom nav (Dictionary | Vocab Bank), ShellRoute in GoRouter"
```

---

## Task 9: VocabBankScreen

**Files:**

- Modify: `lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart` (replace placeholder)

**Interfaces:**

- Consumes:
  - `vocabBankNotifierProvider` → `AsyncValue<List<VocabRecord>>`
  - `topicsNotifierProvider` → `AsyncValue<List<Topic>>`
  - `VocabRecord` fields: id, headword, ipa, meaning, inputType, topicIds, targetLanguage, createdAt

- [ ] **Step 1: Replace placeholder with full VocabBankScreen**

```dart
// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/vocab_record.dart';
import '../providers/topics_provider.dart';
import '../providers/vocab_bank_provider.dart';

class VocabBankScreen extends ConsumerStatefulWidget {
  const VocabBankScreen({super.key});

  @override
  ConsumerState<VocabBankScreen> createState() => _VocabBankScreenState();
}

class _VocabBankScreenState extends ConsumerState<VocabBankScreen> {
  String? _selectedTopicId;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocab Bank'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add custom topic',
            onPressed: () => _showAddTopicDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Search saved words...',
              onChanged: (v) => setState(() => _searchQuery = v),
              leading: const Icon(Icons.search),
            ),
          ),
          // Topic filter chips
          topicsAsync.when(
            data: (topics) => SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedTopicId == null,
                      onSelected: (_) => setState(() => _selectedTopicId = null),
                    ),
                  ),
                  ...topics.map((t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text('${t.emoji} ${t.name}'),
                          selected: _selectedTopicId == t.id,
                          onSelected: (_) => setState(() =>
                              _selectedTopicId = _selectedTopicId == t.id ? null : t.id),
                        ),
                      )),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
          ),
          const Divider(height: 1),
          // Vocab list
          Expanded(
            child: vocabAsync.when(
              data: (records) {
                var filtered = records;
                if (_selectedTopicId != null) {
                  filtered = filtered.where((r) => r.topicIds.contains(_selectedTopicId)).toList();
                }
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filtered = filtered
                      .where((r) =>
                          r.headword.toLowerCase().contains(q) ||
                          r.meaning.toLowerCase().contains(q))
                      .toList();
                }
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No words saved yet.\nLook one up and tap Save!',
                        textAlign: TextAlign.center),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _VocabCard(record: filtered[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📌');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Topic'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Topic name')),
          TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(topicsNotifierProvider.notifier)
                  .addTopic(nameCtrl.text, emojiCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    emojiCtrl.dispose();
  }
}

class _VocabCard extends StatelessWidget {
  const _VocabCard({required this.record});
  final VocabRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () => context.push('/vocab/${record.id}'),
        title: Text(record.headword,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.ipa.isNotEmpty)
              Text(record.ipa,
                  style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            Text(record.meaning, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: Chip(
          label: Text(record.inputType.name,
              style: const TextStyle(fontSize: 11)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        isThreeLine: true,
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

```bash
flutter analyze lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
git commit -m "feat: implement VocabBankScreen with topic filter, search, and word list"
```

---

## Task 10: VocabDetailScreen

**Files:**

- Modify: `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart` (replace placeholder)

**Interfaces:**

- Consumes:
  - `vocabRepositoryProvider` → `VocabRepository` (via `getById`)
  - `vocabBankNotifierProvider.notifier.update(VocabRecord)`
  - `vocabBankNotifierProvider.notifier.delete(String)`
  - `topicsNotifierProvider` → `AsyncValue<List<Topic>>`
  - `ttsServiceProvider` → `TtsService`
  - `userSettingsNotifierProvider` → `UserSettingsState`
  - `VocabRecord.copyWith(...)`

- [ ] **Step 1: Replace placeholder with full VocabDetailScreen**

```dart
// lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/vocab_record.dart';
import '../providers/topics_provider.dart';
import '../providers/vocab_bank_provider.dart';

class VocabDetailScreen extends ConsumerStatefulWidget {
  const VocabDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends ConsumerState<VocabDetailScreen> {
  VocabRecord? _record;
  bool _editing = false;
  late TextEditingController _meaningCtrl;
  late TextEditingController _notesCtrl;
  late List<TextEditingController> _exampleCtrls;
  late List<String> _selectedTopicIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    final repo = ref.read(vocabRepositoryProvider);
    final record = await repo.getById(widget.id);
    setState(() {
      _record = record;
      _loading = false;
      if (record != null) _initEditors(record);
    });
  }

  void _initEditors(VocabRecord r) {
    _meaningCtrl = TextEditingController(text: r.meaning);
    _notesCtrl = TextEditingController(text: r.personalNotes);
    _exampleCtrls = r.examples.map((e) => TextEditingController(text: e)).toList();
    _selectedTopicIds = List.from(r.topicIds);
  }

  @override
  void dispose() {
    _meaningCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _exampleCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _saveEdit() async {
    if (_record == null) return;
    final updated = _record!.copyWith(
      meaning: _meaningCtrl.text.trim(),
      examples: _exampleCtrls
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      personalNotes: _notesCtrl.text.trim(),
      topicIds: _selectedTopicIds,
      updatedAt: DateTime.now(),
    );
    try {
      await ref.read(vocabBankNotifierProvider.notifier).update(updated);
      setState(() {
        _record = updated;
        _editing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete word?'),
        content: Text('Remove "${_record!.headword}" from Vocab Bank?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(vocabBankNotifierProvider.notifier).delete(widget.id);
      if (mounted) context.pop();
    }
  }

  void _toggleTopic(String id) {
    setState(() {
      if (_selectedTopicIds.contains(id)) {
        _selectedTopicIds.remove(id);
      } else if (_selectedTopicIds.length < 2) {
        _selectedTopicIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_record == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));

    final r = _record!;
    final theme = Theme.of(context);
    final tts = ref.read(ttsServiceProvider);
    final settings = ref.read(userSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(r.headword),
        actions: [
          if (!_editing) ...[
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _editing = true)),
            IconButton(icon: const Icon(Icons.delete_outline), color: Colors.red, onPressed: _delete),
          ] else ...[
            TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
            TextButton(onPressed: _saveEdit, child: const Text('Save')),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headword + IPA + TTS
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.headword,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (r.ipa.isNotEmpty)
                        Text(r.ipa,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.secondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () => tts.speak(r.headword, settings.targetLanguage),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Meaning
            Text('Meaning', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            _editing
                ? TextField(
                    controller: _meaningCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  )
                : Text(r.meaning, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            // Examples
            Text('Examples', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (_editing) ...[
              ..._exampleCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _exampleCtrls.removeAt(e.key)),
                      ),
                    ]),
                  )),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add example'),
                onPressed: () => setState(() => _exampleCtrls.add(TextEditingController())),
              ),
            ] else
              ...r.examples.map((ex) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                          child: Text(ex,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontStyle: FontStyle.italic))),
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 18),
                        onPressed: () => tts.speak(ex, settings.targetLanguage),
                      ),
                    ]),
                  )),
            const SizedBox(height: 16),
            // Topics
            Text('Topics', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            if (_editing)
              ref.watch(topicsNotifierProvider).when(
                    data: (topics) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: topics.map((t) {
                        final selected = _selectedTopicIds.contains(t.id);
                        final disabled = !selected && _selectedTopicIds.length >= 2;
                        return FilterChip(
                          label: Text('${t.emoji} ${t.name}'),
                          selected: selected,
                          onSelected: disabled ? null : (_) => _toggleTopic(t.id),
                        );
                      }).toList(),
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text(e.toString()),
                  )
            else
              Wrap(
                spacing: 8,
                children: r.topicIds
                    .map((id) => Chip(label: Text(id), visualDensity: VisualDensity.compact))
                    .toList(),
              ),
            const SizedBox(height: 16),
            // Personal notes
            Text('Personal notes', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            _editing
                ? TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a note...',
                      border: OutlineInputBorder(),
                    ),
                  )
                : r.personalNotes.isEmpty
                    ? Text('No notes yet.',
                        style: TextStyle(color: theme.colorScheme.outline))
                    : Text(r.personalNotes),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run full test suite**

```bash
flutter test
```

Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart
git commit -m "feat: implement VocabDetailScreen with view and edit modes"
```

---

## Self-Review

**Spec coverage:**

- ✅ §4.2 VocabRecord — all fields present (headword, IPA, meaning, examples, topics×2 max, personalNotes, language, type)
- ✅ §4.3 Topic system — 20 predefined (not deletable), custom (deletable, words → 'other')
- ✅ §4.2 "Editable after save" — meaning, examples, topics, notes editable in VocabDetailScreen
- ✅ §4.3 "max 2 topic tags" — enforced in use case + UI chips
- ✅ §4.1 "Save button + Edit before save" — SaveVocabSheet allows editing meaning/examples/notes
- ✅ SM-2 fields stubbed in VocabRecord for Plan 3 compatibility
- ✅ Filter by topic — VocabBankScreen topic chips
- ✅ Search within saved entries — VocabBankScreen search bar
- ⚠️ Filter by type/language pair — VocabBankScreen has UI space but only topic+search implemented (type/language filter deferred to Plan 4)

**Type consistency check:**

- `VocabRecord.topicIds: List<String>` matches repo interface `getAll(topicId: String?)` ✅
- `Topic.id` matches usage in `topicIds` list ✅
- `DeleteTopicUseCase.execute(String topicId, {required bool isPredefined})` matches `TopicsNotifier.deleteTopic(String, bool)` ✅
- `VocabBankNotifier` provider name matches import in `save_vocab_sheet.dart` and `vocab_bank_screen.dart` ✅
