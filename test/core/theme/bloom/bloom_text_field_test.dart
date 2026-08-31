import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_text_field.dart';

void main() {
  testWidgets('accepts input and reports changes', (tester) async {
    String? last;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(hintText: 'Tra từ', onChanged: (v) => last = v),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'resilient');
    expect(last, 'resilient');
    expect(find.text('resilient'), findsOneWidget); // entered text renders
  });

  testWidgets('single-line uses a pill border', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomTextField(hintText: 'x')),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.enabledBorder as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(999));
  });
}
