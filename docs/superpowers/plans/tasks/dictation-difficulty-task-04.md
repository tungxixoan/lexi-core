# Nghe chép Difficulty Levels — Task 04: DictationSessionScreen Cloze Input UI

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (`DictationSessionState.isClozeMode`/`allBlanksFilled`, `updateBlankAnswer()`)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
`DictationSessionScreen` now renders one of two UIs depending on `session.isClozeMode`:
- **Khó (`isClozeMode == false`):** exactly the existing single `TextField` bound to `typedText` — **byte-identical to what's already shipped**.
- **Dễ/Trung bình (`isClozeMode == true`):** a new inline fill-in-the-blank layout — visible words rendered as plain text, each blank rendered as a small `TextField` embedded in the flow, wired to `notifier.updateBlankAnswer(blankIndex, text)`.

"Nộp bài" enablement branches the same way: Khó uses the existing `typedText`-based check; Dễ/Trung bình requires `session.allBlanksFilled`.

## Files
- Modify: `lib/features/listening/presentation/screens/dictation_session_screen.dart`
- Modify: `test/features/listening/presentation/screens/dictation_session_screen_test.dart`

## Interfaces
- Consumes: `DictationSessionState.isClozeMode`/`allBlanksFilled`/`blanks`/`blankAnswers` (Task 02); `BlankSpan` (Task 01)
- Produces: fully functional cloze UI in `DictationSessionScreen`; Khó's existing UI/behavior unchanged

## Steps

- [ ] **Step 1: Write the failing tests**

In `test/features/listening/presentation/screens/dictation_session_screen_test.dart`, add these imports:

```dart
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
```

Update the `_session()` helper — find this exact block:

```dart
DictationSessionState _session({
  String typedText = '',
  int replayCount = 0,
  bool hasPlayedOnce = false,
  bool isComplete = false,
}) =>
    DictationSessionState(
      item: _testItem,
      typedText: typedText,
      replayCount: replayCount,
      hasPlayedOnce: hasPlayedOnce,
      startedAt: DateTime(2026),
      isComplete: isComplete,
    );
```

Replace it with:

```dart
DictationSessionState _session({
  String typedText = '',
  int replayCount = 0,
  bool hasPlayedOnce = false,
  bool isComplete = false,
  DictationDifficulty difficulty = DictationDifficulty.hard,
  List<BlankSpan> blanks = const [],
  List<String> blankAnswers = const [],
}) =>
    DictationSessionState(
      item: _testItem,
      typedText: typedText,
      replayCount: replayCount,
      hasPlayedOnce: hasPlayedOnce,
      startedAt: DateTime(2026),
      isComplete: isComplete,
      difficulty: difficulty,
      blanks: blanks,
      blankAnswers: blankAnswers,
    );
```

Then add this new group at the end of `main()`:

```dart
  group('cloze mode (Dễ/Trung bình)', () {
    // _testItem.target == 'Hello world.' — 2 words: blank both, one each.
    const clozeBlanks = [
      BlankSpan(startWordIndex: 0, wordCount: 1),
      BlankSpan(startWordIndex: 1, wordCount: 1),
    ];

    testWidgets('shows one input per blank instead of the hard-mode single TextField',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session(
        difficulty: DictationDifficulty.easy,
        blanks: clozeBlanks,
        blankAnswers: const ['', ''],
        hasPlayedOnce: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('blank-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('blank-1')), findsOneWidget);
    });

    testWidgets('Nộp bài is disabled until every blank is filled', (tester) async {
      await tester.pumpWidget(_buildSession(_session(
        difficulty: DictationDifficulty.easy,
        blanks: clozeBlanks,
        blankAnswers: const ['Hello', ''],
        hasPlayedOnce: true,
      )));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Nộp bài'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Nộp bài is enabled once every blank is filled and submits with the typed answers',
        (tester) async {
      Object? capturedExtra;
      await tester.pumpWidget(_buildSession(
        _session(
          difficulty: DictationDifficulty.easy,
          blanks: clozeBlanks,
          blankAnswers: const ['', ''],
          hasPlayedOnce: true,
        ),
        onResult: (extra) => capturedExtra = extra,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('blank-0')), 'Hello');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('blank-1')), 'world.');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Nộp bài'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();

      expect(capturedExtra, isA<DictationSessionResult>());
      final result = capturedExtra! as DictationSessionResult;
      expect(result.blankAnswers, ['Hello', 'world.']);
      expect(result.difficulty, DictationDifficulty.easy);
    });
  });
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart
```

Expected: FAIL — no widgets keyed `blank-0`/`blank-1` exist yet.

- [ ] **Step 3: Replace dictation_session_screen.dart**

