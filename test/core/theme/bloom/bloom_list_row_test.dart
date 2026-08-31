import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_list_row.dart';

void main() {
  testWidgets('shows dot, headword, meaning, trailing; taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomListRow(
          cefr: 'B2',
          headword: 'resilient',
          meaning: 'kiên cường',
          trailingText: '2 ngày',
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('resilient'), findsOneWidget);
    expect(find.text('kiên cường'), findsOneWidget);
    expect(find.text('2 ngày'), findsOneWidget);
    await tester.tap(find.text('resilient'));
    expect(taps, 1);
  });
}
