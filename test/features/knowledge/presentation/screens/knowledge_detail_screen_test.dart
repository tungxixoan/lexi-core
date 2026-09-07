import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/knowledge/domain/entities/knowledge_note.dart';

import '../../_fakes.dart';

void main() {
  testWidgets('renders sections and hides empty ones', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(
        id: 'n1',
        title: 'Câu điều kiện loại 2',
        summary: 'Giả định không có thật ở hiện tại.',
        explanation: 'Dùng **were**.',
        patterns: ['If + S + V2, S + would + V'],
      ));
    await pumpDetail(tester, svc, id: 'n1');

    expect(find.text('Câu điều kiện loại 2'), findsOneWidget);
    expect(find.text('Giả định không có thật ở hiện tại.'), findsOneWidget);
    // patterns present -> "Mẫu câu" header (uppercased by BloomSectionHeader)
    expect(find.text('MẪU CÂU'), findsOneWidget);
    expect(find.text('If + S + V2, S + would + V'), findsOneWidget);
    // examples + pitfalls empty -> their headers are hidden
    expect(find.text('VÍ DỤ'), findsNothing);
    expect(find.text('LỖI THƯỜNG GẶP'), findsNothing);
  });

  testWidgets('shows example + pitfall sections when present', (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(
        id: 'n1',
        examples: const [
          KnowledgeExample(text: 'If I were you', translation: 'Nếu tôi là bạn'),
        ],
        pitfalls: const ['Không dùng "was" ở văn viết trang trọng.'],
      ));
    await pumpDetail(tester, svc, id: 'n1');

    expect(find.text('VÍ DỤ'), findsOneWidget);
    expect(find.text('Nếu tôi là bạn'), findsOneWidget);
    expect(find.text('LỖI THƯỜNG GẶP'), findsOneWidget);
  });

  testWidgets('unknown id shows a not-found message', (tester) async {
    final svc = FakeKnowledgeService();
    await pumpDetail(tester, svc, id: 'missing');
    expect(find.text('Không tìm thấy ghi chú'), findsOneWidget);
  });

  testWidgets('delete asks for confirmation then removes', (tester) async {
    final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'n1'));
    await pumpDetail(tester, svc, id: 'n1');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Xoá ghi chú?'), findsOneWidget);

    await tester.tap(find.text('Xoá'));
    await tester.pumpAndSettle();
    expect(svc.store, isEmpty);
  });

  testWidgets('cancelling the delete dialog keeps the note', (tester) async {
    final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'n1'));
    await pumpDetail(tester, svc, id: 'n1');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(svc.store, isNotEmpty);
  });

  testWidgets('edit action navigates to the edit route', (tester) async {
    final svc = FakeKnowledgeService()..store.add(noteFixture(id: 'n1'));
    await pumpDetail(tester, svc, id: 'n1');

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('sửa n1'), findsOneWidget);
  });
}
