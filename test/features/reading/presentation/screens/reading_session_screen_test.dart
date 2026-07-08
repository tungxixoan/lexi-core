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
