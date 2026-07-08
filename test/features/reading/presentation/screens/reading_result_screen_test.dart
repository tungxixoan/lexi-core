import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_result_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

final _testResult = ReadingSessionResult(
  passage: ReadingPassage(
    id: 'p1',
    sentences: const [
      BilingualSentence(
        target: 'Hello world.',
        vietnamese: 'Xin chào thế giới.',
        vocabIds: [],
      ),
    ],
    vocabIds: const [],
    level: CEFRLevel.b1,
    context: AppContext.general,
    targetLanguage: Language.english,
    generatedAt: DateTime(2026),
  ),
  sentenceResults: const [
    SentenceResult(
      target: 'Hello world.',
      typed: 'Hello world.',
      correctChars: 12,
      totalChars: 12,
      durationMs: 5000,
    ),
  ],
  totalDuration: const Duration(seconds: 5),
);

Widget _buildResult() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ReadingResultScreen(result: _testResult),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabBankProvider.overrideWith((_) => const []),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows accuracy percentage', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% accuracy
  });

  testWidgets('shows regenerate and home buttons', (tester) async {
    await tester.pumpWidget(_buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Sinh bài mới'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });
}
