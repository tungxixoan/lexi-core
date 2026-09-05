import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/learning_stats.dart';
import 'package:lexi_core/features/practice/presentation/screens/practice_home_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/use_cases/get_vocab_list_use_case.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/topics_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;
}

class _FakeTopicsNotifier extends TopicsNotifier {
  @override
  Future<List<Topic>> build() async => const [];
}

class _FakeGetVocabListUseCase implements GetVocabListUseCase {
  @override
  Future<List<VocabRecord>> execute({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      const [];
}

class _FakeStatsService implements StatsService {
  @override
  Future<LearningStats> computeStats(Language language) async =>
      const LearningStats(
        dueCount: 0,
        masteredCount: 0,
        totalCount: 0,
        cefrBreakdown: {},
        currentStreak: 0,
        weeklyLog: {},
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Widget> _buildScreen() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/practice/vocab',
    routes: [
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/practice/vocab',
        builder: (ctx, state) => const PracticeHomeScreen(),
      ),
      GoRoute(
        path: '/practice/session',
        builder: (ctx, state) => const Scaffold(body: Text('Session screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      topicsNotifierProvider.overrideWith(_FakeTopicsNotifier.new),
      getVocabListUseCaseProvider.overrideWithValue(_FakeGetVocabListUseCase()),
      statsServiceProvider.overrideWithValue(_FakeStatsService()),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the 3 FilterTiles and the start button', (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    expect(find.byType(FilterTile), findsNWidgets(3));
    expect(
      find.widgetWithText(BloomPillButton, 'Bắt đầu luyện tập'),
      findsOneWidget,
    );
  });

  testWidgets('when dueCount is 0 the "Ôn hôm nay" button is disabled',
      (tester) async {
    await tester.pumpWidget(await _buildScreen());
    await tester.pumpAndSettle();

    final button = tester.widget<BloomPillButton>(
      find.widgetWithText(BloomPillButton, 'Hôm nay đã ôn xong ✓'),
    );
    expect(button.onPressed, isNull);
  });
}
