import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../_fakes.dart';

void main() {
  testWidgets('shows a group grid with counts', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.addAll([
        noteFixture(id: 'a', group: 'en_tenses'),
        noteFixture(id: 'b', group: 'en_tenses'),
        noteFixture(id: 'c', group: 'en_conditionals'),
      ]);
    await pumpHome(tester, svc);
    expect(find.text('Thì'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // count badge
  });

  testWidgets('typing in search switches to a flat result list', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.addAll([
        noteFixture(id: 'a', title: 'Câu điều kiện loại 2'),
        noteFixture(id: 'b', title: 'Thì hiện tại đơn'),
      ]);
    await pumpHome(tester, svc);
    await tester.enterText(find.byType(TextField).first, 'dieu kien');
    await tester.pumpAndSettle();
    expect(find.text('Câu điều kiện loại 2'), findsOneWidget);
    expect(find.text('Thì hiện tại đơn'), findsNothing);
  });

  testWidgets('Khôi phục ghi chú mẫu calls restoreStarters', (tester) async {
    final svc = FakeKnowledgeService();
    await pumpHome(tester, svc);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khôi phục ghi chú mẫu'));
    await tester.pumpAndSettle();
    expect(svc.restoreCalls, 1);
  });
}
