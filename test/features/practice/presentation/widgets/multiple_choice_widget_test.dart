import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/widgets/multiple_choice_widget.dart';
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

final _exercise = MultipleChoiceExercise(
  vocabRecord: _record,
  question: 'Nghĩa của "ephemeral"?',
  options: const ['bền vững', 'to lớn', 'tồn tại trong thời gian ngắn', 'màu xanh'],
  correctIndex: 2,
);

Widget _harness(void Function(ExerciseResult) onResult) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: MultipleChoiceWidget(exercise: _exercise, onResult: onResult),
      ),
    );

void main() {
  testWidgets('renders four BloomMcOptions', (tester) async {
    await tester.pumpWidget(_harness((_) {}));
    expect(find.byType(BloomMcOption), findsNWidgets(4));
  });

  testWidgets('tapping the correct option reports quality 5 / isCorrect', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(captured, isNotNull);
    expect(captured!.quality, 5);
    expect(captured!.isCorrect, isTrue);
  });

  testWidgets('after a tap every option is no longer tappable', (tester) async {
    await tester.pumpWidget(_harness((_) {}));

    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pump(const Duration(milliseconds: 900));

    for (final option in tester.widgetList<BloomMcOption>(find.byType(BloomMcOption))) {
      expect(option.onTap, isNull);
    }
  });

  testWidgets('tapping a wrong option reports quality 1', (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_harness((r) => captured = r));

    await tester.tap(find.text('bền vững'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(captured, isNotNull);
    expect(captured!.quality, 1);
    expect(captured!.isCorrect, isFalse);
  });
}
