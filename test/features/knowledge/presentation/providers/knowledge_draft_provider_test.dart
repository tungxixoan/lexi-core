import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_draft_provider.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';

import '../../_fakes.dart';

void main() {
  test('submit with a Layer-1 hit → Related state', () async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
    final c = draftContainer(svc, useCase: StubUseCase(okDraft));
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .submit(request: 'giải thích câu điều kiện loại 2');
    expect(c.read(knowledgeDraftNotifierProvider), isA<KnowledgeDraftRelated>());
  });

  test('submit with no hit → Ready state, overwriteNoteId null', () async {
    final svc = FakeKnowledgeService();
    final c = draftContainer(svc, useCase: StubUseCase(okDraft));
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .submit(request: 'chủ đề hoàn toàn mới lạ');
    final s = c.read(knowledgeDraftNotifierProvider);
    expect(s, isA<KnowledgeDraftReady>());
    expect((s as KnowledgeDraftReady).overwriteNoteId, isNull);
  });

  test('extend(note) → Ready with overwriteNoteId == note.id', () async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
    final c = draftContainer(svc, useCase: StubUseCase(okDraft));
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .submit(request: 'câu điều kiện loại 2');
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .extend(svc.store.first);
    final s = c.read(knowledgeDraftNotifierProvider) as KnowledgeDraftReady;
    expect(s.overwriteNoteId, 'a');
  });

  test('use-case throwing → Error state', () async {
    final svc = FakeKnowledgeService();
    final c = draftContainer(svc, useCase: ThrowingUseCase());
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .submit(request: 'x y z mới');
    expect(c.read(knowledgeDraftNotifierProvider), isA<KnowledgeDraftError>());
  });

  test('Layer 2: draft.relatedNoteId matches a note → layer2Related set',
      () async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(id: 'z', title: 'khác hẳn'));
    final c = draftContainer(
      svc,
      useCase: StubUseCase(const KnowledgeNoteDraft(
        title: 'T',
        summary: 'S',
        explanation: 'E',
        relatedNoteId: 'z',
      )),
    );
    await c.read(knowledgeNotesNotifierProvider.future);
    await c
        .read(knowledgeDraftNotifierProvider.notifier)
        .submit(request: 'chủ đề mới toanh');
    final s = c.read(knowledgeDraftNotifierProvider) as KnowledgeDraftReady;
    expect(s.layer2Related?.id, 'z');
  });
}
