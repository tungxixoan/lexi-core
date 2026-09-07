import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/knowledge/presentation/widgets/knowledge_note_row.dart';
import 'package:lexi_core/features/vocabulary/domain/entities/cefr_level.dart';

import '../../_fakes.dart';

void main() {
  testWidgets('sections notes by CEFR', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.addAll([
        noteFixture(id: 'a', group: 'en_tenses', level: CEFRLevel.a1),
        noteFixture(id: 'b', group: 'en_tenses', level: CEFRLevel.b2),
        noteFixture(id: 'c', group: 'en_tenses', level: null),
      ]);
    await pumpGroup(tester, svc, groupId: 'en_tenses');

    expect(find.widgetWithText(BloomSectionHeader, 'A1'), findsOneWidget);
    expect(find.widgetWithText(BloomSectionHeader, 'B2'), findsOneWidget);
    expect(
      find.widgetWithText(BloomSectionHeader, 'CHƯA GẮN CẤP ĐỘ'),
      findsOneWidget,
    );
    expect(find.byType(KnowledgeNoteRow), findsNWidgets(3));
    // AppBar shows the group label
    expect(find.widgetWithText(BloomAppBar, 'Thì'), findsOneWidget);
  });

  testWidgets('filters to the group and hides empty CEFR sections',
      (tester) async {
    final svc = FakeKnowledgeService()
      ..store.addAll([
        noteFixture(id: 'a', group: 'en_tenses', level: CEFRLevel.a1),
        noteFixture(id: 'x', group: 'en_conditionals', level: CEFRLevel.c2),
      ]);
    await pumpGroup(tester, svc, groupId: 'en_tenses');

    expect(find.widgetWithText(BloomSectionHeader, 'A1'), findsOneWidget);
    expect(find.widgetWithText(BloomSectionHeader, 'C2'), findsNothing);
    expect(find.byType(KnowledgeNoteRow), findsOneWidget);
  });

  testWidgets('tapping a row opens the note detail', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(
        id: 'a',
        group: 'en_tenses',
        title: 'Thì hiện tại đơn',
      ));
    await pumpGroup(tester, svc, groupId: 'en_tenses');

    await tester.tap(find.text('Thì hiện tại đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Thì hiện tại đơn'), findsOneWidget);
  });

  testWidgets('empty group shows a placeholder', (tester) async {
    final svc = FakeKnowledgeService();
    await pumpGroup(tester, svc, groupId: 'en_tenses');
    expect(find.textContaining('Chưa có ghi chú'), findsOneWidget);
  });
}
