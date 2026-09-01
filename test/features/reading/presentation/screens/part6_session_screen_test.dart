import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part6_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part6_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part6_session_screen.dart';

Part6Passage _passage(int i) => Part6Passage(
      passageText: 'Passage $i (1)___ (2)___ (3)___ (4)___.',
      questions: List.generate(
        4,
        (q) => Part6Question(
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: q % 4,
          explanation: 'Explanation $i-$q',
        ),
      ),
    );

final _testSet = Part6Set(
  id: 'test',
  passages: List.generate(3, _passage),
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part6SessionState(
  set: _testSet,
  selectedAnswers: List<int?>.filled(12, null),
  isSubmitted: false,
);

class _FakePart6Notifier extends Part6PracticeNotifier {
  _FakePart6Notifier(this._session);
  final Part6SessionState _session;

  @override
  AsyncValue<Part6SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part6SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part6SessionScreen()),
      GoRoute(
        path: '/reading/part6/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part6',
        builder: (ctx, state) => const Scaffold(body: Text('Part6 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part6PracticeNotifierProvider
          .overrideWith(() => _FakePart6Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows passage 1 questions first; chips switch passages', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.text('Chỗ trống (1)'), findsOneWidget);
    expect(find.byType(BloomGroupChips), findsOneWidget);
    expect(find.textContaining('Passage 0'), findsOneWidget);

    await tester.tap(find.text('Đoạn 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Passage 1'), findsOneWidget);
    expect(find.textContaining('Passage 0'), findsNothing);
  });

  testWidgets('expanding a blank and picking an option writes only that flat slot', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Chỗ trống (3)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỗ trống (3)')); // q index 2 — distinct from option index, catches an arg-order swap
    await tester.pumpAndSettle();
    final bInTile3 = find.descendant(
      of: find.ancestor(of: find.text('Chỗ trống (3)'), matching: find.byType(BloomExpansionTile)),
      matching: find.text('b'),
    );
    await tester.ensureVisible(bInTile3);
    await tester.tap(bInTile3);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Part6SessionScreen)), listen: false);
    final answers = container.read(part6PracticeNotifierProvider).value!.selectedAnswers;
    expect(answers[Part6SessionState.flatIndex(0, 2)], 1);
    expect(answers[Part6SessionState.flatIndex(0, 0)], isNull);
  });

  testWidgets('Nộp bài is disabled until all 12 blanks are answered', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 blanks are answered', (tester) async {
    await tester.pumpWidget(_buildSession(session: Part6SessionState(
      set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false)));
    await tester.pumpAndSettle();
    expect(tester.widget<BloomPillButton>(find.byType(BloomPillButton)).onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(session: Part6SessionState(
      set: _testSet, selectedAnswers: List<int?>.filled(12, 0), isSubmitted: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BloomPillButton));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });
}
