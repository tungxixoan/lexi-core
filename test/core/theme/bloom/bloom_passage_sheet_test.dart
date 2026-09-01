import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_passage_sheet.dart';

Widget _host(Widget sheet) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Stack(children: [const SizedBox.expand(), sheet]),
      ),
    );

void main() {
  testWidgets('single tab: shows the passage text and the hint', (tester) async {
    await tester.pumpWidget(_host(BloomPassageSheet(
      tabs: ['Văn bản'],
      passages: ['The quarterly report is attached.'],
      initialChildSize: 0.6,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Kéo lên để đọc đoạn văn'), findsOneWidget);
    expect(find.text('The quarterly report is attached.'), findsOneWidget);
  });

  testWidgets('two tabs: switching the tab swaps the passage text', (tester) async {
    await tester.pumpWidget(_host(BloomPassageSheet(
      tabs: ['Văn bản 1', 'Văn bản 2'],
      passages: ['FIRST DOC', 'SECOND DOC'],
      initialChildSize: 0.6,
    )));
    await tester.pumpAndSettle();
    expect(find.text('FIRST DOC'), findsOneWidget);
    expect(find.text('SECOND DOC'), findsNothing);

    await tester.tap(find.text('Văn bản 2'));
    await tester.pumpAndSettle();
    expect(find.text('SECOND DOC'), findsOneWidget);
    expect(find.text('FIRST DOC'), findsNothing);
  });

  testWidgets('single tab: no tab selector chips are shown', (tester) async {
    await tester.pumpWidget(_host(BloomPassageSheet(
      tabs: ['Văn bản'],
      passages: ['x'],
    )));
    await tester.pumpAndSettle();
    // The only tappable pill-like control would be a tab; there are none.
    expect(find.text('Văn bản'), findsNothing);
  });

  testWidgets('bottom-anchors as a bare Stack overlay', (tester) async {
    await tester.pumpWidget(_host(BloomPassageSheet(
      tabs: ['Văn bản'],
      passages: ['x'],
      initialChildSize: 0.16,
    )));
    await tester.pumpAndSettle();
    // Collapsed panel must sit at the bottom of the 600px viewport, not the top.
    expect(
      tester.getTopLeft(find.text('Kéo lên để đọc đoạn văn')).dy,
      greaterThan(300),
    );
  });

  testWidgets('collapsed to a tiny extent with a tab row does not overflow',
      (tester) async {
    await tester.pumpWidget(_host(BloomPassageSheet(
      tabs: ['Văn bản 1', 'Văn bản 2'],
      passages: ['FIRST DOC', 'SECOND DOC'],
      initialChildSize: 0.12,
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Kéo lên để đọc đoạn văn'), findsOneWidget);
  });
}
