import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/router/app_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/knowledge/data/sources/knowledge_note_source.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_detail_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_edit_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_group_screen.dart';
import 'package:lexi_core/features/knowledge/presentation/screens/knowledge_home_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';

import '../../features/knowledge/_fakes.dart';

Future<void> _pump(
  WidgetTester tester,
  String location,
  FakeKnowledgeService svc, {
  Object? extra,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...knowledgeTestOverrides(svc),
        vocabBankNotifierProvider.overrideWith(() => FakeVocabBank()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          initialLocation: location,
          routes: knowledgeRoutes,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (extra != null) {
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(location, extra: extra);
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('/knowledge shows KnowledgeHomeScreen', (tester) async {
    await _pump(tester, '/knowledge', FakeKnowledgeService());
    expect(find.byType(KnowledgeHomeScreen), findsOneWidget);
  });

  testWidgets('/knowledge/group/:groupId shows KnowledgeGroupScreen',
      (tester) async {
    await _pump(tester, '/knowledge/group/en_tenses', FakeKnowledgeService());
    expect(find.byType(KnowledgeGroupScreen), findsOneWidget);
  });

  testWidgets('/knowledge/note/:id shows KnowledgeDetailScreen', (tester) async {
    await _pump(tester, '/knowledge/note/x', FakeKnowledgeService());
    expect(find.byType(KnowledgeDetailScreen), findsOneWidget);
  });

  testWidgets('/knowledge/new without extra shows a blank KnowledgeEditScreen',
      (tester) async {
    await _pump(tester, '/knowledge/new', FakeKnowledgeService());
    expect(find.byType(KnowledgeEditScreen), findsOneWidget);
    expect(find.text('Ghi chú mới'), findsOneWidget);
  });

  testWidgets('/knowledge/new with a draft extra shows the review form',
      (tester) async {
    await _pump(
      tester,
      '/knowledge/new',
      FakeKnowledgeService(),
      extra: (
        draft: const KnowledgeNoteDraft(
          title: 'Câu điều kiện loại 2',
          summary: 's',
          explanation: 'e',
        ),
        request: 'giải thích câu điều kiện loại 2',
        overwriteNoteId: null,
      ),
    );
    expect(find.byType(KnowledgeEditScreen), findsOneWidget);
    expect(find.text('Xem lại bản nháp'), findsOneWidget);
  });

  testWidgets('/knowledge/note/:id/edit loads the note into the edit form',
      (tester) async {
    final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'n1'));
    await _pump(tester, '/knowledge/note/n1/edit', svc);
    expect(find.byType(KnowledgeEditScreen), findsOneWidget);
    expect(find.text('Sửa ghi chú'), findsOneWidget);
  });
}
