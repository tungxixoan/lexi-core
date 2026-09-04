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
import 'package:lexi_core/features/listening/presentation/screens/listening_home_screen.dart';
import 'package:lexi_core/features/listening/presentation/widgets/comprehension_options.dart';
import 'package:lexi_core/features/listening/presentation/widgets/dictation_options.dart';
import 'package:lexi_core/features/practice/domain/entities/saved_exercise.dart';
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
    topicIds: const [],
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
      GoRoute(path: '/', builder: (ctx, state) => const ListeningHomeScreen()),
      GoRoute(
        path: '/practice',
        builder: (ctx, state) => const Scaffold(body: Text('Practice hub')),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
      for (final t in ['dictation', 'comprehension'])
        GoRoute(
          path: '/listening/$t/session',
          builder: (ctx, state) => Scaffold(body: Text('$t session stub')),
        ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(_settings())),
      vocabRepositoryProvider
          .overrideWithValue(_FakeVocabRepository(List.generate(5, _record))),
      savedExercisesServiceProvider
          .overrideWithValue(_FakeSavedExercisesService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows both cards and no options panel initially',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    expect(find.text('Nghe chép'), findsOneWidget);
    expect(find.text('Nghe hiểu'), findsOneWidget);

    expect(find.byType(DictationOptions), findsNothing);
    expect(find.byType(ComprehensionOptions), findsNothing);
  });

  testWidgets('tapping "Nghe chép" expands the dictation options inline',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();

    expect(find.byType(DictationOptions), findsOneWidget);
  });

  testWidgets('tapping the other card collapses the first and expands it',
      (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nghe chép'));
    await tester.pumpAndSettle();
    expect(find.byType(DictationOptions), findsOneWidget);

    // The expanded dictation panel can push the "Nghe hiểu" card offscreen.
    await tester.ensureVisible(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();

    expect(find.byType(DictationOptions), findsNothing);
    expect(find.byType(ComprehensionOptions), findsOneWidget);
  });

  testWidgets('tapping an expanded card again collapses it', (tester) async {
    await tester.pumpWidget(_buildHub());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();
    expect(find.byType(ComprehensionOptions), findsOneWidget);

    await tester.tap(find.text('Nghe hiểu'));
    await tester.pumpAndSettle();
    expect(find.byType(ComprehensionOptions), findsNothing);
  });
}
