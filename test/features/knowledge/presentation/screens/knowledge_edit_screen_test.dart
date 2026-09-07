import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';
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

  testWidgets('edit mode preserves origin + createdAt when the list is empty',
      (tester) async {
    final svc = FakeKnowledgeService();
    final created = DateTime.utc(2020, 5, 1);
    final note = noteFixture(
      'n1',
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
