import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_app_bar.dart';

void main() {
  testWidgets('shows the title and an 800-weight style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(appBar: BloomAppBar(title: 'Tra từ'), body: SizedBox()),
    ));
    expect(find.text('Tra từ'), findsOneWidget);
    final txt = tester.widget<Text>(find.text('Tra từ'));
    expect(txt.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('BloomIconButton fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomIconButton(icon: Icons.settings, onPressed: () => taps++),
      ),
    ));
    await tester.tap(find.byIcon(Icons.settings));
    expect(taps, 1);
  });
}
