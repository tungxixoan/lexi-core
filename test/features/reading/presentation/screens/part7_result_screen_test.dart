import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/domain/entities/economy_volume.dart';
import 'package:lexi_core/features/reading/domain/entities/part7_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/part7_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part7_result_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
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

Part7PassageGroup _group(int i, int questionCount, {int documentCount = 1}) =>
    Part7PassageGroup(
      documents: List.generate(documentCount, (d) => 'Document $i-$d'),
      questions: List.generate(
        questionCount,
        (q) => Part7Question(
          question: 'Q$i-$q?',
          options: const ['a', 'b', 'c', 'd'],
          correctIndex: 0,
          explanation: 'Vì đáp án A đúng ($i-$q).',
        ),
      ),
    );

final _testSet = Part7Set(
  id: 'p1',
  passageGroups: [
    _group(0, 3),
    _group(1, 4),
    _group(2, 5, documentCount: 2),
  ],
  volumes: const {EconomyVolume.vol4},
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

// Every question's correctIndex is 0. Answer group 0 all correct (3/3),
// group 1 all wrong (0/4), group 2 all correct (5/5) -> 8/12.
final _testResult = Part7SessionResult(
  set: _testSet,
  selectedAnswers: const [0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0],
);

Future<Widget> _buildResult({List<Override> extraOverrides = const []}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    routes: [
      GoRoute(
          path: '/',
          builder: (ctx, state) => Part7ResultScreen(result: _testResult)),
      GoRoute(
          path: '/reading/part7',
          builder: (ctx, state) => const Scaffold(body: Text('Part7 home'))),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults.copyWith(
          providerConfigs: {
            AiProvider.gemini: const ProviderConfig(
                apiKeyCiphertext: 'ck', model: 'gemini-2.5-flash'),
          },
        )),
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

  testWidgets(
      'shows the score as correctCount/total (computed dynamically, not a fixed constant)',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('8/12'), findsOneWidget);
  });

  testWidgets(
      'shows all group documents (including both documents of the double-passage group) and explanations',
      (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.textContaining('Document 0-0'), findsOneWidget);
    expect(find.textContaining('Document 1-0'), findsOneWidget);
    expect(find.textContaining('Document 2-0'), findsOneWidget);
    expect(find.textContaining('Document 2-1'), findsOneWidget);
    expect(find.text('Đoạn 3 (2 văn bản liên quan)'), findsOneWidget);
    expect(find.textContaining('Vì đáp án A đúng (0-0).'), findsOneWidget);
  });

  testWidgets('shows Bài khác and Về trang chính buttons', (tester) async {
    await tester.pumpWidget(await _buildResult());
    await tester.pumpAndSettle();
    expect(find.text('Bài khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets(
      'records a practice session with the dynamically-computed total question count',
      (tester) async {
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(await _buildResult(
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    verify(() => mockStats.recordPracticeSession(12)).called(1);
  });

  testWidgets(
      'loads new-word suggestions for the concatenated text of every document across all groups',
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
            .overrideWithValue(mockSuggestions)
      ],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'Document 0-0 Document 1-0 Document 2-0 Document 2-1',
          targetLanguage: Language.english,
          targetCefrLevel: null,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });
}
