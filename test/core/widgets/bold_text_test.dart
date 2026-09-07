import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/widgets/bold_text.dart';

void main() {
  testWidgets('renders one Text.rich per paragraph', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BoldText(source: 'para **one**\n\npara two')),
    ));
    expect(find.byType(RichText), findsNWidgets(2));
  });

  testWidgets('bold run gets FontWeight.bold', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BoldText(source: 'a **b** c')),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final root = rich.text as TextSpan;
    final boldSpan = (root.children!).firstWhere(
      (s) => (s as TextSpan).text == 'b',
    ) as TextSpan;
    expect(boldSpan.style!.fontWeight, FontWeight.bold);
  });
}
