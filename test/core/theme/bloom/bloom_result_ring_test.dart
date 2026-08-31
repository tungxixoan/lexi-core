import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_result_ring.dart';

void main() {
  testWidgets('shows the default percent label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: Center(child: BloomResultRing(percent: 73))),
    ));
    expect(find.text('73%'), findsOneWidget);
  });

  testWidgets('honours an explicit label and clamps the arc', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: BloomResultRing(percent: 250, label: 'A+')),
      ),
    ));
    expect(find.text('A+'), findsOneWidget);
    expect(find.text('250%'), findsNothing);
    expect(tester.takeException(), isNull); // clamped, no assert
  });

  testWidgets('lays out at the requested size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(child: BloomResultRing(percent: 50, size: 120)),
      ),
    ));
    expect(tester.getSize(find.byType(BloomResultRing)), const Size(120, 120));
  });
}
