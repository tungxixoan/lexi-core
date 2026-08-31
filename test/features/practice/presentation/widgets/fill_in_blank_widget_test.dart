import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/widgets/fill_in_blank_widget.dart';
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

final _exercise = FillInBlankExercise(
  vocabRecord: _record,
  sentence: 'Fashions are ___ and quickly forgotten.',
  answer: 'ephemeral',
);

Widget _harness(void Function(ExerciseResult) onResult) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FillInBlankWidget(exercise: _exercise, onResult: onResult),
      ),
    );

void main() {
  testWidgets('renders a BloomTextField and the check button', (tester) async {
    await tester.pumpWidget(_harness((_) {}));
    expect(find.byType(BloomTextField), findsOneWidget);
    expect(find.widgetWithText(BloomPillButton, 'Kiểm tra'), findsOneWidget);
  });

  testWidgets('exact answer reports quality 5', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.enterText(find.byType(TextField), 'ephemeral');
    await tester.tap(find.widgetWithText(BloomPillButton, 'Kiểm tra'));
    await tester.pump(const Duration(milliseconds: 1300));

    expect(captured, isNotNull);
    expect(captured!.quality, 5);
    expect(captured!.isCorrect, isTrue);
  });

  testWidgets('wrong answer reports quality 1 and shows the answer key', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.enterText(find.byType(TextField), 'permanent');
    await tester.tap(find.widgetWithText(BloomPillButton, 'Kiểm tra'));
    await tester.pump(const Duration(milliseconds: 1300));

    expect(captured, isNotNull);
    expect(captured!.quality, 1);
    expect(captured!.isCorrect, isFalse);
    expect(find.text('Đáp án: ${_exercise.answer}'), findsOneWidget);
  });
}
