import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/exercise_result.dart';
import 'package:lexi_core/features/practice/domain/use_cases/compute_sm2_use_case.dart';
import 'package:lexi_core/features/practice/presentation/providers/notification_notifier.dart';
import 'package:lexi_core/features/practice/presentation/screens/session_result_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/update_vocab_use_case.dart';

class _MockStatsService extends Mock implements StatsService {}

/// Fake compute use case: records how many times [compute] ran and returns
/// the record unchanged (so the frozen `_updateSm2` loop is exercised
/// without touching real SM-2 math or storage).
class _FakeComputeSm2UseCase implements ComputeSm2UseCase {
  int computeCalls = 0;

  @override
  VocabRecord compute(VocabRecord record, int quality) {
    computeCalls++;
    return record;
  }
}

/// Fake update use case: records the records it was asked to persist, no-op.
class _FakeUpdateVocabUseCase implements UpdateVocabUseCase {
  final List<VocabRecord> executed = [];

  @override
  Future<void> execute(VocabRecord record) async {
    executed.add(record);
  }
}

/// Fake notification notifier: skips the real `build()` (plugin init +
/// listeners) and the real `reschedule()` (Firestore + local-notifications).
class _FakeNotificationNotifier extends NotificationNotifier {
  int rescheduleCalls = 0;

  @override
  void build() {}

  @override
  Future<void> reschedule() async {
    rescheduleCalls++;
  }
}

VocabRecord _record(String id) => VocabRecord(
      id: id,
      headword: 'headword-$id',
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $id',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: Language.english,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late _FakeComputeSm2UseCase fakeCompute;
  late _FakeUpdateVocabUseCase fakeUpdate;
  late _FakeNotificationNotifier fakeNotifier;
  late _MockStatsService mockStats;

  final word1 = _record('id1');
  final word2 = _record('id2');
  final result = SessionResult(
    results: const [
      ExerciseResult(vocabRecordId: 'id1', quality: 5, isCorrect: true),
      ExerciseResult(vocabRecordId: 'id2', quality: 1, isCorrect: false),
    ],
    words: [word1, word2],
  );

  Future<Widget> buildScreen() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fakeCompute = _FakeComputeSm2UseCase();
    fakeUpdate = _FakeUpdateVocabUseCase();
    fakeNotifier = _FakeNotificationNotifier();
    mockStats = _MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, state) => SessionResultScreen(result: result),
        ),
        GoRoute(
          path: '/practice/vocab',
          builder: (ctx, state) => const Scaffold(body: Text('Vocab practice')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        computeSm2UseCaseProvider.overrideWithValue(fakeCompute),
        updateVocabUseCaseProvider.overrideWithValue(fakeUpdate),
        statsServiceProvider.overrideWithValue(mockStats),
        notificationNotifierProvider.overrideWith(() => fakeNotifier),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    );
  }

  testWidgets('renders the Bloom result ring with the score percentage',
      (tester) async {
    await tester.pumpWidget(await buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(BloomResultRing), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('1 / 2 từ đúng'), findsOneWidget);
    // The result screen is a nested GoRoute; guard that no dead-end back
    // arrow appears (automaticallyImplyLeading: false).
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('renders a Bloom card row per result with both headwords',
      (tester) async {
    await tester.pumpWidget(await buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(BloomCard), findsNWidgets(2));
    expect(find.text('headword-id1'), findsOneWidget);
    expect(find.text('headword-id2'), findsOneWidget);
  });

  testWidgets('the Luyện tập lại button is a BloomPillButton that navigates',
      (tester) async {
    await tester.pumpWidget(await buildScreen());
    await tester.pumpAndSettle();

    final button = find.widgetWithText(BloomPillButton, 'Luyện tập lại');
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.text('Vocab practice'), findsOneWidget);
  });

  testWidgets('_updateSm2 runs: compute called once per result, notifier rescheduled',
      (tester) async {
    await tester.pumpWidget(await buildScreen());
    await tester.pumpAndSettle();

    expect(fakeCompute.computeCalls, 2);
    expect(fakeUpdate.executed.length, 2);
    verify(() => mockStats.recordPracticeSession(2)).called(1);
    expect(fakeNotifier.rescheduleCalls, 1);
  });
}
