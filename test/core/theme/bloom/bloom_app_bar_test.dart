import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_app_bar.dart';

void main() {
  testWidgets('shows the title and an 800-weight style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(appBar: BloomAppBar(title: 'Tra từ'), body: SizedBox()),
    ));
    expect(find.text('Tra từ'), findsOneWidget);
    final txt = tester.widget<Text>(find.text('Tra từ'));
    expect(txt.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('default (automaticallyImplyLeading: true) shows a back button '
      'when the route can pop', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      navigatorKey: key,
      home: const Scaffold(body: Center(child: Text('home'))),
    ));
    key.currentState!.push(MaterialPageRoute(
      builder: (_) => const Scaffold(
        appBar: BloomAppBar(title: 'Detail'),
        body: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('automaticallyImplyLeading: false shows NO back button even when '
      'the route can pop', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      navigatorKey: key,
      home: const Scaffold(body: Center(child: Text('home'))),
    ));
    key.currentState!.push(MaterialPageRoute(
      builder: (_) => const Scaffold(
        appBar: BloomAppBar(title: 'Detail', automaticallyImplyLeading: false),
        body: SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('BloomIconButton fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomIconButton(icon: Icons.settings, onPressed: () => taps++),
      ),
    ));
    await tester.tap(find.byIcon(Icons.settings));
    expect(taps, 1);
  });
}
