import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/knowledge/data/knowledge_notes_service.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';

class _FakeSettings extends UserSettingsNotifier {
  _FakeSettings(this._s);
  final UserSettingsState _s;
  @override
  UserSettingsState build() => _s;
}

class _FakeService implements KnowledgeNotesService {
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

KnowledgeNote _note(String id, {Language lang = Language.english}) {
  final t = DateTime.utc(2026, 1, 1);
  return KnowledgeNote(
    id: id,
    title: 'T $id',
    summary: 's',
    explanation: 'e',
    groupId: 'en_other',
    targetLanguage: lang,
    origin: KnowledgeNoteOrigin.manual,
    createdAt: t,
    updatedAt: t,
  );
}

ProviderContainer _container(_FakeService svc, {Language lang = Language.english}) {
  return ProviderContainer(overrides: [
    knowledgeNotesServiceProvider.overrideWithValue(svc),
    userSettingsNotifierProvider.overrideWith(() => _FakeSettings(
          UserSettingsState.defaults.copyWith(targetLanguage: lang),
        )),
  ]);
}

void main() {
  test('build() seeds then loads notes for the active language', () async {
    final svc = _FakeService()
      ..store.addAll([_note('a'), _note('b', lang: Language.chinese)]);
    final c = _container(svc);
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(svc.seedCalls, 1);
    expect(notes.map((n) => n.id), ['a']);
  });

  test('saveNote upserts and refreshes', () async {
    final svc = _FakeService();
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c.read(knowledgeNotesNotifierProvider.notifier).saveNote(_note('x'));
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes.map((n) => n.id), contains('x'));
  });

  test('deleteNote removes from state', () async {
    final svc = _FakeService()..store.add(_note('x'));
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c.read(knowledgeNotesNotifierProvider.notifier).deleteNote('x');
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes, isEmpty);
  });
}
