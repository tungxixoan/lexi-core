import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/core/widgets/ai_key_missing_card.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';
import 'package:lexi_core/features/reading/domain/entities/reading_passage.dart';
import 'package:lexi_core/features/reading/presentation/providers/reading_practice_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_home_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabRecord _record(int i) {
  final now = DateTime(2026, 1, i + 1);
  return VocabRecord(
    id: 'word-$i',
    headword: 'word$i',
    inputType: InputType.word,
    ipa: '',
    meaning: 'meaning $i',
    examples: const [],
    personalNotes: '',
    topicIds: const ['other'],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.a1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

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
  Future<void> update(VocabRecord record) async {}

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

UserSettingsState _settings({bool aiAvailable = true}) =>
    UserSettingsState.defaults.copyWith(
      providerConfigs: {
        AiProvider.gemini: ProviderConfig(
          apiKeyCiphertext: aiAvailable ? 'ck' : null,
          model: 'gemini-2.5-flash',
        ),
      },
    );

class _FakeSavedExercisesService extends SavedExercisesService {
  _FakeSavedExercisesService({this.random, this.used = const {}})
      : super(firestore: FakeFirebaseFirestore(), currentUid: () => null);
  final ({
    String id,
    Map<String, dynamic> passageJson,
    Map<String, dynamic> generationFilters,
  })? random;
  final Set<String> used;

  @override
  Future<
      ({
        String id,
        Map<String, dynamic> passageJson,
        Map<String, dynamic> generationFilters,
      })?> getRandom({
    required SavedExerciseType type,
    required Language targetLanguage,
    required Map<String, dynamic> filters,
    String? excludeId,
  }) async =>
      random;

  @override
  Future<Set<String>> usedBilingualVocabIds() async => used;
}

/// Records the args passed to [generate] without hitting the AI use case, so a
/// test can assert `_generate` threads `generationFilters` through.
class _RecordingReadingPracticeNotifier extends ReadingPracticeNotifier {
  bool generateCalled = false;
  Map<String, dynamic>? capturedFilters;

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required CEFRLevel level,
    required AppContext context,
    required Language targetLanguage,
    Map<String, dynamic>? generationFilters,
  }) async {
    generateCalled = true;
    capturedFilters = generationFilters;
  }
}

Widget _buildHome({
  required UserSettingsState settings,
  required List<VocabRecord> vocabItems,
  SavedExercisesService? savedService,
  ReadingPracticeNotifier? readingNotifier,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ReadingHomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
      GoRoute(
        path: '/reading/bilingual/session',
        builder: (ctx, state) => const Scaffold(body: Text('session stub')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(settings)),
      vocabRepositoryProvider
          .overrideWithValue(_FakeVocabRepository(vocabItems)),
      if (savedService != null)
        savedExercisesServiceProvider.overrideWithValue(savedService),
      if (readingNotifier != null)
        readingPracticeNotifierProvider.overrideWith(() => readingNotifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the missing-API-key card when no key is set',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(aiAvailable: false),
      vocabItems: List.generate(10, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyMissingCard), findsOneWidget);
    expect(find.textContaining('Chưa có API key cho nhà cung cấp AI'),
        findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows low vocab message when fewer than 5 words',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(3, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 từ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI enabled and >= 5 vocab words',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, topic, level and word-count pickers',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Cấp độ'), findsOneWidget);
    expect(find.text('Số từ dùng để tạo bài'), findsOneWidget);
  });

  testWidgets('shows "Lấy bài có sẵn" alongside "Tạo bài luyện"',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
    expect(find.text('Lấy bài có sẵn'), findsOneWidget);
  });

  testWidgets('reuse navigates to the bilingual session on a match',
      (tester) async {
    final passage = ReadingPassage(
      id: 'p1',
      sentences: const [
        BilingualSentence(target: 'Hi.', vietnamese: 'Chào.', vocabIds: []),
      ],
      vocabIds: const [],
      level: CEFRLevel.a1,
      context: AppContext.general,
      targetLanguage: Language.english,
      generatedAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(5, _record),
      savedService: _FakeSavedExercisesService(
        random: (
          id: 'p1',
          passageJson: passage.toJson(),
          generationFilters: const {'maxCefr': 'a1'},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy bài có sẵn'));
    await tester.pumpAndSettle();
    expect(find.text('session stub'), findsOneWidget);
  });

  testWidgets('reuse shows a snackbar when nothing matches the filters',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(5, _record),
      savedService: _FakeSavedExercisesService(random: null, used: const {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy bài có sẵn'));
    await tester.pump();
    expect(find.text('Chưa có bài đã lưu khớp bộ lọc.'), findsOneWidget);
  });

  testWidgets('"Tạo bài luyện" threads the generation filters into generate()',
      (tester) async {
    final notifier = _RecordingReadingPracticeNotifier();
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
      vocabItems: List.generate(10, _record),
      savedService: _FakeSavedExercisesService(used: const {}),
      readingNotifier: notifier,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo bài luyện'));
    await tester.pumpAndSettle();

    expect(notifier.generateCalled, isTrue);
    expect(notifier.capturedFilters, isNotNull);
    expect(notifier.capturedFilters!.containsKey('topicIds'), isTrue);
    expect(notifier.capturedFilters!.containsKey('maxCefr'), isTrue);
    expect(notifier.capturedFilters!['wordCount'], 10);
  });
}
