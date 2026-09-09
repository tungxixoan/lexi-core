// Shared test doubles for the "Kiến thức" (Knowledge Notes) feature.
//
// Used by the provider tests (Task 9) and every knowledge UI test (Task 11+).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/domain/use_cases/generate_knowledge_note_use_case.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_detail_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_group_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_home_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/widgets/knowledge_ai_request_sheet.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/vocab_record.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

/// A [UserSettingsNotifier] that just replays a fixed [UserSettingsState].
class FakeSettings extends UserSettingsNotifier {
  FakeSettings(this._s);
  final UserSettingsState _s;
  @override
  UserSettingsState build() => _s;
}

/// A [VocabBankNotifier] that never touches Hive/Firestore — returns a fixed
/// (default empty) record list so the detail screen's example-highlighting
/// lookup stays inert in widget tests.
class FakeVocabBank extends VocabBankNotifier {
  FakeVocabBank([this._records = const []]);
  final List<VocabRecord> _records;
  @override
  Future<List<VocabRecord>> build() async => _records;
}

/// In-memory [KnowledgeNotesService]: `store` is the backing list, `seedCalls`
/// counts `seedIfNeeded` invocations.
class FakeKnowledgeService implements KnowledgeNotesService {
  final List<KnowledgeNote> store = [];
  int seedCalls = 0;
  int restoreCalls = 0;

  @override
  Future<List<KnowledgeNote>> all(Language language) async =>
      store.where((n) => n.targetLanguage == language).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> upsert(KnowledgeNote note) async {
    store.removeWhere((n) => n.id == note.id);
    store.add(note);
  }

  @override
  Future<void> delete(String id) async => store.removeWhere((n) => n.id == id);

  @override
  Future<List<KnowledgeNote>> seedIfNeeded(Language language) async {
    seedCalls++;
    return const [];
  }

  @override
  Future<List<KnowledgeNote>> restoreStarters(Language language) async {
    restoreCalls++;
    return const [];
  }
}

/// A minimal valid [KnowledgeNote] for assertions.
KnowledgeNote noteFixture({
  String id = 'n1',
  Language language = Language.english,
  String groupId = 'en_other',
  String? group,
  KnowledgeNoteOrigin origin = KnowledgeNoteOrigin.manual,
  String? title,
  String summary = 's',
  String explanation = 'e',
  List<String> patterns = const [],
  List<KnowledgeExample> examples = const [],
  List<String> pitfalls = const [],
  List<String> tags = const [],
  CEFRLevel? level,
  String? sourcePrompt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final t = createdAt ?? DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id,
    title: title ?? 'T $id',
    summary: summary,
    explanation: explanation,
    patterns: patterns,
    examples: examples,
    pitfalls: pitfalls,
    groupId: group ?? groupId,
    tags: tags,
    cefrLevel: level,
    targetLanguage: language,
    origin: origin,
    sourcePrompt: sourcePrompt,
    createdAt: t,
    updatedAt: updatedAt ?? t,
  );
}

/// ProviderScope / ProviderContainer overrides wiring the fake service and a
/// fixed target language into the knowledge providers.
List<Override> knowledgeTestOverrides(
  FakeKnowledgeService svc, {
  Language language = Language.english,
}) =>
    [
      knowledgeNotesServiceProvider.overrideWithValue(svc),
      userSettingsNotifierProvider.overrideWith(
        () => FakeSettings(
          UserSettingsState.defaults.copyWith(targetLanguage: language),
        ),
      ),
    ];

GoRouter _knowledgeRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/knowledge',
          builder: (_, __) => const Scaffold(body: Text('danh sách')),
        ),
        GoRoute(
          path: '/knowledge/group/:groupId',
          builder: (_, s) =>
              KnowledgeGroupScreen(groupId: s.pathParameters['groupId']!),
        ),
        GoRoute(
          path: '/knowledge/note/:id',
          builder: (_, s) =>
              KnowledgeDetailScreen(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/knowledge/note/:id/edit',
          builder: (_, s) =>
              Scaffold(body: Text('sửa ${s.pathParameters['id']}')),
        ),
      ],
    );

