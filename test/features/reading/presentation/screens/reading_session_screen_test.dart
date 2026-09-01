import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
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
        path: '/reading/bilingual/session/result',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Result screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      readingPracticeNotifierProvider
          .overrideWith(() => _FakeReadingNotifier(_testSession)),
      vocabListForLanguageProvider(Language.english)
          .overrideWith((ref) => const []),
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

final _highlightVocab = VocabRecord(
  id: 'v-world',
  headword: 'world',
  inputType: InputType.word,
  ipa: '',
  meaning: 'thế giới',
  examples: const [],
  personalNotes: '',
  topicIds: const [],
  targetLanguage: Language.english,
  cefrLevel: CEFRLevel.b1,
  activeContext: AppContext.general,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _highlightPassage = ReadingPassage(
  id: 'test-highlight',
  sentences: const [
    BilingualSentence(
      target: 'The world is amazing.',
      vietnamese: 'Thế giới thật tuyệt vời.',
      vocabIds: ['v-world'],
    ),
  ],
  vocabIds: const ['v-world'],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _highlightSession = ReadingSessionState(
  passage: _highlightPassage,
  currentSentenceIndex: 0,
  typedText: '',
  completedSentences: const [],
  sessionStartedAt: DateTime(2026),
  sentenceStartedAt: DateTime(2026),
  isComplete: false,
);

Widget _buildHighlightSession() {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ReadingSessionScreen(),
      ),
      GoRoute(
        path: '/reading/bilingual/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      readingPracticeNotifierProvider
          .overrideWith(() => _FakeReadingNotifier(_highlightSession)),
      vocabListForLanguageProvider(Language.english)
          .overrideWith((ref) => [_highlightVocab]),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Iterable<TextStyle> _allSpanStyles(InlineSpan span) sync* {
  if (span is TextSpan) {
    if (span.style != null) yield span.style!;
    for (final child in span.children ?? const <InlineSpan>[]) {
      yield* _allSpanStyles(child);
    }
  }
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

  testWidgets('shows a Bloom progress bar', (tester) async {
    await tester.pumpWidget(_buildSession());
    await tester.pumpAndSettle();
    expect(find.byType(BloomProgressBar), findsOneWidget);
  });

  testWidgets(
      'highlighted passage sentence keeps Be Vietnam Pro on every span',
      (tester) async {
    await tester.pumpWidget(_buildHighlightSession());
    await tester.pumpAndSettle();

    // The passage lives in a BloomCard; _HighlightedText renders it via a
    // bare RichText that does not inherit the ambient DefaultTextStyle.
    final richTexts = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(BloomCard),
            matching: find.byType(RichText),
          ),
        )
        .where((w) => w.text.toPlainText().contains('The world is amazing.'))
        .toList();
    expect(richTexts, isNotEmpty);

    final styles = richTexts.expand((w) => _allSpanStyles(w.text)).toList();
    expect(styles, isNotEmpty);
    // Every span (plain + the bolded "world" highlight) must carry the font.
    for (final style in styles) {
      expect(style.fontFamily, 'BeVietnamPro');
    }
  });
}
