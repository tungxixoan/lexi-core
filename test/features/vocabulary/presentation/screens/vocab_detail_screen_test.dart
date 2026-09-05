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
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/topic.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/domain/repositories/vocab_repository.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/topics_provider.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:lexi_core/features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import 'package:lexi_core/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  @override
  UserSettingsState build() => UserSettingsState.defaults;
}

class _FakeTopicsNotifier extends TopicsNotifier {
  @override
  Future<List<Topic>> build() async => const [];
}

class _FakeVocabBankNotifier extends VocabBankNotifier {
  _FakeVocabBankNotifier(this._records);
  final List<VocabRecord> _records;
  VocabRecord? updatedRecord;
  final List<String> deletedIds = [];

  @override
  Future<List<VocabRecord>> build() async => _records;

  @override
  Future<void> updateRecord(VocabRecord record) async {
    updatedRecord = record;
  }

  @override
  Future<void> delete(String id) async {
    deletedIds.add(id);
  }
}

class _FakeTtsService implements TtsService {
  @override
  Future<void> pronounce(String text, Language language,
      {required PronunciationTier tier}) async {}

  @override
  Future<void> synthesize(String text, Language language,
      {String? voice, double? rate}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeVocabRepository implements VocabRepository {
  _FakeVocabRepository(this._records);
  final List<VocabRecord> _records;

  @override
  Future<VocabRecord?> getById(String id, {required Language language}) async {
    for (final r in _records) {
      if (r.id == id && r.targetLanguage == language) return r;
    }
    return null;
  }

  @override
  Future<void> save(VocabRecord record) async {}

  @override
  Future<List<VocabRecord>> getAll({
    required Language language,
    String? topicId,
    InputType? inputType,
    CEFRLevel? maxCefrLevel,
    bool dueOnly = false,
  }) async =>
      _records.where((r) => r.targetLanguage == language).toList();

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
  Future<List<Topic>> getTopics() async => const [];

  @override
  Future<void> addTopic(Topic topic) async {}

  @override
  Future<void> deleteTopic(String id) async {}
}

VocabRecord _record(
  String id, {
  String headword = 'serendipity',
  String meaning = 'sự tình cờ may mắn',
}) {
  final now = DateTime(2026, 1, 1);
  return VocabRecord(
    id: id,
    headword: headword,
    inputType: InputType.word,
    ipa: '',
    meaning: meaning,
    examples: const [],
    personalNotes: '',
    topicIds: const [],
    targetLanguage: Language.english,
    cefrLevel: CEFRLevel.b1,
    activeContext: AppContext.general,
    createdAt: now,
    updatedAt: now,
  );
}

Future<Widget> _buildScreen(
  List<VocabRecord> records, {
  _FakeVocabBankNotifier? bank,
  GoRouter? router,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final r = router ??
      GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
              path: '/',
              builder: (ctx, state) => const Scaffold(body: Text('home'))),
          GoRoute(
            path: '/vocab/:id',
            builder: (ctx, state) =>
                VocabDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      );
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSettingsNotifierProvider.overrideWith(_FakeSettingsNotifier.new),
      vocabRepositoryProvider.overrideWithValue(_FakeVocabRepository(records)),
      vocabBankNotifierProvider
          .overrideWith(() => bank ?? _FakeVocabBankNotifier(records)),
      topicsNotifierProvider.overrideWith(_FakeTopicsNotifier.new),
      ttsServiceProvider.overrideWithValue(_FakeTtsService()),
    ],
    child: MaterialApp.router(routerConfig: r),
  );
}

void main() {
  testWidgets('view mode renders headword, meaning and a section header',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/vocab/v1',
      routes: [
        GoRoute(
          path: '/vocab/:id',
          builder: (ctx, state) =>
              VocabDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(await _buildScreen(
      [_record('v1', headword: 'ephemeral', meaning: 'phù du')],
      router: router,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ephemeral'), findsWidgets);
    expect(find.text('phù du'), findsOneWidget);
    expect(find.text('NGHĨA'), findsOneWidget);
  });

  testWidgets('tapping edit switches to edit mode with BloomTextFields',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/vocab/v1',
      routes: [
        GoRoute(
          path: '/vocab/:id',
          builder: (ctx, state) =>
              VocabDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
    await tester
        .pumpWidget(await _buildScreen([_record('v1')], router: router));
    await tester.pumpAndSettle();

    expect(find.byType(BloomTextField), findsNothing);

    await tester.tap(find.descendant(
      of: find.byType(BloomIconButton),
      matching: find.byIcon(Icons.edit_outlined),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(BloomTextField), findsWidgets);
    expect(find.widgetWithText(BloomPillButton, 'Lưu'), findsOneWidget);
  });

  testWidgets('_saveEdit sends the edited meaning to updateRecord',
      (tester) async {
    final bank = _FakeVocabBankNotifier([_record('v1')]);
    final router = GoRouter(
      initialLocation: '/vocab/v1',
      routes: [
        GoRoute(
          path: '/vocab/:id',
          builder: (ctx, state) =>
              VocabDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
        await _buildScreen([_record('v1')], bank: bank, router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(
      of: find.byType(BloomIconButton),
      matching: find.byIcon(Icons.edit_outlined),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(BloomTextField).first, 'nghĩa đã sửa');
    await tester.tap(find.widgetWithText(BloomPillButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(bank.updatedRecord, isNotNull);
    expect(bank.updatedRecord!.meaning, 'nghĩa đã sửa');
  });

  testWidgets('delete flow shows the Vietnamese confirm dialog',
      (tester) async {
    await tester
        .pumpWidget(await _buildScreen([_record('v1', headword: 'ephemeral')]));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.text('home'))).push('/vocab/v1');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Xoá khỏi Ngân hàng từ?'), findsOneWidget);
    expect(find.text('"ephemeral" sẽ bị xoá. Không thể hoàn tác.'),
        findsOneWidget);
  });

  testWidgets('confirming delete removes the record and pops the route',
      (tester) async {
    final bank = _FakeVocabBankNotifier([_record('v1', headword: 'ephemeral')]);
    await tester.pumpWidget(await _buildScreen(
      [_record('v1', headword: 'ephemeral')],
      bank: bank,
    ));
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.text('home'))).push('/vocab/v1');
    await tester.pumpAndSettle();

    expect(find.byType(VocabDetailScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(BloomPillButton, 'Xoá'));
    await tester.pumpAndSettle();

    expect(bank.deletedIds, contains('v1'));
    expect(find.byType(VocabDetailScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });
}
