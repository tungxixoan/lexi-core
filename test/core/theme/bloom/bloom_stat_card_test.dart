import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_stat_card.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders the label uppercased, the value, and the foot',
      (tester) async {
    await tester.pumpWidget(_host(const BloomStatCard(
      label: 'Hôm nay',
      value: '12',
      foot: 'từ đến hạn ôn tập',
    )));
    expect(find.text('HÔM NAY'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('từ đến hạn ôn tập'), findsOneWidget);
  });

  testWidgets('foot is omitted when null', (tester) async {
    await tester
        .pumpWidget(_host(const BloomStatCard(label: 'Đã thuộc', value: '5')));
    expect(find.text('ĐÃ THUỘC'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    // only 2 Text descendants (label + value)
    expect(
        find.descendant(
            of: find.byType(BloomStatCard), matching: find.byType(Text)),
        findsNWidgets(2));
  });

  testWidgets('value uses ink, label uses inkSoft', (tester) async {
    await tester.pumpWidget(_host(const BloomStatCard(label: 'L', value: 'V')));
    expect(tester.widget<Text>(find.text('V')).style!.color,
        BloomColors.light.ink);
    expect(tester.widget<Text>(find.text('L')).style!.color,
        BloomColors.light.inkSoft);
  });
}
