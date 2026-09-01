import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/ai_disabled_card.dart';

void main() {
  testWidgets('renders the given message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AiDisabledCard(message: 'Cần bật AI để dùng.')),
      ),
    );
    expect(find.text('Cần bật AI để dùng.'), findsOneWidget);
    expect(find.byType(AiDisabledCard), findsOneWidget);
  });
}
