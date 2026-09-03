import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/listening/domain/entities/listening_passage.dart';
import 'package:lexi_core/features/listening/presentation/providers/listening_comprehension_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_result_screen.dart';
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

final _testPassage = ListeningPassage(
  id: 'p1',
  kind: ListeningKind.conversation,
  turns: const [
    ListeningTurn(speaker: 'A', text: 'Can I help you?'),
    ListeningTurn(speaker: 'B', text: 'I am looking for a jacket.'),
  ],
  questions: const [
    ListeningQuestion(
        question: 'Where are they?',
        options: ['Store', 'Airport', 'Home', 'School'],
        correctIndex: 0),
    ListeningQuestion(
        question: 'What do they want?',
        options: ['Shoes', 'A jacket', 'A book', 'A ticket'],
        correctIndex: 1),
    ListeningQuestion(
        question: 'Who is speaking first?',
        options: ['A', 'B', 'Both', 'Neither'],
        correctIndex: 0),
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

Future<Widget> _buildResult({List<Override> extraOverrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => ComprehensionResultScreen(result: _testResult),
      ),
      GoRoute(
        path: '/listening/comprehension',
        builder: (ctx, state) =>
            const Scaffold(body: Text('Comprehension home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(
            providerConfigs: {
              AiProvider.gemini: const ProviderConfig(
                  apiKeyCiphertext: 'ck', model: 'gemini-2.5-flash'),
            },
          ),
        ),
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

  testWidgets('shows the score as correctCount/total', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('shows all 3 question texts and the transcript turns',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Where are they?'), findsOneWidget);
    expect(find.textContaining('What do they want?'), findsOneWidget);
    expect(find.textContaining('Who is speaking first?'), findsOneWidget);
    expect(find.textContaining('Can I help you?'), findsOneWidget);
    expect(find.textContaining('I am looking for a jacket.'), findsOneWidget);
  });

  testWidgets('shows correct/incorrect icons matching correctCount',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel), findsNWidgets(1));
  });

  testWidgets('renders the option breakdown as read-only BloomMcOption tiles',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.byType(BloomMcOption), findsWidgets);
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets(
      'records a practice session (for the streak) with the question count',
      (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    // _testPassage.questions has 3 items.
    verify(() => mockStats.recordPracticeSession(3)).called(1);
  });

  testWidgets(
      'loads new-word suggestions for the full transcript text and shows them',
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
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions),
      ],
    ));
    await tester.pumpAndSettle();

    // _testPassage.turns joined: "Can I help you? I am looking for a jacket."
    verify(() => mockSuggestions.execute(
          text: 'Can I help you? I am looking for a jacket.',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });

  testWidgets('does not load suggestions when AI is disabled in settings',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [
        userSettingsNotifierProvider.overrideWith(
          () => _FakeSettingsNotifier(UserSettingsState.defaults),
        ),
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions),
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
