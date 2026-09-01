import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_chip.dart';
import 'package:lexi_core/core/theme/bloom/bloom_group_chips.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('renders one chip per label', (tester) async {
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['Đoạn 1', 'Đoạn 2', 'Đoạn 3'],
      activeIndex: 0,
      onChanged: (_) {},
    )));
    expect(find.byType(BloomChip), findsNWidgets(3));
    expect(find.text('Đoạn 2'), findsOneWidget);
  });

  testWidgets('tapping a chip reports its index', (tester) async {
    int? tapped;
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['Đoạn 1', 'Đoạn 2', 'Đoạn 3'],
      activeIndex: 0,
      onChanged: (i) => tapped = i,
    )));
    await tester.tap(find.text('Đoạn 3'));
    expect(tapped, 2);
  });

  testWidgets('the active chip uses the active style', (tester) async {
    await tester.pumpWidget(_host(BloomGroupChips(
      labels: const ['A', 'B'],
      activeIndex: 1,
      onChanged: (_) {},
    )));
    final chips = tester.widgetList<BloomChip>(find.byType(BloomChip)).toList();
    expect(chips[0].style, BloomChipStyle.neutral);
    expect(chips[1].style, BloomChipStyle.active);
  });
}
