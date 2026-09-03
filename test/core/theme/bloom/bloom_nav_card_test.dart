import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_card.dart';
import 'package:lexi_core/core/theme/bloom/bloom_nav_card.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('renders title, subtitle, and the icon', (tester) async {
    await tester.pumpWidget(_host(BloomNavCard(
      icon: Icons.menu_book_outlined,
      title: 'Luyện đọc',
      subtitle: 'Đọc & gõ song ngữ.',
      onTap: () {},
    )));
    expect(find.text('Luyện đọc'), findsOneWidget);
    expect(find.text('Đọc & gõ song ngữ.'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
  });

  testWidgets('tapping fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(BloomNavCard(
      icon: Icons.headphones_outlined,
      title: 'Luyện nghe',
      subtitle: 'Nghe chép và nghe hiểu.',
      onTap: () => taps++,
    )));
    await tester.tap(find.text('Luyện nghe'));
    expect(taps, 1);
  });

  testWidgets('selected: true sets the BloomCard.selected flag',
      (tester) async {
    await tester.pumpWidget(_host(BloomNavCard(
      icon: Icons.school_outlined,
      title: 'Từ vựng cách khoảng',
      subtitle: 'Ôn từ vựng theo lịch SM-2.',
      selected: true,
      onTap: () {},
    )));
    expect(
      tester.widget<BloomCard>(find.byType(BloomCard)).selected,
      isTrue,
    );
  });
}
