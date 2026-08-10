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
}
