import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_session_screen.dart';

const _group0Doc = 'Document 0';

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

void main() {
  testWidgets('group 1 questions first; chips switch groups; double group shows two doc tabs', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.byType(BloomGroupChips), findsOneWidget);
    expect(find.textContaining('Q0-0?'), findsOneWidget);
    expect(find.textContaining(_group0Doc), findsOneWidget);
    // group 1's questions are not shown yet
    expect(find.textContaining('Q1-0?'), findsNothing);

    await tester.tap(find.text('Đoạn 3')); // the double-passage group
    await tester.pumpAndSettle();
    expect(find.text('Văn bản 1'), findsOneWidget);
    expect(find.text('Văn bản 2'), findsOneWidget);
    expect(find.textContaining('DQ0?'), findsOneWidget);
    expect(find.textContaining('Q0-0?'), findsNothing);
  });

  testWidgets('answering group 3 / question 1 writes flatIndex(groups, 2, 0)', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đoạn 3'));
    await tester.pumpAndSettle();

    final firstCardOptionB = find.descendant(
      of: find.byType(BloomCard).first,
      matching: find.text('b'),
    );
    await tester.ensureVisible(firstCardOptionB);
    await tester.tap(firstCardOptionB);
    await tester.pumpAndSettle();

    final groups = _testSet.passageGroups;
    final container = ProviderScope.containerOf(
        tester.element(find.byType(Part7SessionScreen)), listen: false);
    final answers = container.read(part7PracticeNotifierProvider).value!.selectedAnswers;
    expect(answers[Part7SessionState.flatIndex(groups, 2, 0)], 1); // 3+4+0 = 7
    expect(answers[Part7SessionState.flatIndex(groups, 0, 0)], isNull);
  });

  testWidgets('Nộp bài is disabled until every question is answered', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(session: Part7SessionState(
        set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false)));
    await tester.pumpAndSettle();
    expect(tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(session: Part7SessionState(
        set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BloomPillButton));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });

  testWidgets('answering group-by-group across all 3 groups enables Nộp bài only after the last question', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    bool enabled() => tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed != null;
    expect(enabled(), isFalse);

    // group 0: 3 questions; group 1: 4; group 2: 5. Answer option 'a' for each.
    const perGroup = [3, 4, 5];
    var answeredTotal = 0;
    for (var g = 0; g < 3; g++) {
      if (g > 0) {
        await tester.tap(find.text('Đoạn ${g + 1}'));
        await tester.pumpAndSettle();
      }
      for (var q = 0; q < perGroup[g]; q++) {
        final opt = find.descendant(of: find.byType(BloomCard).at(q), matching: find.text('a'));
        await tester.ensureVisible(opt);
        await tester.tap(opt);
        await tester.pumpAndSettle();
        answeredTotal++;
        expect(enabled(), answeredTotal == 12, reason: 'after group $g question $q');
      }
    }
  });
}
