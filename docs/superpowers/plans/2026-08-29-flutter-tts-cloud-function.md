# Flutter TTS Cloud Function Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flutter plays pronunciation and listening audio through the same self-hosted Piper Cloud Functions (`getPronunciation`, `synthesizeSpeech`) `apps/web/` already uses, instead of on-device `flutter_tts` — with zh/ko/ja pronunciation/listening disabled to match web's own vi/en-only ceiling, and Nghe hiểu's two-speaker differentiation upgraded from a pitch hack to real Piper voices.

**Architecture:** `TtsService` splits into `pronounce()` (cached, via `getPronunciation`) and `synthesize()` (uncached, via `synthesizeSpeech`), both implemented by a new `CloudTtsService` that calls the existing `CloudFunctionCaller` seam and plays the result with a new `audioplayers` dependency. `Language.ttsCloudCode` gates every UI entry point (pronunciation buttons hidden, Nghe chép/Nghe hiểu session creation blocked) for languages Piper has no voice for. `ListeningPassage`/`ListeningTurn` gain a `gender` field (ported from `apps/web/`'s prompt/entity) so a new `assignVoices()` can pick 2 real distinct Piper voices instead of pitch-shifting.

**Tech Stack:** Flutter/Dart, Riverpod (`riverpod_generator`), `audioplayers` (new dependency), `cloud_functions` (already added in the AI-settings-sync plan), `mocktail` (test).

## Global Constraints

- Piper only has voices for Vietnamese and English (`functions/src/getPronunciation.ts`'s `VOICE_IDS`, `functions/src/synthesizeSpeech.ts`'s `language: "vi"|"en"`). No audio (pronunciation or Nghe chép/Nghe hiểu) is ever requested for Chinese/Korean/Japanese — gated via `Language.ttsCloudCode` returning `null` for those three.
- `getPronunciation` is for cached, static dictionary/vocab text (word or sentence tier). `synthesizeSpeech` is for uncached, freshly AI-generated text (Nghe chép sentences, Nghe hiểu turns). Never use one Cloud Function where the spec calls for the other.
- Every Cloud Functions call goes through the existing `lib/core/services/cloud_function_caller.dart` seam (`CloudFunctionCaller`/`FirebaseCloudFunctionCaller`, region `asia-southeast1`) — do not construct a new calling mechanism.
- `pronounce`/`synthesize` must block until playback finishes (matches `flutter_tts`'s `awaitSpeakCompletion(true)`, which `dictation_practice_provider.dart`/`listening_comprehension_provider.dart` both rely on) — resolve on either natural completion or an external `stop()` call, never leave a caller awaiting forever.
- `_rateFor(speedMultiplier)` in both listening providers must pass the multiplier straight through (1.0 = normal speed) — NOT the old `(0.5 * speedMultiplier).clamp(0.0, 1.0)` `flutter_tts`-specific scale, which would play audio at the wrong speed under `audioplayers`.
- `flutter_tts` is removed entirely: the dependency in `pubspec.yaml`, the `flutterTtsProvider` in `app_providers.dart`, and every remaining reference.
- No new error-display UI for TTS failures — catch and no-op (log only), matching the lack of any error UI at these call sites today.

---

## Task 1: Nghe hiểu voice/gender infrastructure

**Files:**
- Modify: `lib/features/listening/domain/entities/listening_passage.dart`
- Modify: `lib/features/listening/data/sources/listening_passage_source.dart`
- Modify: `test/features/listening/domain/entities/listening_passage_test.dart`
- Modify: `test/features/listening/data/sources/listening_passage_source_test.dart`

**Interfaces:**
- Produces: `ListeningTurn(speaker, gender, text)` (new optional `gender` field), `ListeningPassage(..., speakerGenders)` (new `Map<String, String> speakerGenders`, default `const {}`), `String speakerKey(String? speaker)`, `Map<String, String> assignVoices(ListeningPassage passage)` — all in `listening_passage.dart`. Task 2 imports and uses `speakerKey`/`assignVoices` in `listening_comprehension_provider.dart`.
- Consumes: nothing from other tasks — this task doesn't touch `TtsService` or any provider/screen, so it cannot break compilation of anything else.

This task is entirely additive (new fields with safe defaults, new pure functions) — nothing in the app calls `assignVoices` or reads `gender`/`speakerGenders` yet, so the app keeps compiling and behaving exactly as before until Task 2 wires it in.

### Step 1: Add `gender`/`speakerGenders` to the entities

Replace the full contents of `lib/features/listening/domain/entities/listening_passage.dart`:

```dart
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';

enum ListeningKind { conversation, talk }

final class ListeningTurn {
  const ListeningTurn({this.speaker, this.gender, required this.text});

  final String? speaker; // 'A' or 'B' for a conversation; null for a talk
  final String? gender; // 'male' or 'female'; null if the AI omitted it
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
    this.speakerGenders = const {},
  });

  final String id;
  final ListeningKind kind;
  final List<ListeningTurn> turns;
  final List<ListeningQuestion> questions; // always 3 items
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;

  /// Keyed by speaker key ('A', 'B', or 'solo' — see [speakerKey]), value is
  /// 'male' or 'female'. Derived once at parse time from each speaker's
  /// first-seen turn (see `ListeningPassageSource._parse`).
  final Map<String, String> speakerGenders;
}

/// Normalizes a raw turn speaker ('A', 'B', or null for a talk) into the key
/// [ListeningPassage.speakerGenders] and [assignVoices] use.
String speakerKey(String? speaker) => speaker ?? 'solo';

/// Deterministic, computed fresh each time it's needed (not cached on any
/// session state) — cheap and pure given the same passage. Walks distinct
/// speakers in order of first appearance; for each, takes the next unused
/// voice slot (1 or 2) of that speaker's declared gender. A speaker with no
/// declared gender (malformed AI response) defaults to 'female' — an
/// arbitrary but harmless choice, since the alternative (throwing) would
/// break an otherwise-usable passage over a cosmetic voice-picking detail.
/// Ports apps/web/src/lib/listeningPassage.ts's assignVoices() exactly.
Map<String, String> assignVoices(ListeningPassage passage) {
  final seen = <String>{};
  final order = <String>[];
  for (final t in passage.turns) {
    final key = speakerKey(t.speaker);
    if (seen.add(key)) order.add(key);
  }

  final nextSlotByGender = <String, int>{'male': 1, 'female': 1};
  final result = <String, String>{};
  for (final speaker in order) {
    final gender = passage.speakerGenders[speaker] ?? 'female';
    final slot = nextSlotByGender[gender]!;
    result[speaker] = '$gender$slot';
    nextSlotByGender[gender] = slot == 1 ? 2 : 1; // wraps back to 1 past 2 speakers of the same gender
  }
  return result;
}
```

- [ ] **Step 1 done**

### Step 2: Update `ListeningPassageSource`'s prompt and parser

In `lib/features/listening/data/sources/listening_passage_source.dart`, replace the `_buildPrompt` method:

```dart
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
```
with:
```dart
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
        'For every turn, also declare "gender" as "male" or "female" for that turn\'s '
        'speaker — keep it consistent for the same speaker letter across the whole '
        'passage (speaker "A" is always the same gender in every one of its turns; '
        'same for "B"). A conversation may use two speakers of the same gender or two '
        'different genders — vary this across different generations. '
        'Then write exactly 3 multiple-choice questions in ${targetLanguage.label} about '
        'the passage, each with exactly 4 answer options in ${targetLanguage.label}, '
        'testing the main idea, a specific detail, or an implied meaning — never a '
        'fill-in-the-blank question. '
        'Respond with JSON only (no markdown, no code fences): '
        '{"kind": "conversation" or "talk", '
        '"turns": [{"speaker": "A" or "B" or null, "gender": "male" or "female", "text": "..."}], '
        '"questions": [{"question": "...", "options": ["...", "...", "...", "..."], '
        '"correctIndex": 0}]}';
  }
```

Replace the `_parse` method:
```dart
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
```
with:
```dart
  ListeningPassage _parse(
    Map<String, dynamic> json,
    CEFRLevel level,
    AppContext context,
    Language targetLanguage,
  ) {
    final kind = json['kind'] == 'conversation'
        ? ListeningKind.conversation
        : ListeningKind.talk;

    final rawTurns = json['turns'] as List? ?? [];
    final turns = rawTurns.map((t) {
      final tm = t as Map<String, dynamic>;
      final gender = tm['gender'] as String?;
      return ListeningTurn(
        speaker: tm['speaker'] as String?,
        gender: (gender == 'male' || gender == 'female') ? gender : null,
        text: tm['text'] as String? ?? '',
      );
    }).toList();

    // First-seen wins: an AI response that's inconsistent about a speaker's
    // gender on a later turn must not change which voice gets used mid-passage.
    final speakerGenders = <String, String>{};
    for (final t in rawTurns) {
      final tm = t as Map<String, dynamic>;
      final key = speakerKey(tm['speaker'] as String?);
      if (speakerGenders.containsKey(key)) continue;
      final gender = tm['gender'] as String?;
      if (gender == 'male' || gender == 'female') {
        speakerGenders[key] = gender;
      }
    }

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
      speakerGenders: speakerGenders,
      level: level,
      context: context,
      targetLanguage: targetLanguage,
      generatedAt: DateTime.now(),
    );
  }
```

- [ ] **Step 2 done**

### Step 3: Update `listening_passage_test.dart` for the new fields

In `test/features/listening/domain/entities/listening_passage_test.dart`, add these tests inside the existing `group('ListeningTurn', ...)` block (after its existing 2 tests, before the closing `});`):

```dart
    test('gender is null when not provided', () {
      const turn = ListeningTurn(speaker: 'A', text: 'Hello there.');
      expect(turn.gender, isNull);
    });

    test('holds a declared gender', () {
      const turn = ListeningTurn(speaker: 'A', gender: 'female', text: 'Hello there.');
      expect(turn.gender, 'female');
    });
```

Add this test inside the existing `group('ListeningPassage', ...)` block (after its existing 3 tests, before the closing `});`):

```dart
    test('speakerGenders defaults to empty when not provided', () {
      expect(passage.speakerGenders, isEmpty);
    });
```

Add this new top-level group at the end of the file, right before the final closing `}`:

```dart
  group('speakerKey', () {
    test('returns the speaker letter unchanged', () {
      expect(speakerKey('A'), 'A');
      expect(speakerKey('B'), 'B');
    });
    test('returns "solo" for a null speaker (talk format)', () {
      expect(speakerKey(null), 'solo');
    });
  });

  group('assignVoices', () {
    ListeningPassage passageWith(List<ListeningTurn> turns, Map<String, String> genders) =>
        ListeningPassage(
          id: 'p',
          kind: ListeningKind.conversation,
          turns: turns,
          questions: const [],
          speakerGenders: genders,
          level: CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: Language.english,
          generatedAt: DateTime(2026),
        );

    test('assigns distinct voices to two speakers of different genders', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'A', text: 'Hi.'),
          ListeningTurn(speaker: 'B', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'female'},
      );
      final voices = assignVoices(passage);
      expect(voices['A'], 'male1');
      expect(voices['B'], 'female1');
    });

    test('two speakers of the same gender get slot 1 and slot 2', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'A', text: 'Hi.'),
          ListeningTurn(speaker: 'B', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'male'},
      );
      final voices = assignVoices(passage);
      expect(voices['A'], 'male1');
      expect(voices['B'], 'male2');
    });

    test('orders by first appearance, not alphabetically', () {
      final passage = passageWith(
        const [
          ListeningTurn(speaker: 'B', text: 'Hi.'),
          ListeningTurn(speaker: 'A', text: 'Hello.'),
        ],
        {'A': 'male', 'B': 'female'},
      );
      final voices = assignVoices(passage);
      expect(voices['B'], 'female1');
      expect(voices['A'], 'male1');
    });

    test('defaults a speaker with no declared gender to female', () {
      final passage = passageWith(
        const [ListeningTurn(speaker: 'A', text: 'Hi.')],
        const {},
      );
      expect(assignVoices(passage)['A'], 'female1');
    });

    test('a single-speaker talk gets one voice keyed by "solo"', () {
      final passage = passageWith(
        const [
          ListeningTurn(text: 'Attention all passengers.'),
          ListeningTurn(text: 'Flight 204 is now boarding.'),
        ],
        {'solo': 'male'},
      );
      final voices = assignVoices(passage);
      expect(voices['solo'], 'male1');
      expect(voices.length, 1);
    });
  });
```

Run: `flutter test test/features/listening/domain/entities/listening_passage_test.dart`
Expected: all tests pass (existing + new).

- [ ] **Step 3 done**

### Step 4: Update `listening_passage_source_test.dart` for the gender field

In `test/features/listening/data/sources/listening_passage_source_test.dart`, replace the `conversationJson` definition:
```dart
  final conversationJson = jsonEncode({
    'kind': 'conversation',
    'turns': [
      {'speaker': 'A', 'text': 'Can I help you find something?'},
      {'speaker': 'B', 'text': 'Yes, I am looking for a winter jacket.'},
    ],
```
with:
```dart
  final conversationJson = jsonEncode({
    'kind': 'conversation',
    'turns': [
      {'speaker': 'A', 'gender': 'female', 'text': 'Can I help you find something?'},
      {'speaker': 'B', 'gender': 'male', 'text': 'Yes, I am looking for a winter jacket.'},
    ],
```

Add these assertions to the `'parses a conversation response into a ListeningPassage'` test, right after the existing `expect(passage.turns[1].speaker, 'B');` line:
```dart
    expect(passage.turns[0].gender, 'female');
    expect(passage.turns[1].gender, 'male');
    expect(passage.speakerGenders, {'A': 'female', 'B': 'male'});
```

Add this new test at the end of the file, right before the final closing `}`:
```dart
  test('speakerGenders uses the first-seen gender when a later turn disagrees', () async {
    final inconsistentJson = jsonEncode({
      'kind': 'conversation',
      'turns': [
        {'speaker': 'A', 'gender': 'female', 'text': 'Can I help you?'},
        {'speaker': 'B', 'gender': 'male', 'text': 'Yes, please.'},
        {'speaker': 'A', 'gender': 'male', 'text': 'Sure thing.'}, // inconsistent — ignored
      ],
      'questions': [
        {'question': 'Q1', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
        {'question': 'Q2', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
        {'question': 'Q3', 'options': ['a', 'b', 'c', 'd'], 'correctIndex': 0},
      ],
    });
    final source = ListeningPassageSource.withModel(
      FakeGenerativeModelClient(inconsistentJson),
    );
    final passage = await source.generate(
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
    );

    expect(passage.speakerGenders['A'], 'female'); // first-seen wins, not the 3rd turn's 'male'
  });
```

Run: `flutter test test/features/listening/data/sources/listening_passage_source_test.dart`
Expected: all tests pass (existing + new).

- [ ] **Step 4 done**

### Step 5: Full-repo compile check and commit

Run:
```
flutter analyze
```
Expected: no errors or warnings beyond the 21 pre-existing `RadioListTile` deprecation infos (unrelated to this task).

Run:
```
flutter test
```
Expected: the full suite passes — this task is purely additive, nothing else in the repo consumes the new fields/functions yet, so no other test should change behavior.

Commit:
```bash
git add lib/features/listening/domain/entities/listening_passage.dart lib/features/listening/data/sources/listening_passage_source.dart test/features/listening/domain/entities/listening_passage_test.dart test/features/listening/data/sources/listening_passage_source_test.dart
git commit -m "feat: add gender/speakerGenders + assignVoices for Nghe hiểu real voice differentiation"
```

- [ ] **Step 5 done**

---

## Task 2: Cloud-Function-backed TtsService + all 5 call sites + language gating

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/features/dictionary/domain/entities/language.dart`
- Modify: `lib/services/tts_service.dart`
- Modify: `lib/core/di/app_providers.dart`
- Modify: `lib/features/dictionary/presentation/widgets/word_result_widget.dart`
- Modify: `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`
- Modify: `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`
- Modify: `lib/features/listening/presentation/screens/dictation_home_screen.dart`
- Modify: `lib/features/listening/presentation/screens/comprehension_home_screen.dart`
- Modify: `lib/features/listening/presentation/providers/dictation_practice_provider.dart`
- Modify: `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`
- Test: `test/features/dictionary/domain/entities/language_test.dart` (new)
- Test: `test/services/tts_service_test.dart`
- Test: `test/features/listening/presentation/screens/dictation_home_screen_test.dart`
- Test: `test/features/listening/presentation/screens/comprehension_home_screen_test.dart`
- Test: `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
- Test: `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`

**Interfaces:**
- Consumes: `speakerKey`, `assignVoices` (Task 1, `lib/features/listening/domain/entities/listening_passage.dart`).
- Produces: `Language.ttsCloudCode` (`String?` extension getter); `PronunciationTier` enum; `TtsService.pronounce(text, language, {required tier})`, `TtsService.synthesize(text, language, {voice, rate})`, `TtsService.stop()`; `CloudTtsService` (the new default implementation).

This task must land as one unit: `TtsService`'s interface change (`speak` → `pronounce`/`synthesize`) breaks every one of its 5 call sites' compilation simultaneously, so they're all updated together here.

### Step 1: Add `cloud_functions`-style dependency for audio playback

Run:
```
flutter pub add audioplayers
```
This lets pub resolve a version compatible with the rest of `pubspec.yaml` — do not hand-pick a version number. Then run:
```
flutter pub get
```
Expected: `pubspec.yaml` gains an `audioplayers: ^X.Y.Z` line under `dependencies`, `pubspec.lock` updates, both commands exit 0.

Then remove `flutter_tts` from `pubspec.yaml` — delete this line from the `dependencies:` block:
```yaml
  flutter_tts: ^4.2.0
```
Run `flutter pub get` again. Expected: `pubspec.lock` no longer lists `flutter_tts` or its transitive-only dependents.

- [ ] **Step 1 done**

### Step 2: Add `Language.ttsCloudCode`

In `lib/features/dictionary/domain/entities/language.dart`, add this getter to the `extension LanguageX on Language` block... **first check the exact extension name in the file** (read the file — it's `extension` on `Language`, add the member inside its existing body, after `bool get requiresAi => this != Language.english;`):

```dart
  /// Matches apps/web/src/lib/pronunciation.ts's ttsLanguageCode() — the
  /// self-hosted Piper TTS service only has voices deployed for Vietnamese
  /// and English; null means no server-side pronunciation/audio is
  /// available for this target language.
  String? get ttsCloudCode => switch (this) {
        Language.vietnamese => 'vi',
        Language.english => 'en',
        _ => null,
      };
```

- [ ] **Step 2 done**

### Step 3: Test `Language.ttsCloudCode`

Create `test/features/dictionary/domain/entities/language_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';

void main() {
  group('Language.ttsCloudCode', () {
    test('vietnamese -> "vi"', () {
      expect(Language.vietnamese.ttsCloudCode, 'vi');
    });
    test('english -> "en"', () {
      expect(Language.english.ttsCloudCode, 'en');
    });
    test('chinese, korean, japanese all -> null (no Piper voice)', () {
      expect(Language.chinese.ttsCloudCode, isNull);
      expect(Language.korean.ttsCloudCode, isNull);
      expect(Language.japanese.ttsCloudCode, isNull);
    });
  });
}
```

Run: `flutter test test/features/dictionary/domain/entities/language_test.dart`
Expected: 3/3 pass.

- [ ] **Step 3 done**

### Step 4: Rewrite `TtsService`

Replace the full contents of `lib/services/tts_service.dart`:

```dart
// lib/services/tts_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import '../core/services/cloud_function_caller.dart';
import '../features/dictionary/domain/entities/language.dart';

enum PronunciationTier { word, sentence }

abstract class TtsService {
  /// Cached word/sentence pronunciation (dictionary/vocab lookups) — calls
  /// the `getPronunciation` Cloud Function, which caches by
  /// sha256(text+lang+voice) in Firebase Storage and is shared across all
  /// users. No-ops silently if [language].ttsCloudCode is null.
  Future<void> pronounce(String text, Language language, {required PronunciationTier tier});

  /// Uncached synthesis for freshly AI-generated text (Nghe chép sentences,
  /// Nghe hiểu turns) — calls `synthesizeSpeech`, never cached. [voice]
  /// picks one of Piper's 4 voices ('male1'/'male2'/'female1'/'female2');
  /// [rate] is a post-synthesis playback-speed multiplier (1.0 = normal).
  /// No-ops silently if [language].ttsCloudCode is null.
  Future<void> synthesize(String text, Language language, {String? voice, double? rate});

  Future<void> stop();
}

class CloudTtsService implements TtsService {
  CloudTtsService({CloudFunctionCaller? caller, AudioPlayer? player})
      : _caller = caller ?? FirebaseCloudFunctionCaller(),
        _player = player ?? AudioPlayer();

  final CloudFunctionCaller _caller;
  final AudioPlayer _player;

  @override
  Future<void> pronounce(String text, Language language, {required PronunciationTier tier}) async {
    final code = language.ttsCloudCode;
    if (code == null || text.trim().isEmpty) return;
    try {
      final result = await _caller.call('getPronunciation', {
        'text': text,
        'language': code,
        'tier': tier.name,
      });
      final url = result['url'] as String?;
      if (url == null) return;
      await _playAndAwaitCompletion(UrlSource(url));
    } catch (_) {
      // Best-effort: no error-display UI exists at any pronounce() call
      // site today (matches flutter_tts's own lack of one).
    }
  }

  @override
  Future<void> synthesize(String text, Language language, {String? voice, double? rate}) async {
    final code = language.ttsCloudCode;
    if (code == null || text.trim().isEmpty) return;
    try {
      final result = await _caller.call('synthesizeSpeech', {
        'text': text,
        'language': code,
        if (voice != null) 'voice': voice,
      });
      final audioBase64 = result['audioBase64'] as String?;
      if (audioBase64 == null) return;
      if (rate != null) await _player.setPlaybackRate(rate);
      await _playAndAwaitCompletion(BytesSource(base64Decode(audioBase64)));
    } catch (_) {
      // Best-effort — see pronounce()'s comment.
    }
  }

  /// Starts playing [source] and blocks until playback finishes — either
  /// naturally (PlayerState.completed) or because something else called
  /// stop() on this same player mid-playback (PlayerState.stopped).
  /// Mirrors flutter_tts's awaitSpeakCompletion(true), which several
  /// callers (Nghe chép/Nghe hiểu) depend on to know when to flip
  /// isSpeaking back to false.
  Future<void> _playAndAwaitCompletion(Source source) async {
    final done = Completer<void>();
    late final StreamSubscription<PlayerState> sub;
    sub = _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed || state == PlayerState.stopped) {
        if (!done.isCompleted) done.complete();
      }
    });
    try {
      await _player.play(source);
      await done.future;
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> stop() => _player.stop();
}
```

- [ ] **Step 4 done**

### Step 5: Rewrite `tts_service_test.dart`

Replace the full contents of `test/services/tts_service_test.dart`:

```dart
// test/services/tts_service_test.dart
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/services/cloud_function_caller.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/services/tts_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

class FakeSource extends Fake implements Source {}

class _FakeCaller implements CloudFunctionCaller {
  _FakeCaller({this.response, this.error});
  Map<String, dynamic>? response;
  Object? error;
  String? capturedName;
  Map<String, dynamic>? capturedData;

  @override
  Future<Map<String, dynamic>> call(String name, Map<String, dynamic> data) async {
    capturedName = name;
    capturedData = data;
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeSource());
  });

  late MockAudioPlayer mockPlayer;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    when(() => mockPlayer.play(any())).thenAnswer((_) async {});
    when(() => mockPlayer.stop()).thenAnswer((_) async {});
    when(() => mockPlayer.setPlaybackRate(any())).thenAnswer((_) async {});
    when(() => mockPlayer.onPlayerStateChanged)
        .thenAnswer((_) => Stream.value(PlayerState.completed));
  });

  group('CloudTtsService.pronounce', () {
    test('sends {text, language, tier} to getPronunciation and plays the returned url', () async {
      final caller = _FakeCaller(response: {'url': 'https://example.com/a.wav'});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('hello', Language.english, tier: PronunciationTier.word);

      expect(caller.capturedName, 'getPronunciation');
      expect(caller.capturedData, {'text': 'hello', 'language': 'en', 'tier': 'word'});
      verify(() => mockPlayer.play(any(that: isA<UrlSource>()))).called(1);
    });

    test('sends tier "sentence" for PronunciationTier.sentence', () async {
      final caller = _FakeCaller(response: {'url': 'https://example.com/a.wav'});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('Hello world.', Language.vietnamese, tier: PronunciationTier.sentence);

      expect(caller.capturedData?['language'], 'vi');
      expect(caller.capturedData?['tier'], 'sentence');
    });

    test('does not call the Cloud Function for a language with no Piper voice', () async {
      final caller = _FakeCaller();
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.pronounce('你好', Language.chinese, tier: PronunciationTier.word);

      expect(caller.capturedName, isNull);
      verifyNever(() => mockPlayer.play(any()));
    });

    test('swallows a Cloud Function error without throwing', () async {
      final caller = _FakeCaller(error: Exception('network error'));
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await expectLater(
        service.pronounce('hello', Language.english, tier: PronunciationTier.word),
        completes,
      );
    });
  });

  group('CloudTtsService.synthesize', () {
    test('sends {text, language} to synthesizeSpeech and plays the decoded audio', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='}); // base64 for "OK"
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hello world.', Language.english);

      expect(caller.capturedName, 'synthesizeSpeech');
      expect(caller.capturedData, {'text': 'Hello world.', 'language': 'en'});
      verify(() => mockPlayer.play(any(that: isA<BytesSource>()))).called(1);
    });

    test('includes voice in the payload when provided', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english, voice: 'female2');

      expect(caller.capturedData, {'text': 'Hi.', 'language': 'en', 'voice': 'female2'});
    });

    test('applies rate via setPlaybackRate before playing when provided', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english, rate: 1.25);

      verify(() => mockPlayer.setPlaybackRate(1.25)).called(1);
    });

    test('does not call setPlaybackRate when rate is omitted', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('Hi.', Language.english);

      verifyNever(() => mockPlayer.setPlaybackRate(any()));
    });

    test('does not call the Cloud Function for a language with no Piper voice', () async {
      final caller = _FakeCaller();
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      await service.synthesize('안녕하세요', Language.korean);

      expect(caller.capturedName, isNull);
      verifyNever(() => mockPlayer.play(any()));
    });
  });

  group('CloudTtsService playback-completion awaiting', () {
    test('play() blocks until onPlayerStateChanged emits completed', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final controller = StreamController<PlayerState>();
      when(() => mockPlayer.onPlayerStateChanged).thenAnswer((_) => controller.stream);
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      var resolved = false;
      final future = service.synthesize('Hi.', Language.english).then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse); // still waiting

      controller.add(PlayerState.completed);
      await future;
      expect(resolved, isTrue);
      await controller.close();
    });

    test('play() also unblocks on PlayerState.stopped (an external stop() call)', () async {
      final caller = _FakeCaller(response: {'audioBase64': 'T0s='});
      final controller = StreamController<PlayerState>();
      when(() => mockPlayer.onPlayerStateChanged).thenAnswer((_) => controller.stream);
      final service = CloudTtsService(caller: caller, player: mockPlayer);

      var resolved = false;
      final future = service.synthesize('Hi.', Language.english).then((_) => resolved = true);
      await Future<void>.delayed(Duration.zero);
      expect(resolved, isFalse);

      controller.add(PlayerState.stopped);
      await future;
      expect(resolved, isTrue);
      await controller.close();
    });
  });

  group('CloudTtsService.stop', () {
    test('delegates to AudioPlayer.stop()', () async {
      final service = CloudTtsService(caller: _FakeCaller(), player: mockPlayer);
      await service.stop();
      verify(() => mockPlayer.stop()).called(1);
    });
  });
}
```

Run: `flutter test test/services/tts_service_test.dart`
Expected: 12/12 pass.

- [ ] **Step 5 done**

### Step 6: Wire `app_providers.dart` to the new service

In `lib/core/di/app_providers.dart`:

Remove this import:
```dart
import 'package:flutter_tts/flutter_tts.dart';
```

Remove this provider:
```dart
@riverpod
FlutterTts flutterTts(FlutterTtsRef ref) => FlutterTts();
```

Replace:
```dart
@riverpod
TtsService ttsService(TtsServiceRef ref) =>
    FlutterTtsService(ref.watch(flutterTtsProvider));
```
with:
```dart
@riverpod
TtsService ttsService(TtsServiceRef ref) => CloudTtsService();
```

Regenerate codegen:
```
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0, `app_providers.g.dart` no longer has `flutterTtsProvider`.

- [ ] **Step 6 done**

### Step 7: Update pronunciation call sites — `.pronounce()` + hide when unsupported

In `lib/features/dictionary/presentation/widgets/word_result_widget.dart`, add these imports alongside the existing ones (this file does not currently import `Language` at all — merely having a `Language`-typed value in scope does not make its `ttsCloudCode` extension resolve; the extension's declaring file must be imported too):
```dart
import '../../../../services/tts_service.dart';
import '../../domain/entities/language.dart';
```

Replace:
```dart
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Pronounce word',
                  onPressed: () => tts.speak(result.headword, targetLanguage),
                ),
```
with:
```dart
                if (targetLanguage.ttsCloudCode != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Pronounce word',
                    onPressed: () => tts.pronounce(result.headword, targetLanguage,
                        tier: PronunciationTier.word),
                  ),
```
Replace:
```dart
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 18),
                        tooltip: 'Pronounce example',
                        onPressed: () => tts.speak(ex, targetLanguage),
                      ),
