import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part5_question.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/reading/presentation/providers/part5_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_session_screen.dart';

final _testSet = Part5Set(
  id: 'test',
  questions: List.generate(
    3,
    (i) => Part5Question(
      sentenceWithBlank: 'Sentence $i ___.',
      options: const ['a', 'b', 'c', 'd'],
      correctIndex: i % 4,
      explanation: 'Explanation $i',
    ),
  ),
  volumes: const {EconomyVolume.vol3},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _testSession = Part5SessionState(
  set: _testSet,
  selectedAnswers: const [null, null, null],
  isSubmitted: false,
);

class _FakePart5Notifier extends Part5PracticeNotifier {
  _FakePart5Notifier(this._session);
  final Part5SessionState _session;

  @override
  AsyncValue<Part5SessionState?> build() => AsyncData(_session);
}

Widget _buildSession({Part5SessionState? session}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part5SessionScreen()),
      GoRoute(
        path: '/reading/part5/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
      GoRoute(
        path: '/reading/part5',
        builder: (ctx, state) => const Scaffold(body: Text('Part5 home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      part5PracticeNotifierProvider
          .overrideWith(() => _FakePart5Notifier(session ?? _testSession)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows all 3 question sentences', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Sentence 0 ___.'), findsOneWidget);
    expect(find.textContaining('Sentence 1 ___.'), findsOneWidget);
    expect(find.textContaining('Sentence 2 ___.'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<BloomPillButton>(find.byType(BloomPillButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part5SessionState(set: _testSet, selectedAnswers: const [0, 1, 2], isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<BloomPillButton>(find.byType(BloomPillButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('selecting an option and submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part5SessionState(set: _testSet, selectedAnswers: const [0, 1, 2], isSubmitted: false),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BloomPillButton));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });

  testWidgets('tapping an option writes only that question slot', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();

    final optionB = find.descendant(
      of: find.byType(BloomCard).at(1),
      matching: find.text('b'),
    );
    expect(optionB, findsOneWidget);
    await tester.tap(optionB);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Part5SessionScreen)),
      listen: false,
    );
    final selectedAnswers =
        container.read(part5PracticeNotifierProvider).value!.selectedAnswers;
    expect(selectedAnswers[1], 1);
    expect(selectedAnswers[0], isNull);
  });
}