Future<void> _pumpKnowledge(
  WidgetTester tester,
  FakeKnowledgeService svc,
  String initialLocation, {
  Language language = Language.english,
  List<VocabRecord> vocab = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...knowledgeTestOverrides(svc, language: language),
        vocabBankNotifierProvider.overrideWith(() => FakeVocabBank(vocab)),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: _knowledgeRouter(initialLocation),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [KnowledgeDetailScreen] for [id] behind a minimal GoRouter.
Future<void> pumpDetail(
  WidgetTester tester,
  FakeKnowledgeService svc, {
  required String id,
  Language language = Language.english,
  List<VocabRecord> vocab = const [],
}) =>
    _pumpKnowledge(tester, svc, '/knowledge/note/$id',
        language: language, vocab: vocab);

/// Pumps [KnowledgeHomeScreen] behind a minimal GoRouter (group / note / new
/// destinations are stubbed).
Future<void> pumpHome(
  WidgetTester tester,
  FakeKnowledgeService svc, {
  Language language = Language.english,
}) async {
  final router = GoRouter(
    initialLocation: '/knowledge',
    routes: [
      GoRoute(
        path: '/knowledge',
        builder: (_, __) => const KnowledgeHomeScreen(),
      ),
      GoRoute(
        path: '/knowledge/group/:groupId',
        builder: (_, s) =>
            Scaffold(body: Text('nhóm ${s.pathParameters['groupId']}')),
      ),
      GoRoute(
        path: '/knowledge/note/:id',
        builder: (_, s) =>
            Scaffold(body: Text('ghi chú ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/knowledge/new',
        builder: (_, __) => const Scaffold(body: Text('ghi chú mới')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...knowledgeTestOverrides(svc, language: language),
        vocabBankNotifierProvider.overrideWith(() => FakeVocabBank()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps [KnowledgeGroupScreen] for [groupId] behind a minimal GoRouter.
Future<void> pumpGroup(
  WidgetTester tester,
  FakeKnowledgeService svc, {
  required String groupId,
  Language language = Language.english,
}) =>
    _pumpKnowledge(tester, svc, '/knowledge/group/$groupId', language: language);

// ---------------------------------------------------------------------------
// "Nhờ AI soạn" draft flow (Task 14)
// ---------------------------------------------------------------------------

/// A [GenerateKnowledgeNoteUseCase] that returns a fixed [KnowledgeNoteDraft]
/// without touching an AI client.
class StubUseCase implements GenerateKnowledgeNoteUseCase {
  StubUseCase(this._draft);
  final KnowledgeNoteDraft _draft;

  @override
  Future<KnowledgeNoteDraft> execute({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) async =>
      _draft;
}

/// A [GenerateKnowledgeNoteUseCase] whose [execute] always throws.
class ThrowingUseCase implements GenerateKnowledgeNoteUseCase {
  @override
  Future<KnowledgeNoteDraft> execute({
    required String request,
    required Language targetLanguage,
    String? hintGroupId,
    CEFRLevel? hintCefr,
    required List<KnowledgeNote> existingInScope,
    KnowledgeNote? extendingNote,
  }) async =>
      throw Exception('boom');
}

/// A minimal valid AI draft for assertions.
const okDraft = KnowledgeNoteDraft(
  title: 'Câu điều kiện loại 2 và 3',
  summary: 'Tóm tắt',
  explanation: 'Giải thích',
);

/// ProviderContainer wiring the fake service, a fixed language and a stubbed
/// use-case into the knowledge draft providers.
ProviderContainer draftContainer(
  FakeKnowledgeService svc, {
  GenerateKnowledgeNoteUseCase? useCase,
  Language language = Language.english,
}) =>
    ProviderContainer(
      overrides: [
        ...knowledgeTestOverrides(svc, language: language),
        generateKnowledgeNoteUseCaseProvider
            .overrideWithValue(useCase ?? StubUseCase(okDraft)),
      ],
    );

/// Route location + extra recorded by [pumpRequestSheet]'s stub `/knowledge/new`.
String? lastPushedLocation;
Object? lastPushedExtra;

/// Pumps a page whose single button opens [showKnowledgeAiRequestSheet], behind
/// a GoRouter that records navigation to `/knowledge/new`.
Future<void> pumpRequestSheet(
  WidgetTester tester,
  FakeKnowledgeService svc, {
  GenerateKnowledgeNoteUseCase? useCase,
  Language language = Language.english,
}) async {
  lastPushedLocation = null;
  lastPushedExtra = null;
  final router = GoRouter(
    initialLocation: '/knowledge',
    routes: [
      GoRoute(
        path: '/knowledge',
        builder: (_, __) => Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showKnowledgeAiRequestSheet(context),
                child: const Text('mở sheet'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/knowledge/new',
        builder: (_, s) {
          lastPushedLocation = '/knowledge/new';
          lastPushedExtra = s.extra;
          return const Scaffold(body: Text('ghi chú mới'));
        },
      ),
      GoRoute(
        path: '/knowledge/note/:id',
        builder: (_, s) =>
            Scaffold(body: Text('ghi chú ${s.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...knowledgeTestOverrides(svc, language: language),
        generateKnowledgeNoteUseCaseProvider
            .overrideWithValue(useCase ?? StubUseCase(okDraft)),
        vocabBankNotifierProvider.overrideWith(() => FakeVocabBank()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('mở sheet'));
  await tester.pumpAndSettle();
}
