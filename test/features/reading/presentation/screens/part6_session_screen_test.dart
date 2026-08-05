import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  testWidgets('shows all 3 passage texts', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.textContaining('Passage 0'), findsOneWidget);
    expect(find.textContaining('Passage 1'), findsOneWidget);
    expect(find.textContaining('Passage 2'), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled until all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 12 answers are selected', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part6SessionState(
        set: _testSet,
        selectedAnswers: List<int?>.filled(12, 0),
        isSubmitted: false,
      ),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Nộp bài'));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('submitting navigates to the result screen', (tester) async {
    await tester.pumpWidget(_buildSession(
      session: Part6SessionState(
        set: _testSet,
        selectedAnswers: List<int?>.filled(12, 0),
        isSubmitted: false,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();
    expect(find.text('Result screen'), findsOneWidget);
  });

  testWidgets(
      'tapping the option for passage 1 / question 2 writes only that flat slot',
      (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();

    // RadioListTiles are rendered passage-major, then question-major, then
    // option-major: 4 questions x 4 options = 16 tiles per passage.
    // Passage 1 (index 1), question 2 (index 2), option 1 ("b") sits at:
    const passageIndex = 1;
    const questionIndex = 2;
    const optionIndex = 1;
    const tileIndex = passageIndex * 16 + questionIndex * 4 + optionIndex;

    final tiles = find.byType(RadioListTile<int>);
    expect(tiles, findsNWidgets(48));
    await tester.ensureVisible(tiles.at(tileIndex));
    await tester.pumpAndSettle();
    await tester.tap(tiles.at(tileIndex));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Part6SessionScreen)),
      listen: false,
    );
    final selectedAnswers =
        container.read(part6PracticeNotifierProvider).value!.selectedAnswers;

    // The tapped slot got the tapped option...
    expect(
      selectedAnswers[Part6SessionState.flatIndex(passageIndex, questionIndex)],
      optionIndex,
    );
    // ...and an untouched slot (passage 0 / question 0) is unaffected. If the
    // (passageIndex, questionIndex) arguments to selectAnswer were ever
    // swapped, or flatIndex broken, this pair of assertions would fail
    // because every slot would no longer be independently addressable.
    expect(
      selectedAnswers[Part6SessionState.flatIndex(0, 0)],
      isNull,
    );
  });
}
