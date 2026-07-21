import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_result_screen.dart';

final _testPassage = ListeningPassage(
  id: 'p1',
  kind: ListeningKind.conversation,
  turns: const [
    ListeningTurn(speaker: 'A', text: 'Can I help you?'),
    ListeningTurn(speaker: 'B', text: 'I am looking for a jacket.'),
  ],
  questions: const [
    ListeningQuestion(question: 'Where are they?', options: ['Store', 'Airport', 'Home', 'School'], correctIndex: 0),
    ListeningQuestion(question: 'What do they want?', options: ['Shoes', 'A jacket', 'A book', 'A ticket'], correctIndex: 1),
    ListeningQuestion(question: 'Who is speaking first?', options: ['A', 'B', 'Both', 'Neither'], correctIndex: 0),
  ],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// selectedAnswers: [0 (correct), 0 (wrong, correct is 1), 0 (correct)] -> 2/3
final _testResult = ComprehensionSessionResult(
  passage: _testPassage,
  selectedAnswers: const [0, 0, 0],
);

Widget _buildResult() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ComprehensionResultScreen(result: _testResult),
      ),
      GoRoute(
        path: '/listening/comprehension',
        builder: (ctx, state) => const Scaffold(body: Text('Comprehension home')),
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

void main() {
  testWidgets('shows the score as correctCount/total', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('shows all 3 question texts and the transcript turns', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Where are they?'), findsOneWidget);
    expect(find.textContaining('What do they want?'), findsOneWidget);
    expect(find.textContaining('Who is speaking first?'), findsOneWidget);
    expect(find.textContaining('Can I help you?'), findsOneWidget);
    expect(find.textContaining('I am looking for a jacket.'), findsOneWidget);
  });

  testWidgets('shows correct/incorrect icons matching correctCount', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel), findsNWidgets(1));
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });
}
