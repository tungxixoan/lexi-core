# Nghe chép Difficulty Levels — Task 03: DictationHomeScreen Mức độ Picker

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (`generate({..., difficulty})`, `DictationDifficulty`)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
Adds a "Mức độ" `FilterTile` to `DictationHomeScreen` (Dễ / Trung bình / Khó), defaulting to Khó, placed after the existing Cấp độ picker. Threads the selection into `notifier.generate(..., difficulty: _difficulty)`.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_home_screen.dart`
- Modify: `test/features/listening/presentation/screens/dictation_home_screen_test.dart`

## Interfaces
- Consumes: `DictationDifficulty` (Task 01); `DictationPracticeNotifier.generate({..., difficulty})` (Task 02)
- Produces: `DictationHomeScreen` now shows and applies a difficulty selection

## Steps

- [ ] **Step 1: Write the failing tests**

In `test/features/listening/presentation/screens/dictation_home_screen_test.dart`, first extend `_FakeDictationNotifier` (modified in Task 02 to accept the `difficulty` parameter) to also **capture** it — find this exact block:

```dart
class _FakeDictationNotifier extends DictationPracticeNotifier {
  List<VocabRecord>? capturedWords;
  int callCount = 0;

  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required AppContext context,
    required Language targetLanguage,
    required CEFRLevel level,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) async {
    callCount++;
    capturedWords = words;
    // Leave state as AsyncData(null): the screen only navigates away when
    // the resulting session is non-null, so tests can stay on this screen.
  }
}
```

Replace it with:

```dart
class _FakeDictationNotifier extends DictationPracticeNotifier {
  List<VocabRecord>? capturedWords;
  DictationDifficulty? capturedDifficulty;
  int callCount = 0;

  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required AppContext context,
    required Language targetLanguage,
    required CEFRLevel level,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) async {
    callCount++;
    capturedWords = words;
    capturedDifficulty = difficulty;
    // Leave state as AsyncData(null): the screen only navigates away when
    // the resulting session is non-null, so tests can stay on this screen.
  }
}
```

Then add these tests at the end of `main()`, after the existing `'generate() prioritizes due words over not-due words'` test:

```dart
  testWidgets('shows the Mức độ picker', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mức độ'), findsOneWidget);
  });

  testWidgets('defaults to Khó and passes it to generate()', (tester) async {
    final fakeNotifier = _FakeDictationNotifier();
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
      dictationNotifier: fakeNotifier,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Khó'), findsOneWidget);

    await tester.tap(find.text('Tạo bài luyện'));
    await tester.pumpAndSettle();

    expect(fakeNotifier.capturedDifficulty, DictationDifficulty.hard);
  });
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart
```

Expected: FAIL — no "Mức độ" `FilterTile` exists yet.

- [ ] **Step 3: Add the difficulty field, picker, and FilterTile**

In `lib/features/listening/presentation/screens/dictation_home_screen.dart`, add this import:

```dart
import '../../domain/entities/dictation_difficulty.dart';
```

Find this exact block:

```dart
class _DictationHomeScreenState extends ConsumerState<DictationHomeScreen> {
  static const _minVocabWords = 2;

  late Language _language;
  final Set<String> _topicIds = {};
  CEFRLevel? _level;

  List<VocabRecord>? _matchingWords; // null while loading
```

Replace it with:

```dart
class _DictationHomeScreenState extends ConsumerState<DictationHomeScreen> {
  static const _minVocabWords = 2;

  late Language _language;
  final Set<String> _topicIds = {};
  CEFRLevel? _level;
  DictationDifficulty _difficulty = DictationDifficulty.hard;

  List<VocabRecord>? _matchingWords; // null while loading
```

Find this exact block (the `_pickLevel` method):

```dart
  Future<void> _pickLevel() async {
    final result = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Cấp độ',
      options: [
        ...CEFRLevel.values.map((l) => SelectOption(value: l, label: l.label)),
        const SelectOption<CEFRLevel?>(value: null, label: 'Tất cả'),
      ],
      selected: _level,
    );
    if (result != null) {
      setState(() => _level = result.value);
      _reload();
    }
  }
```

Add this new method immediately after it:

```dart

  Future<void> _pickDifficulty() async {
    final result = await showSingleSelectSheet<DictationDifficulty>(
      context: context,
      title: 'Mức độ',
      options: DictationDifficulty.values
          .map((d) => SelectOption(value: d, label: d.label))
          .toList(),
      selected: _difficulty,
    );
    if (result != null) {
      setState(() => _difficulty = result.value);
    }
  }
```

Find this exact block (in `build()`):

```dart
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            const SizedBox(height: 16),
```

Replace it with:

```dart
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            FilterTile(
              icon: Icons.tune,
              label: 'Mức độ',
              value: _difficulty.label,
              onTap: _pickDifficulty,
            ),
            const SizedBox(height: 16),
```

Find this exact block (in `_generate()`):

```dart
    await ref.read(dictationPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: _language,
        );
```

Replace it with:

```dart
    await ref.read(dictationPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: _language,
          difficulty: _difficulty,
        );
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_home_screen_test.dart
```

Expected: all tests pass (existing 6 + the 2 new ones from Step 1).

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/dictation_home_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_home_screen.dart \
        test/features/listening/presentation/screens/dictation_home_screen_test.dart
git commit -m "feat(dictation-difficulty): add Mức độ picker to DictationHomeScreen"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
