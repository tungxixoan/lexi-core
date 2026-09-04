import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/core/widgets/save_exercise_button.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';

class MockSavedExercisesService extends Mock implements SavedExercisesService {}

void main() {
  setUpAll(() {
    registerFallbackValue(SavedExerciseType.bilingual);
    registerFallbackValue(Language.english);
    registerFallbackValue(<String, dynamic>{});
  });

  Widget harness({
    required MockSavedExercisesService service,
    String? reusedFromId,
    SavedExerciseType type = SavedExerciseType.part5,
    Map<String, dynamic> Function()? buildPassageJson,
    Map<String, dynamic>? generationFilters,
    Language targetLanguage = Language.english,
  }) {
    return ProviderScope(
      overrides: [savedExercisesServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        home: Scaffold(
          body: SaveExerciseButton(
            type: type,
            reusedFromId: reusedFromId,
            buildPassageJson:
                buildPassageJson ?? () => <String, dynamic>{'k': 'v'},
            generationFilters: generationFilters ??
                <String, dynamic>{'topicIds': <String>[], 'volumes': <String>[]},
            targetLanguage: targetLanguage,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'fresh: shows "Lưu bài", tap saves once with the passed args and swaps '
      'to "Đã lưu bài này"', (tester) async {
    final service = MockSavedExercisesService();
    when(() => service.save(
          type: any(named: 'type'),
          passageJson: any(named: 'passageJson'),
          generationFilters: any(named: 'generationFilters'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenAnswer((_) async => 'saved-id');

    await tester.pumpWidget(harness(
      service: service,
      type: SavedExerciseType.part6,
      buildPassageJson: () => <String, dynamic>{'passage': 'body'},
      generationFilters: <String, dynamic>{'topicIds': <String>['t1']},
      targetLanguage: Language.chinese,
    ));

    expect(find.text('Lưu bài'), findsOneWidget);

    await tester.tap(find.text('Lưu bài'));
    await tester.pumpAndSettle();

    final captured = verify(() => service.save(
          type: captureAny(named: 'type'),
          passageJson: captureAny(named: 'passageJson'),
          generationFilters: captureAny(named: 'generationFilters'),
          targetLanguage: captureAny(named: 'targetLanguage'),
        )).captured;
    expect(captured, [
      SavedExerciseType.part6,
      <String, dynamic>{'passage': 'body'},
      <String, dynamic>{'topicIds': <String>['t1']},
      Language.chinese,
    ]);

    expect(find.text('Đã lưu bài này'), findsOneWidget);
    expect(find.text('Lưu bài'), findsNothing);
  });

  testWidgets('reusedFromId set: shows "Đã lưu bài này", never saves',
      (tester) async {
    final service = MockSavedExercisesService();

    await tester.pumpWidget(harness(service: service, reusedFromId: 'x'));
    await tester.pumpAndSettle();

    expect(find.text('Đã lưu bài này'), findsOneWidget);
    expect(find.text('Lưu bài'), findsNothing);
    verifyNever(() => service.save(
          type: any(named: 'type'),
          passageJson: any(named: 'passageJson'),
          generationFilters: any(named: 'generationFilters'),
          targetLanguage: any(named: 'targetLanguage'),
        ));
  });

  testWidgets('save returns null: signed-out snackbar, button restored',
      (tester) async {
    final service = MockSavedExercisesService();
    when(() => service.save(
          type: any(named: 'type'),
          passageJson: any(named: 'passageJson'),
          generationFilters: any(named: 'generationFilters'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenAnswer((_) async => null);

    await tester.pumpWidget(harness(service: service));
    await tester.tap(find.text('Lưu bài'));
    await tester.pump();

    expect(find.text('Chưa đăng nhập — không lưu được.'), findsOneWidget);
    expect(find.text('Lưu bài'), findsOneWidget);
    expect(find.text('Đã lưu bài này'), findsNothing);
  });

  testWidgets('save throws: failure snackbar, button restored', (tester) async {
    final service = MockSavedExercisesService();
    when(() => service.save(
          type: any(named: 'type'),
          passageJson: any(named: 'passageJson'),
          generationFilters: any(named: 'generationFilters'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenThrow(Exception('nope'));

    await tester.pumpWidget(harness(service: service));
    await tester.tap(find.text('Lưu bài'));
    await tester.pump();

    expect(find.text('Lưu bài thất bại. Thử lại sau.'), findsOneWidget);
    expect(find.text('Lưu bài'), findsOneWidget);
    expect(find.text('Đã lưu bài này'), findsNothing);
  });

  testWidgets('buildPassageJson is not called on plain render, only on tap',
      (tester) async {
    final service = MockSavedExercisesService();
    when(() => service.save(
          type: any(named: 'type'),
          passageJson: any(named: 'passageJson'),
          generationFilters: any(named: 'generationFilters'),
          targetLanguage: any(named: 'targetLanguage'),
        )).thenAnswer((_) async => 'saved-id');

    var calls = 0;
    await tester.pumpWidget(harness(
      service: service,
      buildPassageJson: () {
        calls++;
        return <String, dynamic>{'k': 'v'};
      },
    ));
    await tester.pumpAndSettle();
    expect(calls, 0);

    await tester.tap(find.text('Lưu bài'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
