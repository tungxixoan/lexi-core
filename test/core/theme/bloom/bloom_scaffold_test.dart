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
