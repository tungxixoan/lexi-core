import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
import 'package:lexi_core/features/knowledge/presentation/providers/knowledge_notes_provider.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_edit_screen.dart';

import '../../_fakes.dart';

GoRouter _router(Widget screen) => GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(path: '/edit', builder: (_, __) => screen),
        GoRoute(
          path: '/knowledge',
          builder: (_, __) => const Scaffold(body: Text('danh sách')),
        ),
        GoRoute(
          path: '/knowledge/note/:id',
          builder: (_, s) =>
              Scaffold(body: Text('note ${s.pathParameters['id']}')),
        ),
      ],
    );

Future<void> _pump(WidgetTester tester, FakeKnowledgeService svc, Widget screen) {
  return tester.pumpWidget(ProviderScope(
    overrides: knowledgeTestOverrides(svc),
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(screen),
    ),
  ));
}

/// Like [_pump] but resolves the notes provider first, so `_save`'s lookup of
/// the note being overwritten sees a loaded list.
Future<void> _pumpLoaded(
    WidgetTester tester, FakeKnowledgeService svc, Widget screen) async {
  final container = ProviderContainer(overrides: knowledgeTestOverrides(svc));
  addTearDown(container.dispose);
  // Hold a listener so the auto-dispose provider stays alive through the pump.
  final sub = container.listen(knowledgeNotesNotifierProvider, (_, __) {});
  addTearDown(sub.close);
  await container.read(knowledgeNotesNotifierProvider.future);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: _router(screen),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('review-draft mode pre-fills the form and saves an ai note',
      (tester) async {
    final svc = FakeKnowledgeService();
    const draft = KnowledgeNoteDraft(
      title: 'Câu điều kiện loại 2',
      summary: 'S',
      explanation: 'E',
      suggestedGroupId: 'en_conditionals',
    );
    await _pump(
      tester,
      svc,
      const KnowledgeEditScreen(draft: draft, sourcePrompt: 'loại 2'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Câu điều kiện loại 2'), findsOneWidget);

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store.single.origin.name, 'ai');
    expect(svc.store.single.groupId, 'en_conditionals');
    expect(svc.store.single.sourcePrompt, 'loại 2');
  });

  testWidgets('blank-new with empty title shows a validation error',
      (tester) async {
    final svc = FakeKnowledgeService();
    await _pump(tester, svc, const KnowledgeEditScreen());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store, isEmpty);
    expect(find.textContaining('Nhập tiêu đề'), findsOneWidget);
  });

  testWidgets('save failure keeps the form and shows the error text',
      (tester) async {
    final svc = FakeKnowledgeService(throwOnUpsert: true);
    await _pump(
      tester,
      svc,
      const KnowledgeEditScreen(
        draft: KnowledgeNoteDraft(
          title: 'Ghi chú X',
          summary: 'S',
          explanation: 'E',
          suggestedGroupId: 'en_other',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không lưu được'), findsOneWidget);
    expect(find.text('Xem lại bản nháp'), findsOneWidget); // still on the form
    expect(svc.store, isEmpty);
  });

  testWidgets('"Bổ sung" overwrite keeps an existing manual note\'s origin',
      (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(
        id: 'n1',
        origin: KnowledgeNoteOrigin.manual,
        groupId: 'en_other',
      ));
    await _pumpLoaded(
      tester,
      svc,
      const KnowledgeEditScreen(
        draft: KnowledgeNoteDraft(
          title: 'Bản nháp bổ sung',
          summary: 'S',
          explanation: 'E',
          suggestedGroupId: 'en_other',
        ),
        overwriteNoteId: 'n1',
      ),
    );

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store.single.id, 'n1');
    expect(svc.store.single.origin.name, 'manual');
  });

  testWidgets('"Bổ sung" overwrite promotes a starter note to ai',
      (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(
        id: 'n1',
        origin: KnowledgeNoteOrigin.starter,
        groupId: 'en_other',
      ));
    await _pumpLoaded(
      tester,
      svc,
      const KnowledgeEditScreen(
        draft: KnowledgeNoteDraft(
          title: 'Bản nháp bổ sung',
          summary: 'S',
          explanation: 'E',
          suggestedGroupId: 'en_other',
        ),
        overwriteNoteId: 'n1',
      ),
    );

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store.single.origin.name, 'ai');
  });

  testWidgets('edit mode preserves origin + createdAt when the list is empty',
      (tester) async {
    final svc = FakeKnowledgeService();
    final created = DateTime.utc(2020, 5, 1);
    final note = noteFixture(
      id: 'n1',
      origin: KnowledgeNoteOrigin.starter,
      groupId: 'en_conditionals',
      createdAt: created,
    );
    // Notifier list deliberately NOT pre-loaded — svc.store is empty.
    await _pump(tester, svc, KnowledgeEditScreen(initial: note));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(svc.store.single.id, 'n1');
    expect(svc.store.single.origin.name, 'starter');
    expect(svc.store.single.createdAt, created);
  });
}
