import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_segmented.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

const _segs = [
  BloomSegment(value: 1, label: 'Một'),
  BloomSegment(value: 2, label: 'Hai'),
  BloomSegment(value: 3, label: 'Ba'),
];

void main() {
  testWidgets('renders one label per segment', (tester) async {
    await tester.pumpWidget(_host(
        BloomSegmented<int>(segments: _segs, selected: 2, onChanged: (_) {})));
    for (final l in ['Một', 'Hai', 'Ba']) {
      expect(find.text(l), findsOneWidget);
    }
  });

  testWidgets(
      'the selected segment label is drawn in accentInk, others in inkSoft',
      (tester) async {
    await tester.pumpWidget(_host(
        BloomSegmented<int>(segments: _segs, selected: 2, onChanged: (_) {})));
    expect(tester.widget<Text>(find.text('Hai')).style!.color,
        BloomColors.light.accentInk);
    expect(tester.widget<Text>(find.text('Một')).style!.color,
        BloomColors.light.inkSoft);
  });

  testWidgets('tapping a segment reports its value', (tester) async {
    int? got;
    await tester.pumpWidget(_host(BloomSegmented<int>(
        segments: _segs, selected: 1, onChanged: (v) => got = v)));
    await tester.tap(find.text('Ba'));
    expect(got, 3);
  });

  testWidgets('works with an enum value type', (tester) async {
    await tester.pumpWidget(_host(BloomSegmented<ThemeMode>(
      segments: const [
        BloomSegment(value: ThemeMode.light, label: 'Sáng'),
        BloomSegment(value: ThemeMode.dark, label: 'Tối'),
        BloomSegment(value: ThemeMode.system, label: 'Hệ thống'),
      ],
      selected: ThemeMode.system,
      onChanged: (_) {},
    )));
    expect(find.text('Hệ thống'), findsOneWidget);
  });
}