```
with:
```dart
                      if (targetLanguage.ttsCloudCode != null)
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 18),
                          tooltip: 'Pronounce example',
                          onPressed: () =>
                              tts.pronounce(ex, targetLanguage, tier: PronunciationTier.sentence),
                        ),
```
In `lib/features/dictionary/presentation/widgets/sentence_result_widget.dart`, add these imports (this file does not currently import `Language` at all — needed for `.ttsCloudCode` to resolve):
```dart
import '../../../../services/tts_service.dart';
import '../../domain/entities/language.dart';
```
Replace:
```dart
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Pronounce sentence',
                  onPressed: () =>
                      tts.speak(result.original, targetLanguage),
                ),
```
with:
```dart
                if (targetLanguage.ttsCloudCode != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Pronounce sentence',
                    onPressed: () => tts.pronounce(result.original, targetLanguage,
                        tier: PronunciationTier.sentence),
                  ),
```

In `lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart`, add these imports alongside the existing ones (this file does not currently import `Language` at all — needed for `.ttsCloudCode` to resolve):
```dart
import '../../../../services/tts_service.dart';
import '../../../dictionary/domain/entities/language.dart';
```
Replace:
```dart
                IconButton(
                  icon: const Icon(Icons.volume_up_outlined),
                  onPressed: () =>
                      tts.speak(r.headword, settings.targetLanguage),
                ),
