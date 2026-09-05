import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/core/services/stats_service.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/widgets/save_exercise_button.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_item.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_result_screen.dart';
import 'package:lexi_core/features/listening/domain/entities/blank_span.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';

class MockStatsService extends Mock implements StatsService {}

class MockSavedExercisesService extends Mock implements SavedExercisesService {}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

VocabRecord _record(String id, {Language language = Language.english}) =>
    VocabRecord(
      id: id,
      headword: id,
      inputType: InputType.word,
      ipa: '',
      meaning: 'meaning of $id',
      examples: const [],
      personalNotes: '',
      topicIds: const [],
      targetLanguage: language,
      cefrLevel: CEFRLevel.b1,
      activeContext: AppContext.general,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _CapturingVocabRepository implements VocabRepository {
  _CapturingVocabRepository(this.records);
  final List<VocabRecord> records;
  final List<VocabRecord> updated = [];

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async =>
      null;

  @override
  Future<void> update(VocabRecord record) async {
    updated.add(record);
  }

  @override
  Future<void> delete(String id, {required Language language}) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(
          String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

/// Like [_CapturingVocabRepository] but returns a different record list per
/// [Language] — mirrors the real per-language-collection split, so a test
/// can assert that a lookup for one language never sees another language's
/// records (the exact shape of the bug in Finding #1).
class _LanguageScopedVocabRepository implements VocabRepository {
  _LanguageScopedVocabRepository(this.recordsByLanguage);
  final Map<Language, List<VocabRecord>> recordsByLanguage;
  final List<VocabRecord> updated = [];

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      recordsByLanguage[language] ?? const [];

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async =>
      null;

  @override
  Future<void> update(VocabRecord record) async {
    updated.add(record);
  }

  @override
  Future<void> delete(String id, {required Language language}) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(
          String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

class _ThrowingVocabRepository implements VocabRepository {
  final List<VocabRecord> updated = [];

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      throw Exception('storage error fetching vocab bank');

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async =>
      null;

  @override
  Future<void> update(VocabRecord record) async {
    updated.add(record);
  }

  @override
  Future<void> delete(String id, {required Language language}) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(
          String headword, Language language) async =>
      null;

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

final _testItem = DictationItem(
  id: 'item-1',
  target: 'Hello world.',
  vietnamese: 'Xin chào thế giới.',
  vocabIds: const ['id1', 'id2'],
  level: CEFRLevel.b1,
  context: AppContext.general,
  targetLanguage: Language.english,
  generatedAt: DateTime(2026),
);

final _perfectResult = DictationSessionResult(
  item: _testItem,
  typed: 'Hello world.',
  replayCount: 0,
  duration: const Duration(seconds: 5),
);

Widget _buildResult(
  DictationSessionResult result,
  VocabRepository repo, {
  List<Override> extraOverrides = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => DictationResultScreen(result: result),
      ),
      GoRoute(
        path: '/listening/dictation',
        builder: (ctx, state) => const Scaffold(body: Text('Dictation home')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      vocabRepositoryProvider.overrideWithValue(repo),
      savedExercisesServiceProvider
          .overrideWithValue(MockSavedExercisesService()),
      userSettingsNotifierProvider.overrideWith(
        () => _FakeSettingsNotifier(UserSettingsState.defaults),
      ),
      ...extraOverrides,
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('shows the final score percentage', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('100'), findsWidgets); // 100% score
    expect(find.byType(BloomStatCard), findsNWidgets(4));
  });

  testWidgets('shows the target sentence and Vietnamese translation',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello world.'), findsWidgets);
    expect(find.text('Xin chào thế giới.'), findsOneWidget);
  });

  testWidgets('shows Câu khác and Về trang chính buttons', (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.text('Câu khác'), findsOneWidget);
    expect(find.text('Về trang chính'), findsOneWidget);
  });

  testWidgets('shows "Lưu bài" for a fresh item; "Đã lưu bài này" when reused',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.byType(SaveExerciseButton), findsOneWidget);
    expect(find.text('Lưu bài'), findsOneWidget);

    final reused = DictationSessionResult(
      item: _testItem,
      typed: 'Hello world.',
      replayCount: 0,
      duration: const Duration(seconds: 5),
      reusedFromId: 'saved-d',
    );
    await tester.pumpWidget(_buildResult(reused, repo));
    await tester.pumpAndSettle();
    expect(find.text('Lưu bài'), findsNothing);
    expect(find.text('Đã lưu bài này'), findsOneWidget);
  });

  testWidgets('updates SM-2 for every vocab word used in the sentence',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();

    expect(repo.updated.length, 2);
    expect(repo.updated.map((r) => r.id), containsAll(['id1', 'id2']));
    // finalScore is 1.0 -> quality 5 -> quality >= 3 branch -> repetitions 0 -> 1
    for (final r in repo.updated) {
      expect(r.sm2Repetitions, 1);
      expect(r.nextReviewAt, isNotNull);
    }
  });

  testWidgets(
      'records a practice session (for the streak) with the item vocab count',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    final mockStats = MockStatsService();
    when(() => mockStats.recordPracticeSession(any())).thenAnswer((_) async {});

    await tester.pumpWidget(_buildResult(
      _perfectResult,
      repo,
      extraOverrides: [statsServiceProvider.overrideWithValue(mockStats)],
    ));
    await tester.pumpAndSettle();

    // _testItem.vocabIds == ['id1', 'id2']
    verify(() => mockStats.recordPracticeSession(2)).called(1);
  });

  testWidgets(
      "updates SM-2 using the SESSION's own language even when it differs "
      'from the global settings target language', (tester) async {
    // Global settings target language is English (the default), but this
    // session was generated in Chinese via dictation_home_screen's own
    // in-screen language picker — the bug this test guards against had
    // _updateSm2 resolve vocabIds against the globally-scoped
    // vocabBankNotifierProvider (which follows the GLOBAL English setting),
    // so every lookup for these Chinese-language words threw StateError and
    // SM-2 updates silently never happened.
    final chineseItem = DictationItem(
      id: 'item-2',
      target: '你好世界。',
      vietnamese: 'Xin chào thế giới.',
      vocabIds: const ['zh1', 'zh2'],
      level: CEFRLevel.b1,
      context: AppContext.general,
      targetLanguage: Language.chinese,
      generatedAt: DateTime(2026),
    );
    final chineseResult = DictationSessionResult(
      item: chineseItem,
      typed: '你好世界。',
      replayCount: 0,
      duration: const Duration(seconds: 5),
    );
    final repo = _LanguageScopedVocabRepository({
      Language.english: [_record('id1'), _record('id2')],
      Language.chinese: [
        _record('zh1', language: Language.chinese),
        _record('zh2', language: Language.chinese),
      ],
    });

    await tester.pumpWidget(_buildResult(
      chineseResult,
      repo,
      extraOverrides: [
        userSettingsNotifierProvider.overrideWith(
          () => _FakeSettingsNotifier(
            UserSettingsState.defaults
                .copyWith(targetLanguage: Language.english),
          ),
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(repo.updated.length, 2);
    expect(repo.updated.map((r) => r.id), containsAll(['zh1', 'zh2']));
    for (final r in repo.updated) {
      expect(r.sm2Repetitions, 1);
      expect(r.nextReviewAt, isNotNull);
    }
  });

  testWidgets(
      'does not crash and performs zero updates when the vocab bank fetch throws',
      (tester) async {
    final repo = _ThrowingVocabRepository();
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();

    // Screen still renders normally despite the fetch failure.
    expect(find.text('Câu khác'), findsOneWidget);
    expect(repo.updated, isEmpty);
  });

  testWidgets('shows the Số lần tua stat with count and penalty percentage',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    final result = DictationSessionResult(
      item: _testItem,
      typed: 'Hello world.',
      replayCount: 0,
      duration: const Duration(seconds: 5),
      seekCount: 2,
      seekPenaltyTotal: 0.03,
    );
    await tester.pumpWidget(_buildResult(result, repo));
    await tester.pumpAndSettle();
    // BloomStatCard renders its label uppercased.
    expect(find.textContaining('SỐ LẦN TUA'), findsOneWidget);
    expect(find.textContaining('2 (−3%)'), findsOneWidget);
  });

  testWidgets('shows the Số lần tua stat as 0 (−0%) when no seeks happened',
      (tester) async {
    final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
    await tester.pumpWidget(_buildResult(_perfectResult, repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('SỐ LẦN TUA'), findsOneWidget);
    expect(find.textContaining('0 (−0%)'), findsOneWidget);
  });

  group('cloze mode (Dễ/Trung bình)', () {
    // _testItem.target == 'Hello world.' — blank both words, one each.
    const clozeBlanks = [
      BlankSpan(startWordIndex: 0, wordCount: 1),
      BlankSpan(startWordIndex: 1, wordCount: 1),
    ];

    final clozeResult = DictationSessionResult(
      item: _testItem,
      typed: '',
      replayCount: 0,
      duration: const Duration(seconds: 3),
      difficulty: DictationDifficulty.easy,
      blanks: clozeBlanks,
      blankAnswers: const ['Hello', 'wrong'],
    );

    testWidgets(
        'shows the correct blank answer and reveals the right word for the wrong one',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello'), findsWidgets);
      expect(find.textContaining('wrong'), findsOneWidget);
      expect(find.textContaining('đúng: world.'), findsOneWidget);
    });

    testWidgets(
        'shows the score based on blockAccuracy (1 of 2 blanks correct = 50%)',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();
      expect(find.textContaining('50'), findsWidgets);
    });

    testWidgets(
        'still shows the full correct sentence and Vietnamese translation',
        (tester) async {
      final repo = _CapturingVocabRepository([_record('id1'), _record('id2')]);
      await tester.pumpWidget(_buildResult(clozeResult, repo));
      await tester.pumpAndSettle();
      expect(find.text('Hello world.'), findsOneWidget); // "Câu đúng" section
      expect(find.text('Xin chào thế giới.'), findsOneWidget);
    });
  });
}
