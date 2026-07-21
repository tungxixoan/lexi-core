import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_session_screen.dart';
import 'package:lexi_core/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  int speakCount = 0;

  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0}) async {
    speakCount++;
  }

  @override
  Future<void> stop() async {}
}

final _testItem = DictationItem(
  id: 'item-1',
  target: 'Hello world.',
  vietnamese: 'Xin chào thế giới.',
  vocabIds: const [],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

DictationSessionState _session({
  DictationItem? item,
  String typedText = '',
  int replayCount = 0,
  bool hasPlayedOnce = false,
  bool isComplete = false,
  DictationDifficulty difficulty = DictationDifficulty.hard,
  List<BlankSpan> blanks = const [],
  List<String> blankAnswers = const [],
}) =>
    DictationSessionState(
      item: item ?? _testItem,
      typedText: typedText,
      replayCount: replayCount,
      hasPlayedOnce: hasPlayedOnce,
      startedAt: DateTime(2026),
      isComplete: isComplete,
      difficulty: difficulty,
      blanks: blanks,
      blankAnswers: blankAnswers,
    );

class _FakeDictationNotifier extends DictationPracticeNotifier {
  _FakeDictationNotifier(this._initial);
  final DictationSessionState _initial;
  @override
  AsyncValue<DictationSessionState?> build() => AsyncData(_initial);
}

Widget _buildSession(
  DictationSessionState initial, {
  void Function(Object? extra)? onResult,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const DictationSessionScreen(),
      ),
      GoRoute(
        path: '/listening/dictation/session/result',
        builder: (ctx, state) {
          onResult?.call(state.extra);
          return const Scaffold(body: Text('Result screen'));
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      dictationPracticeNotifierProvider
          .overrideWith(() => _FakeDictationNotifier(initial)),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows Phát button before the first play', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.text('Phát'), findsOneWidget);
  });

  testWidgets('shows a TextField for typing', (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Nộp bài is disabled before the first play', (tester) async {
    await tester.pumpWidget(_buildSession(_session(typedText: 'Hello')));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Nộp bài is enabled after playing and typing something',
      (tester) async {
    await tester.pumpWidget(
      _buildSession(_session(typedText: 'Hello', hasPlayedOnce: true)),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping play changes the button label to Nghe lại (0)',
      (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phát'));
    await tester.pumpAndSettle();
    expect(find.text('Nghe lại (0)'), findsOneWidget);
  });

  testWidgets('tapping play a second time increments to Nghe lại (1)',
      (tester) async {
    await tester.pumpWidget(_buildSession(_session()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Phát'));
    await tester.pumpAndSettle();
    expect(find.text('Nghe lại (0)'), findsOneWidget);

    await tester.tap(find.text('Nghe lại (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nghe lại (1)'), findsOneWidget);
  });

  testWidgets(
      'submitting after playing, replaying, and typing navigates to the '
      'result route with a correct DictationSessionResult', (tester) async {
    Object? capturedExtra;
    await tester.pumpWidget(
      _buildSession(
        _session(),
        onResult: (extra) => capturedExtra = extra,
      ),
    );
    await tester.pumpAndSettle();

    // Play once, then replay once more, so replayCount should end up at 1.
    await tester.tap(find.text('Phát'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe lại (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nghe lại (1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello world.');
    await tester.pumpAndSettle();

    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(submitButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();

    expect(find.text('Result screen'), findsOneWidget);
    expect(capturedExtra, isA<DictationSessionResult>());
    final result = capturedExtra! as DictationSessionResult;
    expect(result.item, _testItem);
    expect(result.typed, 'Hello world.');
    expect(result.replayCount, 1);
  });

  group('cloze mode (Dễ/Trung bình)', () {
    // _testItem.target == 'Hello world.' — 2 words: blank both, one each.
    const clozeBlanks = [
      BlankSpan(startWordIndex: 0, wordCount: 1),
      BlankSpan(startWordIndex: 1, wordCount: 1),
    ];

    testWidgets('shows one input per blank instead of the hard-mode single TextField',
        (tester) async {
      await tester.pumpWidget(_buildSession(_session(
        difficulty: DictationDifficulty.easy,
        blanks: clozeBlanks,
        blankAnswers: const ['', ''],
        hasPlayedOnce: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('blank-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('blank-1')), findsOneWidget);
    });

    testWidgets('Nộp bài is disabled until every blank is filled', (tester) async {
      await tester.pumpWidget(_buildSession(_session(
        difficulty: DictationDifficulty.easy,
        blanks: clozeBlanks,
        blankAnswers: const ['Hello', ''],
        hasPlayedOnce: true,
      )));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Nộp bài'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'Nộp bài is enabled once every blank is filled and submits with the typed answers',
        (tester) async {
      Object? capturedExtra;
      await tester.pumpWidget(_buildSession(
        _session(
          difficulty: DictationDifficulty.easy,
          blanks: clozeBlanks,
          blankAnswers: const ['', ''],
          hasPlayedOnce: true,
        ),
        onResult: (extra) => capturedExtra = extra,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('blank-0')), 'Hello');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('blank-1')), 'world.');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Nộp bài'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();

      expect(capturedExtra, isA<DictationSessionResult>());
      final result = capturedExtra! as DictationSessionResult;
      expect(result.blankAnswers, ['Hello', 'world.']);
      expect(result.difficulty, DictationDifficulty.easy);
    });

    // clozeBlanks above blanks both words of the 2-word _testItem, so it
    // never exercises the visible-text-between-blanks branch of
    // _ClozeInput, nor a multi-word (wordCount > 1) blank. Use a longer
    // sentence for those two cases.
    // Word indices: 0 The, 1 quick, 2 brown, 3 fox, 4 jumps, 5 over,
    // 6 the, 7 lazy, 8 dog.
    final longItem = DictationItem(
      id: 'item-2',
      target: 'The quick brown fox jumps over the lazy dog',
      vietnamese: 'Con cáo nâu nhanh nhẹn nhảy qua con chó lười biếng',
      vocabIds: const [],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime(2026),
    );

    testWidgets(
        'renders visible text before, between, and after non-adjacent blanks',
        (tester) async {
      const blanks = [
        BlankSpan(startWordIndex: 1, wordCount: 1), // "quick"
        BlankSpan(startWordIndex: 6, wordCount: 1), // "the"
      ];
      await tester.pumpWidget(_buildSession(_session(
        item: longItem,
        difficulty: DictationDifficulty.easy,
        blanks: blanks,
        blankAnswers: const ['', ''],
        hasPlayedOnce: true,
      )));
      await tester.pumpAndSettle();

      // Visible segments before the first blank, between the two blanks,
      // and after the second blank must actually render as plain text.
      expect(find.text('The '), findsOneWidget);
      expect(find.text('brown fox jumps over '), findsOneWidget);
      expect(find.text('lazy dog'), findsOneWidget);

      // Both blanks are still rendered as inputs.
      expect(find.byKey(const ValueKey('blank-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('blank-1')), findsOneWidget);
    });

    testWidgets(
        'a multi-word (Trung bình) blank renders as a single TextField and '
        'submits the typed phrase as one blankAnswers entry', (tester) async {
      const blanks = [
        BlankSpan(startWordIndex: 2, wordCount: 3), // "brown fox jumps"
      ];
      Object? capturedExtra;
      await tester.pumpWidget(_buildSession(
        _session(
          item: longItem,
          difficulty: DictationDifficulty.medium,
          blanks: blanks,
          blankAnswers: const [''],
          hasPlayedOnce: true,
        ),
        onResult: (extra) => capturedExtra = extra,
      ));
      await tester.pumpAndSettle();

      // Visible context on both sides of the single 3-word blank.
      expect(find.text('The quick '), findsOneWidget);
      expect(find.text('over the lazy dog'), findsOneWidget);

      // One TextField stands in for all 3 words — not one per word.
      expect(find.byKey(const ValueKey('blank-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('blank-1')), findsNothing);

      await tester.enterText(
          find.byKey(const ValueKey('blank-0')), 'brown fox jumps');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Nộp bài'),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
      await tester.pumpAndSettle();

      expect(capturedExtra, isA<DictationSessionResult>());
      final result = capturedExtra! as DictationSessionResult;
      expect(result.blankAnswers, ['brown fox jumps']);
      expect(result.difficulty, DictationDifficulty.medium);
    });
  });
}