```
with:
```dart
                if (settings.targetLanguage.ttsCloudCode != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up_outlined),
                    onPressed: () => tts.pronounce(r.headword, settings.targetLanguage,
                        tier: PronunciationTier.word),
                  ),
```
Replace:
```dart
                          IconButton(
                            icon: const Icon(Icons.volume_up_outlined,
                                size: 18),
                            onPressed: () =>
                                tts.speak(e.value, settings.targetLanguage),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
```
with:
```dart
                          if (settings.targetLanguage.ttsCloudCode != null)
                            IconButton(
                              icon: const Icon(Icons.volume_up_outlined,
                                  size: 18),
                              onPressed: () => tts.pronounce(
                                  e.value, settings.targetLanguage,
                                  tier: PronunciationTier.sentence),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
```

- [ ] **Step 7 done**

### Step 8: Gate Nghe chép / Nghe hiểu home screens for unsupported languages

In `lib/features/listening/presentation/screens/dictation_home_screen.dart`, replace:
```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (words == null)
```
with:
```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (_language.ttsCloudCode == null)
              AiDisabledCard(
                message: 'Tính năng này chưa hỗ trợ ${_language.label}. '
                    'Hãy chọn Tiếng Việt hoặc English.',
              )
            else if (words == null)
```

In `lib/features/listening/presentation/screens/comprehension_home_screen.dart`, replace:
```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else
              sessionAsync.when(
```
with:
```dart
            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (_language.ttsCloudCode == null)
              AiDisabledCard(
                message: 'Tính năng này chưa hỗ trợ ${_language.label}. '
                    'Hãy chọn Tiếng Việt hoặc English.',
              )
            else
              sessionAsync.when(
```

- [ ] **Step 8 done**

### Step 9: Test the new language gate on both home screens

In `test/features/listening/presentation/screens/dictation_home_screen_test.dart`, add this test at the end of `main()`'s test list, right before the closing `});` of the file:
```dart

  testWidgets('shows unsupported-language message when target language has no Piper voice', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults
          .copyWith(aiEnabled: true, targetLanguage: Language.chinese),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa hỗ trợ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });
```

In `test/features/listening/presentation/screens/comprehension_home_screen_test.dart`, add this test at the end of `main()`'s test list, right before the closing `});` of the file:
```dart

  testWidgets('shows unsupported-language message when target language has no Piper voice', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults
          .copyWith(aiEnabled: true, targetLanguage: Language.japanese),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa hỗ trợ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });
