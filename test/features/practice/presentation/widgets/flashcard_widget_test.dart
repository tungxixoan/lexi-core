import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/presentation/widgets/flashcard_widget.dart';
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

final _longMeaning =
    'Một tính từ dùng để mô tả những sự vật, hiện tượng chỉ tồn tại hoặc kédài '
    'kéo dài trong một khoảng thời gian rất ngắn ngủi, thoáng qua rồi biến mất, chẳng hạn '
    'như những xu hướng thời trang theo mùa, những đám mây trên bầu trời buổi '
    'sớm, hay cảm xúc bồng bột nhất thời của tuổi trẻ; từ này thường mang sắc '
    'thái tiếc nuối về sự phù du của vạn vật trong cuộc sống.';

VocabRecord _recordWithMeaning(String meaning) => VocabRecord(
      id: 'id1',
      headword: 'ephemeral',
      inputType: InputType.word,
      ipa: '/ɪˈfem(ə)rəl/',
      meaning: meaning,
      examples: const ['Fashions are ephemeral.'],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Widget _buildCard(void Function(ExerciseResult) onResult) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FlashcardWidget(
          exercise: FlashcardExercise(vocabRecord: _record),
          onResult: onResult,
        ),
      ),
    );

Widget _buildScrollableCard(VocabRecord record) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: SingleChildScrollView(
            child: FlashcardWidget(
              exercise: FlashcardExercise(vocabRecord: record),
              onResult: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('starts showing the front (headword), not the meaning',
      (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('tồn tại trong thời gian ngắn'), findsNothing);
  });

  testWidgets('tapping the front flips to the back (meaning)', (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();
    expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);
    expect(find.text('ephemeral'), findsNothing);
  });

  testWidgets('tapping the meaning area on the back flips back to the front',
      (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pumpAndSettle();

    expect(find.text('ephemeral'), findsOneWidget);
    expect(find.text('tồn tại trong thời gian ngắn'), findsNothing);
  });

  testWidgets('can flip back and forth multiple times before grading',
      (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('ephemeral'));
      await tester.pumpAndSettle();
      expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);

      await tester.tap(find.text('tồn tại trong thời gian ngắn'));
      await tester.pumpAndSettle();
      expect(find.text('ephemeral'), findsOneWidget);
    }
  });

  testWidgets('tapping mid-animation is ignored until the current flip settles',
      (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester
        .pump(const Duration(milliseconds: 50)); // still animating forward
    await tester.tap(
        find.text('ephemeral')); // guarded no-op, must not reverse mid-flight
    await tester.pumpAndSettle();
    expect(find.text('tồn tại trong thời gian ngắn'), findsOneWidget);
  });

  testWidgets('Đã hiểu button reports understood=true', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isTrue);
    expect(result!.quality, 5);
  });

  testWidgets('Chưa hiểu button reports understood=false', (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chưa hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isFalse);
    expect(result!.quality, 1);
  });

  testWidgets('a very long meaning does not overflow the card', (tester) async {
    expect(_longMeaning.length, greaterThan(300));
    await tester
        .pumpWidget(_buildScrollableCard(_recordWithMeaning(_longMeaning)));

    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_longMeaning), findsOneWidget);
  });

  testWidgets('face content is hidden mid-flip and fully revealed once settled',
      (tester) async {
    await tester.pumpWidget(_buildCard((_) {}));
    await tester.tap(find.text('ephemeral'));
    await tester.pump(); // start the flip ticker
    // Exactly the midpoint of the 450ms flip: the card is edge-on, so its
    // content must not be readable yet.
    await tester.pump(const Duration(milliseconds: 225));

    final midOpacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('ephemeral'), matching: find.byType(Opacity))
          .first,
    );
    expect(midOpacity.opacity, lessThan(0.05));

    await tester.pumpAndSettle();
    final settled = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('tồn tại trong thời gian ngắn'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(settled.opacity, moreOrLessEquals(1.0));
  });

  testWidgets(
      'a grade tap while the card is mid-flip is ignored (no silent grade)',
      (tester) async {
    ExerciseResult? captured;
    await tester.pumpWidget(_buildCard((r) => captured = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle(); // settled on the back face

    // Start a flip-back by tapping the meaning/hint area, then DO NOT settle —
    // the grade buttons are now in the opacity-ramped, still-hit-testable
    // subtree.
    await tester.tap(find.text('Chạm để xem lại từ vựng'));
    await tester.pump(const Duration(milliseconds: 100)); // mid-flip
    await tester.tap(find.text('Đã hiểu'), warnIfMissed: false);
    await tester.pump();
    expect(captured, isNull, reason: 'grade must not fire during the flip');

    // The flip-back completes; a real grade tap after re-revealing still works.
    await tester.pumpAndSettle();
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    expect(captured, isNotNull);
    expect(captured!.isCorrect, isTrue);
  });

  testWidgets('grading buttons still work after flipping back and forth',
      (tester) async {
    ExerciseResult? result;
    await tester.pumpWidget(_buildCard((r) => result = r));
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tồn tại trong thời gian ngắn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ephemeral'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isCorrect, isTrue);
  });
}
