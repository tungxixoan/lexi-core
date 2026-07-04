# Plan 2 — Task 02: Domain Entities

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01

## Global Constraints
(see `plan2-global-constraints.md`)
- All domain entities: immutable, `const` constructors, no public setters; mutation via `copyWith`
- Topic constraint: each VocabRecord max 2 topic tags
- Sentences (`InputType.sentence`) are **never** saved to VocabBank

## What This Task Delivers
Three new domain entity files: `CEFRLevel` enum, `Topic` (with 20 predefined entries + JSON serialization), and `VocabRecord` (with all Plan 2 fields + SM-2 stubs for Plan 3 + JSON serialization).

## Files
- Create: `lib/features/vocabulary/domain/entities/cefr_level.dart`
- Create: `lib/features/vocabulary/domain/entities/topic.dart`
- Create: `lib/features/vocabulary/domain/entities/vocab_record.dart`

## Interfaces From Prior Tasks

```dart
// lib/features/dictionary/domain/entities/input_type.dart
enum InputType { word, phrase, sentence }

// lib/features/dictionary/domain/entities/app_context.dart
enum AppContext { general, business, technology, travel, foodDrink, health, academic, socialCasual }

// lib/features/dictionary/domain/entities/language.dart
enum Language { english, chinese, korean, japanese }
```

## Produces (used by Tasks 03, 04, 05, 06)

```dart
enum CEFRLevel { a1, a2, b1, b2, c1, c2 }

final class Topic {
  const Topic({required String id, required String name, required String emoji,
                required bool isPredefined, required DateTime createdAt});
  Topic copyWith({String? name, String? emoji});
  Map<String, dynamic> toJson();
  factory Topic.fromJson(Map<String, dynamic> json);
  static final List<Topic> predefined;  // 20 items, ids: 'daily-life', 'travel', ...
}

final class VocabRecord {
  const VocabRecord({required String id, required String headword,
    required InputType inputType, required String ipa, required String meaning,
    required List<String> examples, required String personalNotes,
    required List<String> topicIds, required Language targetLanguage,
    required CEFRLevel cefrLevel, required AppContext activeContext,
    required DateTime createdAt, required DateTime updatedAt,
    DateTime? nextReviewAt, int sm2Repetitions, double sm2EaseFactor, int sm2Interval});
  VocabRecord copyWith({String? meaning, List<String>? examples,
    String? personalNotes, List<String>? topicIds, DateTime? updatedAt,
    DateTime? nextReviewAt, int? sm2Repetitions, double? sm2EaseFactor, int? sm2Interval});
  Map<String, dynamic> toJson();
  factory VocabRecord.fromJson(Map<String, dynamic> json);
}
```

## Steps

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
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/input_type.dart';
import '../../../dictionary/domain/entities/language.dart';
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
  final InputType inputType; // word or phrase only — sentences not saveable
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
  // SM-2 fields — used by Plan 3 (Spaced Repetition); stored from Plan 2 onwards
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

- [ ] **Step 4: Verify**

```bash
flutter analyze lib/features/vocabulary/domain/entities/
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/vocabulary/domain/entities/
git commit -m "feat(plan2): add CEFRLevel, Topic (20 predefined), VocabRecord domain entities"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Analyze: flutter analyze output (no errors)
Concerns: (if any)
