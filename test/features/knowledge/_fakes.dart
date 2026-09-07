// Shared test doubles for the "Kiến thức" (Knowledge Notes) feature.
//
// Used by the provider tests (Task 9) and every knowledge UI test (Task 11+).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

/// A [UserSettingsNotifier] that just replays a fixed [UserSettingsState].
class FakeSettings extends UserSettingsNotifier {
  FakeSettings(this._s);
  final UserSettingsState _s;
  @override
  UserSettingsState build() => _s;
}

/// In-memory [KnowledgeNotesService]: `store` is the backing list, `seedCalls`
/// counts `seedIfNeeded` invocations.
class FakeKnowledgeService implements KnowledgeNotesService {
  final List<KnowledgeNote> store = [];
  int seedCalls = 0;

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
  Future<List<KnowledgeNote>> restoreStarters(Language language) async =>
      const [];
}

/// A minimal valid [KnowledgeNote] for assertions.
KnowledgeNote noteFixture(
  String id, {
  Language language = Language.english,
  String groupId = 'en_other',
  KnowledgeNoteOrigin origin = KnowledgeNoteOrigin.manual,
  String? title,
  String? sourcePrompt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final t = createdAt ?? DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id,
    title: title ?? 'T $id',
    summary: 's',
    explanation: 'e',
    groupId: groupId,
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
