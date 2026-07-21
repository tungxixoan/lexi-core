import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_session_screen.dart';
import 'package:lexi_core/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {}
  @override
  Future<void> stop() async {}
}

final _testPassage = ListeningPassage(
  id: 'p1',
  kind: ListeningKind.conversation,
  turns: const [
    ListeningTurn(speaker: 'A', text: 'Can I help you?'),
    ListeningTurn(speaker: 'B', text: 'I am looking for a jacket.'),
    ListeningTurn(speaker: 'A', text: 'This way, please.'),
  ],
  questions: const [
    ListeningQuestion(question: 'Q1?', options: ['a', 'b', 'c', 'd'], correctIndex: 0),
    ListeningQuestion(question: 'Q2?', options: ['a', 'b', 'c', 'd'], correctIndex: 1),
    ListeningQuestion(question: 'Q3?', options: ['a', 'b', 'c', 'd'], correctIndex: 2),
  ],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

ListeningSessionState _session({
  int currentTurnIndex = 0,
  bool isSpeaking = false,
  List<int?>? selectedAnswers,
  bool isSubmitted = false,
}) =>
    ListeningSessionState(
      passage: _testPassage,
      currentTurnIndex: currentTurnIndex,
      isSpeaking: isSpeaking,
      playToken: 0,
      selectedAnswers: selectedAnswers ?? [null, null, null],
      isSubmitted: isSubmitted,
    );

class _FakeListeningNotifier extends ListeningComprehensionNotifier {
  _FakeListeningNotifier(this._initial);
  final ListeningSessionState _initial;
  @override
  AsyncValue<ListeningSessionState?> build() => AsyncData(_initial);
}

ComprehensionSessionResult? capturedResult;

Widget _buildSession(ListeningSessionState initial) {
  capturedResult = null;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ComprehensionSessionScreen(),
      ),
      GoRoute(
        path: '/listening/comprehension/session/result',
        builder: (ctx, state) {
          capturedResult = state.extra as ComprehensionSessionResult?;
          return const Scaffold(body: Text('Result screen'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      listeningComprehensionNotifierProvider
          .overrideWith(() => _FakeListeningNotifier(initial)),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the turn indicator for the current turn', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lượt 1/3'), findsOneWidget);
  });

  testWidgets('shows all 3 questions with 4 options each', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Q1?'), findsOneWidget);
    expect(find.textContaining('Q2?'), findsOneWidget);
    expect(find.textContaining('Q3?'), findsOneWidget);
    expect(find.byType(RadioListTile<int>), findsNWidgets(12)); // 3 questions x 4 options
  });

  testWidgets('Nộp bài is disabled until all 3 questions are answered', (tester) async {
    await tester.pumpWidget(_buildSession(_session(selectedAnswers: [0, 1, null])));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled once all 3 are answered and navigates with the right result',
      (tester) async {
    await tester.pumpWidget(_buildSession(_session(selectedAnswers: [0, 0, 2])));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();

    expect(find.text('Result screen'), findsOneWidget);
    expect(capturedResult, isNotNull);
    expect(capturedResult!.passage, same(_testPassage));
    expect(capturedResult!.selectedAnswers, [0, 0, 2]);
    expect(capturedResult!.correctCount, 2); // correctIndex 0,1,2 vs selected 0,0,2
  });

  testWidgets('⏮ is disabled on the first turn, ⏭ advances the indicator', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    final prevButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_previous),
    );
    expect(prevButton.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lượt 2/3'), findsOneWidget);
  });

  testWidgets('⏭ is disabled on the last turn', (tester) async {
    await tester.pumpWidget(_buildSession(_session(currentTurnIndex: 2)));
    await tester.pumpAndSettle();
    final nextButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.skip_next),
    );
    expect(nextButton.onPressed, isNull);
  });
}
