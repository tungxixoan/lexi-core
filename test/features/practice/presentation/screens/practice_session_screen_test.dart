import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/providers/practice_session_provider.dart';
import 'package:lexi_core/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:lexi_core/features/practice/presentation/widgets/flashcard_widget.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _record = VocabRecord(
  id: 'id1',
  headword: 'ephemeral',
  inputType: InputType.word,
  ipa: '/ɪˈfem(ə)rəl/',
  meaning: 'tồn tại trong thời gian ngắn',
  examples: const ['Fashions are ephemeral.'],
  personalNotes: '',
  topicIds: const [],
  targetLanguage: Language.english,
  cefrLevel: CEFRLevel.b1,
  activeContext: AppContext.general,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _fakeState = PracticeSessionState(
  words: [_record],
  exercises: [FlashcardExercise(vocabRecord: _record)],
  currentIndex: 0,
  results: const [],
  isComplete: false,
);

/// Fake that skips the real `startSession` (which would hit AI/settings
/// providers) and just holds a fixed state.
class _FakePracticeSessionNotifier extends PracticeSessionNotifier {
  @override
  AsyncValue<PracticeSessionState> build() => AsyncData(_fakeState);

  @override
  Future<void> startSession(SessionConfig config) async {}
}

Future<Widget> _buildScreen() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      practiceSessionNotifierProvider
          .overrideWith(_FakePracticeSessionNotifier.new),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: PracticeSessionScreen(config: SessionConfig(words: [_record])),
    ),
  );
}

void main() {
  testWidgets('renders the Bloom progress bar, the N / total title and the exercise',
      (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(BloomProgressBar), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(FlashcardWidget), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });
}