```
This second file doesn't currently import `Language` — add this import alongside the existing ones:
```dart
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
```

Run: `flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart test/features/listening/presentation/screens/comprehension_home_screen_test.dart`
Expected: all tests pass (existing + the 2 new ones).

- [ ] **Step 9 done**

### Step 10: Update `dictation_practice_provider.dart` — `.synthesize()` + rate fix

In `lib/features/listening/presentation/providers/dictation_practice_provider.dart`, replace:
```dart
double _rateFor(double speedMultiplier) => (0.5 * speedMultiplier).clamp(0.0, 1.0);
```
with:
```dart
double _rateFor(double speedMultiplier) => speedMultiplier;
```

Replace the `play()` method's speak call:
```dart
    await ref.read(ttsServiceProvider).speak(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
```
with:
```dart
    await ref.read(ttsServiceProvider).synthesize(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(updated.speedMultiplier),
        );
```
(This exact block appears once in `play()`. Two more near-identical blocks appear in `seekTo()` and `setSpeed()` — make the same `speak(` → `synthesize(` rename at each, keeping every other argument unchanged. There are exactly 3 occurrences of `ttsServiceProvider).speak(` in this file; rename all 3 to `.synthesize(`.)

- [ ] **Step 10 done**

### Step 11: Rewrite `dictation_practice_provider_test.dart`

The only changes needed are mechanical: every `mockTts.speak(` becomes `mockTts.synthesize(`, and every literal `rate:` value changes from the old `flutter_tts`-scaled number to the direct multiplier (`0.5` → `1.0`, `0.375` → `0.75`, `0.625` → `1.25`) — `_rateFor` now passes the multiplier straight through instead of computing `0.5 * multiplier`. Apply these exact replacements in `test/features/listening/presentation/providers/dictation_practice_provider_test.dart`:

Replace (in the `'DictationPracticeNotifier lifecycle'` group's `setUp`):
```dart
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```
with:
```dart
      when(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```

Replace (in `'first play() ...'`):
```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1);
```
with:
```dart
      verify(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: 1.0))
          .called(1);
```

Replace (in `'second play() ...'`):
```dart
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(2);
```
with:
```dart
      verify(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: 1.0))
          .called(2);
```

Replace (in the `'DictationPracticeNotifier difficulty/blanks'` group's `setUp`) — identical shape to the lifecycle group's `setUp` above:
```dart
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```
with:
```dart
      when(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```

Replace (in the `'DictationPracticeNotifier seekTo'` group's `setUp`):
```dart
      when(() => mockTts.speak(any(), any(), rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```
with:
```dart
      when(() => mockTts.synthesize(any(), any(), rate: any(named: 'rate')))
          .thenAnswer((_) async {});
```

Replace (in `'first seekTo() ...'`):
```dart
      verify(() => mockTts.speak('world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
```
with:
```dart
      verify(() => mockTts.synthesize('world.', fixedItem.targetLanguage, rate: 1.0)).called(1);
```

Replace (in `'seekTo() after the first listen ...'`):
```dart
      verify(() => mockTts.speak('Hello world.', fixedItem.targetLanguage, rate: 0.5)).called(1);
```
with:
```dart
      verify(() => mockTts.synthesize('Hello world.', fixedItem.targetLanguage, rate: 1.0)).called(1);
```

Replace (in `'seekTo() with an out-of-range wordIndex is a no-op'`):
```dart
      verifyNever(() => mockTts.speak(any(), any(), rate: any(named: 'rate')));
```
with:
```dart
      verifyNever(() => mockTts.synthesize(any(), any(), rate: any(named: 'rate')));
```

Replace (in `'setSpeed() while idle ...'`):
```dart
      verifyNever(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
          rate: any(named: 'rate')));
```
with:
```dart
      verifyNever(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
          rate: any(named: 'rate')));
```

Replace the entire `'setSpeed() while speaking ...'` test body:
```dart
      final completer = Completer<void>();
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) => completer.future);
      when(() => mockTts.stop()).thenAnswer((_) async {});

      final playFuture = notifier.play(); // starts speaking, hangs on completer
      final speedFuture = notifier.setSpeed(0.75);
      completer.complete(); // let both hung speak() calls resolve
      await playFuture;
      await speedFuture;

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.replayCount, 1);
      expect(state.isSpeaking, false);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.5))
          .called(1); // the original play(), at the default 1x rate
      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.375))
          .called(1); // the setSpeed()-triggered replay, at the new 0.75x rate
