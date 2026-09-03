import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/word_radar/domain/entities/word_radar_ai_result.dart';
import 'package:lexi_core/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart';
import 'package:lexi_core/features/word_radar/presentation/widgets/result_suggestions_section.dart';

class MockGetVocabSuggestionsForTextUseCase extends Mock
    implements GetVocabSuggestionsForTextUseCase {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Future<Widget> _buildSection({
  required bool aiAvailable,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(
          UserSettingsState.defaults.copyWith(
            providerConfigs: {
              AiProvider.gemini: ProviderConfig(
                apiKeyCiphertext: aiAvailable ? 'ck' : null,
                model: 'gemini-2.5-flash',
              ),
            },
          ),
        ),
      ),
      ...extraOverrides,
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: ResultSuggestionsSection(
          text: 'some passage text',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Language.english);
    registerFallbackValue(CEFRLevel.b1);
  });

  testWidgets('does not call the suggestions use case when AI is disabled',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    await tester.pumpWidget(await _buildSection(
      aiAvailable: false,
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions)
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

  testWidgets(
      'loads suggestions with the given text/language/level and renders them',
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

    await tester.pumpWidget(await _buildSection(
      aiAvailable: true,
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions)
      ],
    ));
    await tester.pumpAndSettle();

    verify(() => mockSuggestions.execute(
          text: 'some passage text',
          targetLanguage: Language.english,
          targetCefrLevel: CEFRLevel.b1,
        )).called(1);
    expect(find.text('Gợi ý từ mới'), findsOneWidget);
    expect(find.text('ubiquitous'), findsOneWidget);
  });

  testWidgets('shows an error message with a retry button on failure',
      (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenThrow(Exception('network error'));

    await tester.pumpWidget(await _buildSection(
      aiAvailable: true,
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions)
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không tải được gợi ý từ mới'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('tapping Thử lại retries the use case call', (tester) async {
    final mockSuggestions = MockGetVocabSuggestionsForTextUseCase();
    var callCount = 0;
    when(() => mockSuggestions.execute(
          text: any(named: 'text'),
          targetLanguage: any(named: 'targetLanguage'),
          targetCefrLevel: any(named: 'targetCefrLevel'),
        )).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) throw Exception('network error');
      return const WordRadarAiResult(translation: '', suggestions: []);
    });

    await tester.pumpWidget(await _buildSection(
      aiAvailable: true,
      extraOverrides: [
        getVocabSuggestionsForTextUseCaseProvider
            .overrideWithValue(mockSuggestions)
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(callCount, 2);
    expect(find.text('Không có gợi ý mới.'), findsOneWidget);
  });
}
