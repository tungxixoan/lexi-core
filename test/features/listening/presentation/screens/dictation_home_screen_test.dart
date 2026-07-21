import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/domain/entities/input_type.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/listening/domain/entities/dictation_difficulty.dart';
import 'package:lexi_core/features/listening/presentation/providers/dictation_practice_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/dictation_home_screen.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

VocabRecord _record(int i, {DateTime? nextReviewAt}) {
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
    nextReviewAt: nextReviewAt,
  );
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this.records);
  final List<VocabRecord> records;

  @override
  Future<List<VocabRecord>> getAll({
    String? topicId,
    InputType? inputType,
    Language? language,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      records;

  @override
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<VocabRecord?> getById(String id) async => null;

  @override
  Future<void> update(VocabRecord record) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<bool> existsByHeadword(String headword, Language language) async =>
      false;

  @override
  Future<VocabRecord?> getByHeadword(String headword, Language language) async =>
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

/// Fake notifier that records the `words` argument passed to [generate]
/// instead of invoking the real (AI-backed) use case.
class _FakeDictationNotifier extends DictationPracticeNotifier {
  List<VocabRecord>? capturedWords;
  int callCount = 0;

  @override
  AsyncValue<DictationSessionState?> build() => const AsyncData(null);

  @override
  Future<void> generate({
    required List<VocabRecord> words,
    required AppContext context,
    required Language targetLanguage,
    required CEFRLevel level,
    DictationDifficulty difficulty = DictationDifficulty.hard,
  }) async {
    callCount++;
    capturedWords = words;
    // Leave state as AsyncData(null): the screen only navigates away when
    // the resulting session is non-null, so tests can stay on this screen.
  }
}

Widget _buildHome({
  required UserSettingsState settings,
  required List<VocabRecord> vocabItems,
  _FakeDictationNotifier? dictationNotifier,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const DictationHomeScreen(),
      ),
      GoRoute(
        path: '/listening/dictation/session',
        builder: (ctx, state) => const Scaffold(body: Text('Session screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(vocabItems)),
      if (dictationNotifier != null)
        dictationPracticeNotifierProvider.overrideWith(() => dictationNotifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
      vocabItems: List.generate(5, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows low vocab message when fewer than 2 words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(1, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 từ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI enabled and >= 2 vocab words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, topic and level pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(2, _record),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Cấp độ'), findsOneWidget);
  });

  testWidgets('generate() is called with exactly 2 words when more than 2 are eligible', (tester) async {
    final fakeNotifier = _FakeDictationNotifier();
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.generate(5, _record),
      dictationNotifier: fakeNotifier,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo bài luyện'));
    await tester.pumpAndSettle();

    expect(fakeNotifier.callCount, 1);
    expect(fakeNotifier.capturedWords, isNotNull);
    expect(fakeNotifier.capturedWords!.length, 2);
  });

  testWidgets('generate() prioritizes due words over not-due words', (tester) async {
    final now = DateTime.now();
    final dueWords = [
      _record(0, nextReviewAt: null),
      _record(1, nextReviewAt: now.subtract(const Duration(days: 1))),
    ];
    final notDueWords = [
      _record(2, nextReviewAt: now.add(const Duration(days: 30))),
      _record(3, nextReviewAt: now.add(const Duration(days: 30))),
      _record(4, nextReviewAt: now.add(const Duration(days: 30))),
    ];
    final dueIds = dueWords.map((r) => r.id).toSet();

    final fakeNotifier = _FakeDictationNotifier();
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: [...dueWords, ...notDueWords],
      dictationNotifier: fakeNotifier,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo bài luyện'));
    await tester.pumpAndSettle();

    expect(fakeNotifier.capturedWords, isNotNull);
    expect(fakeNotifier.capturedWords!.length, 2);
    expect(
      fakeNotifier.capturedWords!.every((r) => dueIds.contains(r.id)),
      isTrue,
      reason: 'expected both selected words to come from the due set: '
          '${fakeNotifier.capturedWords!.map((r) => r.id)}',
    );
  });
}