```
with:
```dart
      final completer = Completer<void>();
      when(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) => completer.future);
      when(() => mockTts.stop()).thenAnswer((_) async {});

      final playFuture = notifier.play(); // starts speaking, hangs on completer
      final speedFuture = notifier.setSpeed(0.75);
      completer.complete(); // let both hung speak() calls resolve
      await playFuture;
      await speedFuture;

      final state = c.read(dictationPracticeNotifierProvider).value!;
      expect(state.speedMultiplier, 0.75);
      expect(state.replayCount, 1);
      expect(state.isSpeaking, false);
      verify(() => mockTts.stop()).called(1);
      verify(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: 1.0))
          .called(1); // the original play(), at the default 1x rate
      verify(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.75))
          .called(1); // the setSpeed()-triggered replay, at the new 0.75x rate
```

Replace the entire `'setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next play()'` test (including its name):
```dart
    test('setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next play()', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);
      when(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});

      await notifier.setSpeed(1.25); // idle: just stores the choice
      await notifier.play();

      verify(() => mockTts.speak(fixedItem.target, fixedItem.targetLanguage,
              rate: 0.625))
          .called(1);
    });
```
with:
```dart
    test('setSpeed() passes 0.75x/1x/1.25x straight through as the playback rate for the next play()', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      final notifier = c.read(dictationPracticeNotifierProvider.notifier);
      await generateSession(notifier);
      when(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: any(named: 'rate')))
          .thenAnswer((_) async {});

      await notifier.setSpeed(1.25); // idle: just stores the choice
      await notifier.play();

      verify(() => mockTts.synthesize(fixedItem.target, fixedItem.targetLanguage,
              rate: 1.25))
          .called(1);
    });
