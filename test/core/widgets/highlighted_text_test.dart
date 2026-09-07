import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/widgets/highlighted_text.dart';

void main() {
  testWidgets('no highlights → plain Text', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: HighlightedText(text: 'hello world', highlights: []),
      ),
    ));
    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('accent-insensitive match splits into spans', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: HighlightedText(
          text: 'Tôi thích điều kiện', highlights: ['dieu kien'],
        ),
      ),
    ));
    final rich = tester.widget<RichText>(find.byType(RichText));
    final root = rich.text as TextSpan;
    final matched = (root.children!).map((s) => (s as TextSpan).text).toList();
    expect(matched, ['Tôi thích ', 'điều kiện']);
  });
}
