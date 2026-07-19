import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_session_screen.dart';
import 'package:lexi_core/services/tts_service.dart';

class _FakeTtsService implements TtsService {
  int speakCount = 0;

  @override
  Future<void> speak(String text, Language language) async {
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
  String typedText = '',
  int replayCount = 0,
  bool hasPlayedOnce = false,
  bool isComplete = false,
}) =>
    DictationSessionState(
      item: _testItem,
      typedText: typedText,
      replayCount: replayCount,
      hasPlayedOnce: hasPlayedOnce,
      startedAt: DateTime(2026),
      isComplete: isComplete,
    );

class _FakeDictationNotifier extends DictationPracticeNotifier {
  _FakeDictationNotifier(this._initial);
  final DictationSessionState _initial;
  @override
  AsyncValue<DictationSessionState?> build() => AsyncData(_initial);
}

Widget _buildSession(DictationSessionState initial) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const DictationSessionScreen(),
      ),
      GoRoute(
        path: '/listening/dictation/session/result',
        builder: (ctx, state) => const Scaffold(body: Text('Result screen')),
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
}
