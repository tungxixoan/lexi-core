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

  testWidgets('no trailing widget when trailingText is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
          body: BloomListRow(cefr: 'A1', headword: 'x', meaning: 'y')),
    ));
    expect(find.text('2 ngày'), findsNothing);
    // and no exception thrown building it
  });

  testWidgets('builds and taps are a no-op when onTap is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
          body: BloomListRow(cefr: 'A1', headword: 'x', meaning: 'y')),
    ));
    await tester.tap(find.text('x')); // must not throw
  });

  testWidgets('long headword does not overflow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
          body: SizedBox(
              width: 200,
              child: BloomListRow(
                cefr: 'B2',
                headword: 'a very very very long multi word headword entry',
                meaning: 'nghĩa dài',
                trailingText: '2 ngày',
              ))),
    ));
    expect(tester.takeException(), isNull);
  });
}
