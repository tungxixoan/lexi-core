import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_bottom_nav.dart';

const _items = [
  BloomNavItem(icon: Icons.search, label: 'Tra từ'),
  BloomNavItem(icon: Icons.book, label: 'Từ vựng'),
  BloomNavItem(icon: Icons.school, label: 'Luyện tập'),
  BloomNavItem(icon: Icons.settings, label: 'Cài đặt'),
];

void main() {
  testWidgets('bottom nav renders all labels, taps report index', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: BloomBottomNav(
          items: _items, selectedIndex: 0, onSelected: (i) => tapped = i),
      ),
    ));
    for (final it in _items) {
      expect(find.text(it.label), findsOneWidget);
    }
    await tester.tap(find.text('Luyện tập'));
    expect(tapped, 2);
  });

  testWidgets('selected item colors its label with accent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: BloomBottomNav(
          items: _items, selectedIndex: 1, onSelected: (_) {}),
      ),
    ));
    final label = tester.widget<Text>(find.text('Từ vựng'));
    expect(label.style?.color, BloomColors.light.accent);
  });

  testWidgets('rail renders and taps', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Row(children: [
          BloomNavRail(items: _items, selectedIndex: 0, onSelected: (i) => tapped = i),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
    await tester.tap(find.byIcon(Icons.settings));
    expect(tapped, 3);
  });
}
