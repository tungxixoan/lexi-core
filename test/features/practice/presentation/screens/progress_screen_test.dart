import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/learning_stats.dart';
import 'package:lexi_core/features/practice/presentation/screens/progress_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;
}

class _FakeGetVocabListUseCase implements GetVocabListUseCase {
  _FakeGetVocabListUseCase(this.words);
  final List<VocabRecord> words;

  @override
  Future<List<VocabRecord>> execute({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      words;
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

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

final _today = DateTime.now();

// masteredCount is 6 (not 5) so its stat-card value can't collide with the
// b2 CEFR count (5), keeping the per-value `find.text` assertions exact.
final _stats = LearningStats(
  dueCount: 12,
  masteredCount: 6,
  totalCount: 40,
  cefrBreakdown: const {
    CEFRLevel.a1: 10,
    CEFRLevel.a2: 8,
    CEFRLevel.b1: 15,
    CEFRLevel.b2: 5,
    CEFRLevel.c1: 2,
    CEFRLevel.c2: 0,
  },
  currentStreak: 3,
  weeklyLog: {
    _dateKey(_today): 4,
    _dateKey(_today.subtract(const Duration(days: 1))): 2,
    _dateKey(_today.subtract(const Duration(days: 3))): 7,
  },
);

const _statsNothingDue = LearningStats(
  dueCount: 0,
  masteredCount: 0,
  totalCount: 0,
  cefrBreakdown: {},
  currentStreak: 0,
  weeklyLog: {},
);

Widget _buildProgress(
  LearningStats? stats, {
  bool loading = false,
  List<VocabRecord> dueWords = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const ProgressScreen()),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice stub')),
      ),
      GoRoute(
        path: '/practice/session',
        builder: (ctx, state) => const Scaffold(body: Text('Session stub')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      getVocabListUseCaseProvider
          .overrideWithValue(_FakeGetVocabListUseCase(dueWords)),
      learningStatsProvider.overrideWith(
        (ref) =>
            loading ? Completer<LearningStats>().future : Future.value(stats!),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
      'renders the streak, both stat cards, and the CEFR + chart sections',
      (tester) async {
    await tester.pumpWidget(_buildProgress(_stats));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsWidgets); // streak count
    expect(find.text('12'), findsOneWidget); // due
    expect(find.text('6'), findsOneWidget); // mastered
    expect(find.byType(BloomStatCard), findsNWidgets(2));
    expect(find.byType(BloomBarChart), findsOneWidget);
    expect(
        find.byType(BloomProgressBar), findsNWidgets(6)); // one per CEFR level
  });

  testWidgets('the "ôn ngay" CTA pushes a session with the due words',
      (tester) async {
    await tester.pumpWidget(
      _buildProgress(_stats, dueWords: [_record('a'), _record('b')]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BloomPillButton));
    await tester.pumpAndSettle();

    expect(find.text('Session stub'), findsOneWidget);
  });

  testWidgets('zero-streak shows the ❄️ prompt, no CTA when nothing is due',
      (tester) async {
    await tester.pumpWidget(_buildProgress(_statsNothingDue));
    await tester.pumpAndSettle();

    expect(find.text('❄️'), findsOneWidget);
    expect(find.byType(BloomPillButton), findsNothing);
  });

  testWidgets('renders as a root tab — no back button in the app bar',
      (tester) async {
    await tester.pumpWidget(_buildProgress(_stats));
    await tester.pumpAndSettle();

    expect(find.byType(BloomIconButton), findsNothing);
  });

  testWidgets('loading state shows a spinner', (tester) async {
    await tester.pumpWidget(_buildProgress(null, loading: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
