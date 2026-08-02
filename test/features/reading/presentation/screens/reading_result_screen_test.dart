import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart'
    show WordPhraseResult;
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_result_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';

class MockStatsService extends Mock implements StatsService {}

class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

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

final _testResultWithBackspaces = ReadingSessionResult(
  passage: ReadingPassage(
    id: 'p2',
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
      deletedChars: 6,
    ),
  ],
  totalDuration: const Duration(seconds: 5),
);

Future<Widget> _buildResultWithBackspaces() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ReadingResultScreen(result: _testResultWithBackspaces),
      ),
      GoRoute(
        path: '/reading',
        builder: (ctx, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabBankProvider.overrideWith((_) => const []),
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: true)),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<Widget> _buildResult({
  ReadingSessionResult? result,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ReadingResultScreen(result: result ?? _testResult),
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
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: true)),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  testWidgets('shows accuracy percentage', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% accuracy
  });

  testWidgets('shows regenerate and home buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Sinh bài mới'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('shows a score stat card labeled Điểm', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Điểm'), findsOneWidget);
  });

  testWidgets('score reflects the deletion penalty subtracted from accuracy', (tester) async {
    await tester.pumpWidget(await _buildResultWithBackspaces());
    await tester.pumpAndSettle();
    // deletionRatio = 6/12 = 0.5; penalty = 0.5 * 0.5 = 0.25; 100% - 25% = 75.0%
    expect(find.text('75.0%'), findsOneWidget);
  });

  testWidgets('records a practice session (for the streak) with the passage vocab count',
      (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});
    final resultWithVocab = ReadingSessionResult(
      passage: ReadingPassage(
        id: 'p3',
        sentences: const [
          BilingualSentence(
            target: 'Hello world.',
            vietnamese: 'Xin chào thế giới.',
            vocabIds: ['id1', 'id2'],
          ),
        ],
        vocabIds: const ['id1', 'id2'],
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

    await tester.pumpWidget(await _buildResult(
      result: resultWithVocab,
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockStats.recordPracticeSession(2)).called(1);
  });

  testWidgets(
      'loads new-word suggestions for the full passage text and shows them',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async => const WordRadarAiResult(
          translation: '',
          suggestions: [
            WordPhraseResult(
              headword: 'ubiquitous',
              inputType: InputType.word,
              ipa: '/juːˈbɪkwɪtəs/',
              meaning: 'có mặt khắp nơi',
              examples: [],
              suggestedTopics: [],
            ),
          ],
        ));

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'Hello world.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });

  testWidgets('does not crash when loading suggestions fails', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenThrow(Exception('AI unavailable'));

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sinh bài mới'), findsOneWidget); // screen still renders
    expect(find.textContaining('Không tải được gợi ý'), findsOneWidget);
  });

  testWidgets('does not load suggestions when AI is disabled in settings', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [
        userSettingsNotifierProvider.overrideWith(
          () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(aiEnabled: false)),
        ),
        getVocabSuggestionsForTextUseCaseProvider.overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    verifyNever(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        ));
    expect(find.text('Gợi ý từ mới'), findsNothing);
  });
}
