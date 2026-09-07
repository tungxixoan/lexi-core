import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/language.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';

import '../../_fakes.dart';

ProviderContainer _container(FakeKnowledgeService svc,
    {Language lang = Language.english}) {
  return ProviderContainer(
    overrides: knowledgeTestOverrides(svc, language: lang),
  );
}

void main() {
  test('build() seeds then loads notes for the active language', () async {
    final svc = FakeKnowledgeService()
      ..store.addAll(
          [noteFixture(id: 'a'), noteFixture(id: 'b', language: Language.chinese)]);
    final c = _container(svc);
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(svc.seedCalls, 1);
    expect(notes.map((n) => n.id), ['a']);
  });

  test('saveNote upserts and refreshes', () async {
    final svc = FakeKnowledgeService();
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeNotesNotifierProvider.notifier)
        .saveNote(noteFixture(id: 'x'));
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes.map((n) => n.id), contains('x'));
  });

  test('deleteNote removes from state', () async {
    final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'x'));
    final c = _container(svc);
    await c.read(knowledgeNotesNotifierProvider.future);
    await c.read(knowledgeNotesNotifierProvider.notifier).deleteNote('x');
    final notes = await c.read(knowledgeNotesNotifierProvider.future);
    expect(notes, isEmpty);
  });
}
