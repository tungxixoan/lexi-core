# Plan 7 — Task 05: ReadingSessionScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 7 Task 03 (provider wired, stub `reading_session_screen.dart` exists); Task 04 (home screen navigates to `/reading/session`)

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
The 3-row session UI: (1) passage with progressive opacity per sentence and vocab words highlighted; (2) current Vietnamese translation; (3) character-by-character typing area. Auto-advances to next sentence on completion; navigates to result screen when passage is complete.

## Files
- Modify: `lib/features/reading/presentation/screens/reading_session_screen.dart`

## Interfaces
- Consumes:
  - `readingPracticeNotifierProvider` — for session state + `updateTypedText()`
  - `vocabBankProvider` — to look up headwords for vocab highlighting
  - `ReadingSessionResult` from `reading_practice_provider.dart`
- Produces: fully functional `ReadingSessionScreen`

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/reading/presentation/screens/reading_session_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_session_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

final _testPassage = ReadingPassage(
  id: 'test',
  sentences: const [
    BilingualSentence(
      target: 'Hello.',
      vietnamese: 'Xin chào.',
      vocabIds: [],
    ),
    BilingualSentence(
      target: 'World.',
      vietnamese: 'Thế giới.',
      vocabIds: [],
    ),
  ],
  vocabIds: const [],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = ReadingSessionState(
  passage: _testPassage,
  currentSentenceIndex: 0,
  typedText: '',
  completedSentences: const [],
  sessionStartedAt: DateTime(2026),
  sentenceStartedAt: DateTime(2026),
  isComplete: false,
);

Widget _buildSession() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ReadingSessionScreen(),
      ),
      GoRoute(
        path: '/reading/session/result',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Result screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      readingPracticeNotifierProvider
          .overrideWith(() => _FakeReadingNotifier(_testSession)),
      vocabBankProvider.overrideWith((_) => const []),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeReadingNotifier extends ReadingPracticeNotifier {
  _FakeReadingNotifier(this._session);
  final ReadingSessionState _session;
  @override
  AsyncValue<ReadingSessionState?> build() => AsyncData(_session);
}

void main() {
  testWidgets('shows current sentence target text', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello.'), findsWidgets);
  });

  testWidgets('shows Vietnamese translation of current sentence', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.text('Xin chào.'), findsOneWidget);
  });

  testWidgets('shows a TextField for typing', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/reading/presentation/screens/reading_session_screen_test.dart
```

Expected: FAIL — stub screen doesn't render the passage.

- [ ] **Step 3: Replace reading_session_screen.dart**

Replace `lib/features/reading/presentation/screens/reading_session_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/reading_passage.dart';
import '../providers/reading_practice_provider.dart';

class ReadingSessionScreen extends ConsumerStatefulWidget {
  const ReadingSessionScreen({super.key});

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTyped(String text, ReadingSessionState session) {
    ref.read(readingPracticeNotifierProvider.notifier).updateTypedText(text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ReadingSessionState?>>(
      readingPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        final prevIndex = prev?.valueOrNull?.currentSentenceIndex;
        if (prevIndex != null &&
            session.currentSentenceIndex != prevIndex) {
          _ctrl.clear();
          _focusNode.requestFocus();
        }

        if (session.isComplete) {
          final result = ReadingSessionResult(
            passage: session.passage,
            sentenceResults: session.completedSentences,
            totalDuration:
                DateTime.now().difference(session.sessionStartedAt),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/reading/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(readingPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/reading');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(
          session: session,
          ctrl: _ctrl,
          focusNode: _focusNode,
          onTyped: _onTyped,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({
    required this.session,
    required this.ctrl,
    required this.focusNode,
    required this.onTyped,
  });

  final ReadingSessionState session;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final void Function(String, ReadingSessionState) onTyped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabRecords = ref.watch(vocabBankProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Câu ${session.currentSentenceIndex + 1} / ${session.passage.sentences.length}',
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: passage with opacity
            Expanded(
              child: _PassageDisplay(
                passage: session.passage,
                currentIndex: session.currentSentenceIndex,
                vocabRecords: vocabRecords,
              ),
            ),
            const Divider(height: 24),
            // Row 2: Vietnamese translation
            _VietnameseRow(
              sentence: session.currentSentence,
            ),
            const SizedBox(height: 16),
            // Row 3: typing area
            _TypingArea(
              target: session.currentSentence.target,
              typedText: session.typedText,
              ctrl: ctrl,
              focusNode: focusNode,
              onTyped: (text) => onTyped(text, session),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (session.currentSentenceIndex) /
                  session.passage.sentences.length,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassageDisplay extends StatelessWidget {
  const _PassageDisplay({
    required this.passage,
    required this.currentIndex,
    required this.vocabRecords,
  });

  final ReadingPassage passage;
  final int currentIndex;
  final List<VocabRecord> vocabRecords;

  double _opacity(int sentenceIndex) {
    final delta = sentenceIndex - currentIndex;
    if (delta < 0) return 0.3; // already typed
    if (delta == 0) return 1.0; // current
    if (delta == 1) return 0.4; // next
    return 0.2; // locked
  }

  List<String> _getHighlightWords(BilingualSentence sentence) {
    return sentence.vocabIds
        .map((id) => vocabRecords
            .where((r) => r.id == id)
            .map((r) => r.headword)
            .firstOrNull)
        .whereType<String>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: passage.sentences.asMap().entries.map((entry) {
          final i = entry.key;
          final sentence = entry.value;
          final highlights = _getHighlightWords(sentence);
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _opacity(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _HighlightedText(
                text: sentence.target,
                highlights: highlights,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    this.style,
  });

  final String text;
  final List<String> highlights;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Text(text, style: style);
    }
    final spans = <TextSpan>[];
    String remaining = text;
    while (remaining.isNotEmpty) {
      int? earliestStart;
      String? earliestWord;
      for (final word in highlights) {
        final idx = remaining.toLowerCase().indexOf(word.toLowerCase());
        if (idx >= 0 && (earliestStart == null || idx < earliestStart)) {
          earliestStart = idx;
          earliestWord = word;
        }
      }
      if (earliestStart == null || earliestWord == null) {
        spans.add(TextSpan(text: remaining, style: style));
        break;
      }
      if (earliestStart > 0) {
        spans.add(
            TextSpan(text: remaining.substring(0, earliestStart), style: style));
      }
      spans.add(TextSpan(
        text: remaining.substring(
            earliestStart, earliestStart + earliestWord.length),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ));
      remaining = remaining.substring(earliestStart + earliestWord.length);
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

class _VietnameseRow extends StatelessWidget {
  const _VietnameseRow({required this.sentence});
  final BilingualSentence sentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(sentence.target),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          sentence.vietnamese,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

class _TypingArea extends StatelessWidget {
  const _TypingArea({
    required this.target,
    required this.typedText,
    required this.ctrl,
    required this.focusNode,
    required this.onTyped,
  });

  final String target;
  final String typedText;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ValueChanged<String> onTyped;

  List<TextSpan> _buildSpans(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    for (int i = 0; i < target.length; i++) {
      if (i < typedText.length) {
        final correct = typedText[i] == target[i];
        spans.add(TextSpan(
          text: typedText[i],
          style: TextStyle(
            color: correct
                ? Colors.green
                : theme.colorScheme.error,
            backgroundColor: correct
                ? null
                : theme.colorScheme.error.withOpacity(0.1),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: target[i],
          style: TextStyle(color: theme.colorScheme.outline),
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          IgnorePointer(
            child: RichText(
              text: TextSpan(children: _buildSpans(context)),
            ),
          ),
          TextField(
            controller: ctrl,
            focusNode: focusNode,
            maxLines: null,
            autofocus: true,
            style: const TextStyle(color: Colors.transparent),
            cursorColor: theme.colorScheme.primary,
            decoration: const InputDecoration.collapsed(hintText: ''),
            onChanged: onTyped,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/reading/presentation/screens/reading_session_screen_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/reading/presentation/screens/reading_session_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_session_screen.dart \
        test/features/reading/presentation/screens/reading_session_screen_test.dart
git commit -m "feat(plan7): implement ReadingSessionScreen with 3-row typing UI"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any — e.g., transparent TextField on web; opacity animation behavior)
