import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';

void main() {
  testWidgets('renders body over a gradient ground', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const BloomScaffold(body: Text('hello')),
    ));
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('gradient ground fills the viewport, not just the body child',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const BloomScaffold(body: Text('x')),
    ));

    final gradientBox = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient != null,
    );
    expect(gradientBox, findsOneWidget);

    final groundSize = tester.getSize(gradientBox);
    final scaffoldSize = tester.getSize(find.byType(Scaffold));
    // Pre-fix the wash sized to the one-line text child (~20px); it must now
    // span the whole scaffold body instead.
    expect(groundSize.height, greaterThan(100));
    expect(groundSize.height, scaffoldSize.height);
  });

  testWidgets('passes through appBar and bottom nav slots', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: BloomScaffold(
        appBar: AppBar(title: const Text('T')),
        body: const SizedBox(),
        bottomNavigationBar: const Text('nav'),
      ),
    ));
    expect(find.text('T'), findsOneWidget);
    expect(find.text('nav'), findsOneWidget);
  });
}
