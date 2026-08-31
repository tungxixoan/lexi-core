import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/widgets/translation_exercise_widget.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';

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

final _exercise = TranslationExercise(
  vocabRecord: _record,
  prompt: "Translate to Vietnamese: 'The ephemeral beauty of cherry blossoms.'",
  answer: 'Vẻ đẹp phù du của hoa anh đào.',
);

Widget _harness(void Function(ExerciseResult) onResult) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: TranslationExerciseWidget(exercise: _exercise, onResult: onResult),
      ),
    );

BloomPillButton _pill(WidgetTester tester, String label) =>
    tester.widget<BloomPillButton>(find.widgetWithText(BloomPillButton, label));

void main() {
  testWidgets('"Xem đáp án" is disabled while the field is empty', (tester) async {
    await tester.pumpWidget(_harness((_) {}));
    expect(_pill(tester, 'Xem đáp án').onPressed, isNull);
  });

  testWidgets('revealing the answer then grading correct reports quality 5', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.enterText(find.byType(TextField), 'Vẻ đẹp phù du của hoa anh đào');
    await tester.pumpWidget(_harness((r) => captured = r)); // force a rebuild

    expect(_pill(tester, 'Xem đáp án').onPressed, isNotNull);
    await tester.tap(find.widgetWithText(BloomPillButton, 'Xem đáp án'));
    await tester.pump();

    expect(find.text('Đáp án: ${_exercise.answer}'), findsOneWidget);
    // Revealed-answer text keeps a theme text base (real fontSize) + success color.
    final answerText =
        tester.widget<Text>(find.text('Đáp án: ${_exercise.answer}'));
    expect(answerText.style?.fontSize, isNotNull);
    expect(answerText.style?.color, isNotNull);

    await tester.tap(find.widgetWithText(BloomPillButton, 'Đúng rồi'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.quality, 5);
    expect(captured!.isCorrect, isTrue);
  });

  testWidgets('grading wrong reports quality 1', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.enterText(find.byType(TextField), 'sai bét');
    await tester.pumpWidget(_harness((r) => captured = r)); // force a rebuild

    await tester.tap(find.widgetWithText(BloomPillButton, 'Xem đáp án'));
    await tester.pump();

    await tester.tap(find.widgetWithText(BloomPillButton, 'Sai rồi'));
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.quality, 1);
    expect(captured!.isCorrect, isFalse);
  });
}
