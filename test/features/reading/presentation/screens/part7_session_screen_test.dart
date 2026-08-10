import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_session_screen.dart';

Part7PassageGroup _singleGroup(int i, int questionCount) => Part7PassageGroup(
      documents: ['Document $i'],
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'E$i-$q',
        ),
      ),
    );

Part7PassageGroup _doubleGroup() => Part7PassageGroup(
      documents: const ['Document A', 'Document B'],
      questions: List.generate(
        5,
        (q) => Part7Question(
          question: 'DQ$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'DE$q',
        ),
      ),
    );

final _testSet = Part7Set(
  id: 'test',
  passageGroups: [_singleGroup(0, 3), _singleGroup(1, 4), _doubleGroup()],
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part7SessionState(
  set: _testSet,
  selectedAnswers: List<int?>.filled(12, null),
  isSubmitted: false,
);

class _FakePart7Notifier extends Part7PracticeNotifier {
  _FakePart7Notifier(this._session);
  final Part7SessionState _session;

  @override
  AsyncValue<Part7SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part7SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part7SessionScreen()),
      GoRoute(
        path: '/reading/part7/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part7',
        builder: (ctx, state) => const Scaffold(body: Text('Part7 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part7PracticeNotifierProvider
          .overrideWith(() => _FakePart7Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Locates the `Column` built by `_QuestionGroup` for the question whose
/// rendered text contains [questionTextSubstring] (e.g. `'Q1-2?'`), so a
/// specific option tile can be searched for within that scope only.
Finder _questionColumn(String questionTextSubstring) {
  final questionFinder = find.textContaining(questionTextSubstring);
  return find
      .ancestor(of: questionFinder, matching: find.byWidgetPredicate((w) => w is Column))
      .first;
}

/// Locates the `RadioListTile<int>` within [questionScope] whose title text
/// equals [optionText] (e.g. `'a'`..`'d'`).
Finder _optionTile(Finder questionScope, String optionText) {
  return find.descendant(
    of: questionScope,
    matching: find.byWidgetPredicate(
      (w) => w is RadioListTile<int> && (w.title as Text?)?.data == optionText,
    ),
  );
}

void main() {
  testWidgets('shows all 3 groups\' documents, including both documents of the double-passage group',
      (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Document 0'), findsOneWidget);
    expect(find.textContaining('Document 1'), findsOneWidget);
    expect(find.textContaining('Document A'), findsOneWidget);
    expect(find.textContaining('Document B'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part7SessionState(set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part7SessionState(set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });

  testWidgets(
      'tapping an option threads the correct group/question index end-to-end '
      'and Nộp bài only enables once every question across all 3 groups is answered',
      (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();

    FilledButton submitButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    bool submitEnabled() => submitButton().onPressed != null;

    expect(submitEnabled(), isFalse);

    // Group 1 (the second single-passage group, 4 questions), question index 2
    // (0-based) — a non-first group/question where a swapped or miscaptured
    // groupIndex/questionIndex would visibly select the wrong tile.
    final targetQuestion = _questionColumn('Q1-2?');
    final targetOptionC = _optionTile(targetQuestion, 'c');
    await tester.ensureVisible(targetOptionC);
    await tester.tap(targetOptionC);
    await tester.pumpAndSettle();

    // The tapped question now shows option 'c' (index 2) as selected...
    final tappedTile = tester.widget<RadioListTile<int>>(_optionTile(targetQuestion, 'c'));
    expect(tappedTile.groupValue, 2);

    // ...while a sibling question in the SAME group remains untouched...
    final siblingTile =
        tester.widget<RadioListTile<int>>(_optionTile(_questionColumn('Q1-0?'), 'a'));
    expect(siblingTile.groupValue, isNull);

    // ...and a question in the double-passage group (a different groupIndex)
    // is also untouched.
    final otherGroupTile =
        tester.widget<RadioListTile<int>>(_optionTile(_questionColumn('DQ0?'), 'a'));
    expect(otherGroupTile.groupValue, isNull);

    expect(submitEnabled(), isFalse);

    // Now answer every remaining question, in flat (group-major) order, and
    // confirm the submit button flips to enabled only after the very last
    // one — proving the dynamic total-question count (3 + 4 + 5 = 12) and
    // per-group indexing work end-to-end, not just at the notifier level.
    const questionsInFlatOrder = [
      'Q0-0?', 'Q0-1?', 'Q0-2?', // group 0 (3 questions)
      'Q1-0?', 'Q1-1?', 'Q1-2?', 'Q1-3?', // group 1 (4 questions)
      'DQ0?', 'DQ1?', 'DQ2?', 'DQ3?', 'DQ4?', // group 2, double-passage (5 questions)
    ];
    const options = ['a', 'b', 'c', 'd'];

    for (var i = 0; i < questionsInFlatOrder.length; i++) {
      final scope = _questionColumn(questionsInFlatOrder[i]);
      final tile = _optionTile(scope, options[i % options.length]);
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final isLast = i == questionsInFlatOrder.length - 1;
      expect(submitEnabled(), isLast, reason: 'after tapping "${questionsInFlatOrder[i]}"');
    }
  });
}
