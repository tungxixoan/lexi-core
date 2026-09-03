import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_bar_chart.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

const _bars = [
  BloomBarChartBar(label: 'T2', value: 0),
  BloomBarChartBar(label: 'T3', value: 4),
  BloomBarChartBar(label: 'T4', value: 10),
  BloomBarChartBar(label: 'T5', value: 2),
  BloomBarChartBar(label: 'T6', value: 0),
  BloomBarChartBar(label: 'T7', value: 6),
  BloomBarChartBar(label: 'CN', value: 3, highlight: true),
];

void main() {
  testWidgets('renders every day label', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    for (final l in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets('shows the value above each non-zero bar, hides it for zero', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    expect(find.text('10'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // '0' days show no number
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the highlighted day label is drawn in accent', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: _bars)));
    expect(tester.widget<Text>(find.text('CN')).style!.color, BloomColors.light.accent);
    expect(tester.widget<Text>(find.text('T2')).style!.color, BloomColors.light.inkFaint);
  });

  testWidgets('renders with an all-zero week without throwing', (tester) async {
    await tester.pumpWidget(_host(const BloomBarChart(bars: [
      BloomBarChartBar(label: 'T2', value: 0),
      BloomBarChartBar(label: 'T3', value: 0),
    ])));
    expect(tester.takeException(), isNull);
  });
}
