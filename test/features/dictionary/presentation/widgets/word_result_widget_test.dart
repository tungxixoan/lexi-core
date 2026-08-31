import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/lookup_result.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/word_result_widget.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:lexi_core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;
}

class _FakeVocabBankNotifier extends VocabBankNotifier {
  @override
  Future<List<VocabRecord>> build() async => const [];
}

class _FakeTtsService implements TtsService {
  @override
  Future<void> pronounce(String text, Language language,
      {required PronunciationTier tier}) async {}

  @override
  Future<void> synthesize(String text, Language language,
      {String? voice, double? rate}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Future<Widget> _build(WordPhraseResult result) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      vocabBankNotifierProvider.overrideWith(_FakeVocabBankNotifier.new),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 360,
            child: WordResultWidget(result: result),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const result = WordPhraseResult(
    headword: 'ubiquitous',
    inputType: InputType.word,
    ipa: '/juːˈbɪkwɪtəs/',
    meaning: 'có mặt khắp nơi',
    examples: [],
    suggestedTopics: [],
  );

  testWidgets('headword renders on a single line at 360px width',
      (tester) async {
    await tester.pumpWidget(await _build(result));
    await tester.pumpAndSettle();

    expect(find.text('ubiquitous'), findsOneWidget);
    // Pre-fix (Flexible + Spacer stealing half the row) this headword wrapped
    // to multiple lines (~62px); the Expanded fix keeps it to one line (~31px).
    expect(tester.getSize(find.text('ubiquitous')).height, lessThan(40));
    expect(tester.takeException(), isNull);
  });
}
