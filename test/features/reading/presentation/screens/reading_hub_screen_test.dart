import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/services/saved_exercises_service.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_hub_screen.dart';
import 'package:lexi_core/features/reading/presentation/widgets/part5_options.dart';
import 'package:lexi_core/features/reading/presentation/widgets/part6_options.dart';
import 'package:lexi_core/features/reading/presentation/widgets/part7_options.dart';
import 'package:lexi_core/features/reading/presentation/widgets/reading_bilingual_options.dart';
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

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

class _FakeSavedExercisesService extends SavedExercisesService {
  _FakeSavedExercisesService()
      : super(firestore: FakeFirebaseFirestore(), currentUid: () => null);

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
      null;

  @override
  Future<Set<String>> usedBilingualVocabIds() async => const {};
}

UserSettingsState _settings() => UserSettingsState.defaults.copyWith(
      providerConfigs: {
        AiProvider.gemini: ProviderConfig(
          apiKeyCiphertext: 'ck',
          model: 'gemini-2.5-flash',
        ),
      },
    );

Widget _buildHub() {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const ReadingHubScreen()),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
      for (final t in ['bilingual', 'part5', 'part6', 'part7'])
        GoRoute(
          path: '/reading/$t/session',
          builder: (ctx, state) => Scaffold(body: Text('$t session stub')),
        ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(_settings())),
      vocabRepositoryProvider
          .overrideWithValue(_FakeVocabRepository(List.generate(10, _record))),
      savedExercisesServiceProvider
          .overrideWithValue(_FakeSavedExercisesService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows all 4 cards and no options panel initially',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    expect(find.text('Đọc & gõ'), findsOneWidget);
    expect(find.text('Part 5 — Điền câu'), findsOneWidget);
    expect(find.text('Part 6 — Điền đoạn văn'), findsOneWidget);
    expect(find.text('Part 7 — Đọc hiểu'), findsOneWidget);

    expect(find.byType(ReadingBilingualOptions), findsNothing);
    expect(find.byType(Part5Options), findsNothing);
    expect(find.byType(Part6Options), findsNothing);
    expect(find.byType(Part7Options), findsNothing);
  });

  testWidgets('tapping "Đọc & gõ" expands the bilingual options inline',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đọc & gõ'));
    await tester.pumpAndSettle();

    expect(find.byType(ReadingBilingualOptions), findsOneWidget);
  });

  testWidgets('tapping another card collapses the first and expands the second',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đọc & gõ'));
    await tester.pumpAndSettle();
    expect(find.byType(ReadingBilingualOptions), findsOneWidget);

    // The expanded bilingual panel pushes the Part 5 card below the viewport.
    await tester.ensureVisible(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();

    expect(find.byType(ReadingBilingualOptions), findsNothing);
    expect(find.byType(Part5Options), findsOneWidget);
  });

  testWidgets('tapping an expanded card again collapses it', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();
    expect(find.byType(Part5Options), findsOneWidget);

    await tester.tap(find.text('Part 5 — Điền câu'));
    await tester.pumpAndSettle();
    expect(find.byType(Part5Options), findsNothing);
  });
}
