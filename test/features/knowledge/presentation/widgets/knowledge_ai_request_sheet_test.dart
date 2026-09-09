import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/ai_key_missing_card.dart';

import '../../_fakes.dart';

void main() {
  testWidgets('no API key → AiKeyMissingCard, no "Soạn" button', (tester) async {
    final svc = FakeKnowledgeService();
    await pumpRequestSheet(tester, svc, aiAvailable: false);

    expect(find.byType(AiKeyMissingCard), findsOneWidget);
    expect(find.text('Soạn'), findsNothing);
  });

  testWidgets('Related banner: "Vẫn tạo mới" triggers generation and navigates',
      (tester) async {
    final svc = FakeKnowledgeService()
      ..store.add(noteFixture(id: 'a', title: 'Câu điều kiện loại 2'));
    await pumpRequestSheet(tester, svc, useCase: StubUseCase(okDraft));

    await tester.enterText(
        find.byType(TextField).first, 'câu điều kiện loại 2');
    await tester.tap(find.text('Soạn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ghi chú liên quan'), findsOneWidget);

    await tester.tap(find.text('Vẫn tạo mới'));
    await tester.pumpAndSettle();

    expect(lastPushedLocation, '/knowledge/new');
  });
}