```

Run: `flutter test test/features/listening/presentation/providers/dictation_practice_provider_test.dart`
Expected: all tests pass.

- [ ] **Step 11 done**

### Step 12: Update `listening_comprehension_provider.dart` — `.synthesize()`, rate fix, real voices

No new imports needed — `assignVoices`/`speakerKey` come from `listening_passage.dart`, already imported in this file, and `ttsServiceProvider`'s `.synthesize(...)` call resolves via the same transitive-type-inference path the existing `.speak(...)` call already relies on today (this file has never directly imported `tts_service.dart`, and doesn't need to now either — adding it would trigger an unused-import warning since nothing here references `TtsService`/`PronunciationTier` by name).

Replace:
```dart
double _rateFor(double speedMultiplier) => (0.5 * speedMultiplier).clamp(0.0, 1.0);
```
with:
```dart
double _rateFor(double speedMultiplier) => speedMultiplier;
```

Delete this method from `ListeningComprehensionNotifier` entirely:
```dart
  double _pitchFor(String? speaker) => speaker == 'B' ? 1.3 : 1.0;

```

Replace the `playCurrentTurn()` method:
```dart
  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    await ref.read(ttsServiceProvider).speak(
          turn.text,
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    if (latest.currentTurnIndex < latest.passage.turns.length - 1) {
      // Turn finished naturally (not interrupted) and it's not the last one
      // — keep going without a gap, staying "isSpeaking" the whole time.
      state = AsyncData(latest.copyWith(currentTurnIndex: latest.currentTurnIndex + 1));
      await playCurrentTurn();
      return;
    }
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```
with:
```dart
  Future<void> playCurrentTurn() async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(isSpeaking: true, playToken: token));
    final turn = current.currentTurn;
    final voices = assignVoices(current.passage);
    await ref.read(ttsServiceProvider).synthesize(
          turn.text,
          current.passage.targetLanguage,
          voice: voices[speakerKey(turn.speaker)],
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    if (latest.currentTurnIndex < latest.passage.turns.length - 1) {
      // Turn finished naturally (not interrupted) and it's not the last one
      // — keep going without a gap, staying "isSpeaking" the whole time.
      state = AsyncData(latest.copyWith(currentTurnIndex: latest.currentTurnIndex + 1));
      await playCurrentTurn();
      return;
    }
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

Replace the `seekToWord()` method:
```dart
  Future<void> seekToWord(int globalWordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final total = totalWordsOf(current.passage);
    if (globalWordIndex < 0 || globalWordIndex >= total) return;

    final resolved = _resolveGlobalWordIndex(current.passage, globalWordIndex);
    final turn = current.passage.turns[resolved.turnIndex];
    final words = _splitWords(turn.text);
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(
      currentTurnIndex: resolved.turnIndex,
      isSpeaking: true,
      playToken: token,
    ));
    await ref.read(ttsServiceProvider).stop();
    await ref.read(ttsServiceProvider).speak(
          words.skip(resolved.wordIndex).join(' '),
          current.passage.targetLanguage,
          pitch: _pitchFor(turn.speaker),
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```
with:
```dart
  Future<void> seekToWord(int globalWordIndex) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    final total = totalWordsOf(current.passage);
    if (globalWordIndex < 0 || globalWordIndex >= total) return;

    final resolved = _resolveGlobalWordIndex(current.passage, globalWordIndex);
    final turn = current.passage.turns[resolved.turnIndex];
    final words = _splitWords(turn.text);
    final token = current.playToken + 1;
    state = AsyncData(current.copyWith(
      currentTurnIndex: resolved.turnIndex,
      isSpeaking: true,
      playToken: token,
    ));
    await ref.read(ttsServiceProvider).stop();
    final voices = assignVoices(current.passage);
    await ref.read(ttsServiceProvider).synthesize(
          words.skip(resolved.wordIndex).join(' '),
          current.passage.targetLanguage,
          voice: voices[speakerKey(turn.speaker)],
          rate: _rateFor(current.speedMultiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null || latest.playToken != token) return; // superseded meanwhile
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
```

- [ ] **Step 12 done**

### Step 13: Rewrite `listening_comprehension_provider_test.dart`

The `fixedPassage` fixture has turns A, B, A with no explicit genders — under `assignVoices`, both default to 'female' and get distinct slots by order of first appearance: **A → 'female1'**, **B → 'female2'**. Every `mockTts.speak(...)` becomes `mockTts.synthesize(...)`, every `pitch:` argument becomes the corresponding `voice:` value, and every literal `rate:` value changes from the old scale to the direct multiplier (`0.5` → `1.0`, `0.375` → `0.75`, `0.625` → `1.25`).

Apply these exact replacements in `test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`:

Replace (in the top-level `setUp`):
```dart
    when(
      () => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')),
    ).thenAnswer((_) async {});
```
with:
```dart
    when(
      () => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')),
    ).thenAnswer((_) async {});
```

Replace the `'playCurrentTurn() speaks the current turn ...'` test's name and body:
```dart
  test('playCurrentTurn() speaks the current turn with the correct pitch and resets isSpeaking on completion', () async {
    await generateFixed();
    await container.read(listeningComprehensionNotifierProvider.notifier).playCurrentTurn();
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.5))
        .called(1);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.isSpeaking, false); // reset after the awaited speak() completes
  });
```
with:
```dart
  test('playCurrentTurn() speaks the current turn with the correct voice and resets isSpeaking on completion', () async {
    await generateFixed();
    await container.read(listeningComprehensionNotifierProvider.notifier).playCurrentTurn();
    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
            voice: 'female1', rate: 1.0))
        .called(1);
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.isSpeaking, false); // reset after the awaited synthesize() completes
  });
```

Replace the `'playCurrentTurn() auto-continues ...'` test's body:
```dart
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.5))
        .called(1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3,
            rate: 0.5))
        .called(1);
    verify(() => mockTts.speak('Sure, for how many guests?', Language.english, pitch: 1.0,
            rate: 0.5))
        .called(1);
```
with:
```dart
    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
            voice: 'female1', rate: 1.0))
        .called(1);
    verify(() => mockTts.synthesize('Yes, I need a room for tonight.', Language.english,
            voice: 'female2', rate: 1.0))
        .called(1);
    verify(() => mockTts.synthesize('Sure, for how many guests?', Language.english,
            voice: 'female1', rate: 1.0))
        .called(1);
```

Replace the `'interrupting playback via stopPlayback() ...'` test's body:
```dart
    final completer = Completer<void>();
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn();
    await notifier.stopPlayback(); // supersedes the in-flight turn 0 playback
    completer.complete(); // let the original (now-superseded) speak() resolve
    await playFuture;

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0); // stopPlayback() doesn't change turns
    verify(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .called(1); // no auto-continue
```
with:
```dart
    final completer = Completer<void>();
    when(() => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn();
    await notifier.stopPlayback(); // supersedes the in-flight turn 0 playback
    completer.complete(); // let the original (now-superseded) synthesize() resolve
    await playFuture;

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 0); // stopPlayback() doesn't change turns
    verify(() => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')))
        .called(1); // no auto-continue
```

Replace (in `'seekToWord within the first turn ...'`):
```dart
    verify(() => mockTts.speak('I help you?', Language.english, pitch: 1.0, rate: 0.5)).called(1);
```
with:
```dart
    verify(() => mockTts.synthesize('I help you?', Language.english, voice: 'female1', rate: 1.0))
        .called(1);
```

Replace the `'seekToWord crossing into a later turn ...'` test's name and body:
```dart
  test(
      "seekToWord crossing into a later turn switches currentTurnIndex and uses that turn's pitch",
      () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(5); // turn 0 has 5 words (indices 0-4), so this is turn 1 word 0

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.speak('Yes, I need a room for tonight.', Language.english, pitch: 1.3,
            rate: 0.5))
        .called(1);
  });
```
with:
```dart
  test(
      "seekToWord crossing into a later turn switches currentTurnIndex and uses that turn's voice",
      () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.seekToWord(5); // turn 0 has 5 words (indices 0-4), so this is turn 1 word 0

    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.currentTurnIndex, 1);
    verify(() => mockTts.synthesize('Yes, I need a room for tonight.', Language.english,
            voice: 'female2', rate: 1.0))
        .called(1);
  });
```

Replace (in `'seekToWord with an out-of-range index is a no-op'`):
```dart
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')));
```
with:
```dart
    verifyNever(() => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')));
```

Replace (in `'setSpeed() while idle ...'`):
```dart
    verifyNever(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')));
    verifyNever(() => mockTts.stop());
```
with:
```dart
    verifyNever(() => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')));
    verifyNever(() => mockTts.stop());
```

Replace the `'setSpeed() while speaking ...'` test's body:
```dart
    final completer = Completer<void>();
    when(() => mockTts.speak(any(), any(), pitch: any(named: 'pitch'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn(); // hangs on completer for turn 0
    final speedFuture = notifier.setSpeed(0.75);
    completer.complete(); // let every hung/future speak() call resolve
    await playFuture;
    await speedFuture;

    verify(() => mockTts.stop()).called(1);
    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.375))
        .called(1); // the setSpeed()-triggered restart, at the new 0.75x rate
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
```
with:
```dart
    final completer = Completer<void>();
    when(() => mockTts.synthesize(any(), any(), voice: any(named: 'voice'), rate: any(named: 'rate')))
        .thenAnswer((_) => completer.future);

    final playFuture = notifier.playCurrentTurn(); // hangs on completer for turn 0
    final speedFuture = notifier.setSpeed(0.75);
    completer.complete(); // let every hung/future synthesize() call resolve
    await playFuture;
    await speedFuture;

    verify(() => mockTts.stop()).called(1);
    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
            voice: 'female1', rate: 0.75))
        .called(1); // the setSpeed()-triggered restart, at the new 0.75x rate
    final state = container.read(listeningComprehensionNotifierProvider).valueOrNull!;
    expect(state.speedMultiplier, 0.75);
```

Replace the entire `'setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next playCurrentTurn()'` test (including its name):
```dart
  test('setSpeed() maps 0.75x/1x/1.25x to 0.375/0.5/0.625 for the next playCurrentTurn()', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(1.25); // idle: just stores the choice
    await notifier.playCurrentTurn();

    verify(() => mockTts.speak('Hello, can I help you?', Language.english, pitch: 1.0, rate: 0.625))
        .called(1);
  });
```
with:
```dart
  test('setSpeed() passes 0.75x/1x/1.25x straight through as the playback rate for the next playCurrentTurn()', () async {
    await generateFixed();
    final notifier = container.read(listeningComprehensionNotifierProvider.notifier);

    await notifier.setSpeed(1.25); // idle: just stores the choice
    await notifier.playCurrentTurn();

    verify(() => mockTts.synthesize('Hello, can I help you?', Language.english,
            voice: 'female1', rate: 1.25))
        .called(1);
  });
```

Run: `flutter test test/features/listening/presentation/providers/listening_comprehension_provider_test.dart`
Expected: all tests pass.

- [ ] **Step 13 done**

### Step 14: Full-repo check and commit

Run:
```
flutter analyze
```
Expected: no errors or warnings beyond the 21 pre-existing `RadioListTile` deprecation infos.

Run:
```
flutter test
```
Expected: the full suite passes.

Commit:
```bash
git add pubspec.yaml pubspec.lock lib/features/dictionary/domain/entities/language.dart lib/services/tts_service.dart lib/core/di/app_providers.dart lib/core/di/app_providers.g.dart lib/features/dictionary/presentation/widgets/word_result_widget.dart lib/features/dictionary/presentation/widgets/sentence_result_widget.dart lib/features/vocabulary/presentation/screens/vocab_detail_screen.dart lib/features/listening/presentation/screens/dictation_home_screen.dart lib/features/listening/presentation/screens/comprehension_home_screen.dart lib/features/listening/presentation/providers/dictation_practice_provider.dart lib/features/listening/presentation/providers/listening_comprehension_provider.dart test/features/dictionary/domain/entities/language_test.dart test/services/tts_service_test.dart test/features/listening/presentation/screens/dictation_home_screen_test.dart test/features/listening/presentation/screens/comprehension_home_screen_test.dart test/features/listening/presentation/providers/dictation_practice_provider_test.dart test/features/listening/presentation/providers/listening_comprehension_provider_test.dart
git commit -m "feat: route Flutter TTS/pronunciation through Piper Cloud Functions, drop flutter_tts"
```

- [ ] **Step 14 done**

---

## After both tasks

Run the full suite once more (`flutter analyze && flutter test`) as a final sanity check, then proceed to the final whole-branch review per the subagent-driven-development skill.