Replace `lib/features/listening/presentation/screens/dictation_session_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/blank_span.dart';
import '../providers/dictation_practice_provider.dart';

class DictationSessionScreen extends ConsumerStatefulWidget {
  const DictationSessionScreen({super.key});

  @override
  ConsumerState<DictationSessionScreen> createState() =>
      _DictationSessionScreenState();
}

class _DictationSessionScreenState extends ConsumerState<DictationSessionScreen> {
  late final TextEditingController _ctrl;
  List<TextEditingController>? _blankCtrls;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _blankCtrls?.forEach((c) => c.dispose());
    super.dispose();
  }

  /// Lazily creates one controller per blank, once per screen lifetime —
  /// blanks never change after generation, so these stay stable across
  /// rebuilds (unlike constructing a fresh controller in build(), which
  /// would reset the user's cursor/focus on every keystroke).
  List<TextEditingController> _blankControllersFor(DictationSessionState session) {
    _blankCtrls ??= List.generate(
      session.blanks.length,
      (i) => TextEditingController(text: session.blankAnswers[i]),
    );
    return _blankCtrls!;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DictationSessionState?>>(
      dictationPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isComplete) {
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
            difficulty: session.difficulty,
            blanks: session.blanks,
            blankAnswers: session.blankAnswers,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/listening/dictation/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/listening/dictation');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isComplete flips to true.
        if (session.isComplete) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(
          session: session,
          ctrl: _ctrl,
          blankCtrls: session.isClozeMode ? _blankControllersFor(session) : const [],
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({
    required this.session,
    required this.ctrl,
    required this.blankCtrls,
  });

  final DictationSessionState session;
  final TextEditingController ctrl;
  final List<TextEditingController> blankCtrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dictationPracticeNotifierProvider.notifier);
    final canSubmit = session.hasPlayedOnce &&
        (session.isClozeMode
            ? session.allBlanksFilled
            : session.typedText.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe chép'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: FilledButton.icon(
                onPressed: notifier.play,
                icon: Icon(session.hasPlayedOnce ? Icons.replay : Icons.play_arrow),
                label: Text(
                  session.hasPlayedOnce
                      ? 'Nghe lại (${session.replayCount})'
                      : 'Phát',
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (session.isClozeMode)
              _ClozeInput(
                target: session.item.target,
                blanks: session.blanks,
                controllers: blankCtrls,
                onBlankChanged: notifier.updateBlankAnswer,
              )
            else
              TextField(
                controller: ctrl,
                maxLines: null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Gõ lại những gì bạn nghe được...',
                ),
                onChanged: notifier.updateTypedText,
              ),
            const Spacer(),
            FilledButton(
              onPressed: canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders [target] with each [blanks] entry replaced by an inline editable
/// text field, and everything else as plain visible text — a cloze
/// (fill-in-the-blank) layout for Dễ/Trung bình.
class _ClozeInput extends StatelessWidget {
  const _ClozeInput({
    required this.target,
    required this.blanks,
    required this.controllers,
    required this.onBlankChanged,
  });

  final String target;
  final List<BlankSpan> blanks;
  final List<TextEditingController> controllers;
  final void Function(int blankIndex, String text) onBlankChanged;

  @override
  Widget build(BuildContext context) {
    final words = target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);

    final children = <Widget>[];
    var wordIndex = 0;
    for (var blankIdx = 0; blankIdx < blanks.length; blankIdx++) {
      final blank = blanks[blankIdx];
      if (blank.startWordIndex > wordIndex) {
        final visible = words.sublist(wordIndex, blank.startWordIndex).join(' ');
        children.add(Text('$visible ', style: baseStyle));
      }
      children.add(
        IntrinsicWidth(
          child: TextField(
            key: ValueKey('blank-$blankIdx'),
            controller: controllers[blankIdx],
            style: baseStyle,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              border: UnderlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 4),
            ),
            onChanged: (text) => onBlankChanged(blankIdx, text),
          ),
        ),
      );
      children.add(const Text(' '));
      wordIndex = blank.startWordIndex + blank.wordCount;
    }
    if (wordIndex < words.length) {
      children.add(Text(words.sublist(wordIndex).join(' '), style: baseStyle));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/listening/presentation/screens/dictation_session_screen_test.dart
```

Expected: all tests pass — the original 7 Khó-mode tests (unmodified) plus the 3 new cloze-mode tests.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/dictation_session_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/dictation_session_screen.dart \
        test/features/listening/presentation/screens/dictation_session_screen_test.dart
git commit -m "feat(dictation-difficulty): add cloze input UI to DictationSessionScreen for Dễ/Trung bình"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
