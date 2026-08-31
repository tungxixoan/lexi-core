import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_card.dart';

void main() {
  testWidgets('default card: surface ground, border outline, md radius',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(child: Text('x'))),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCard), matching: find.byType(Container)).first,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface);
    expect((deco.border as Border).top.color, BloomColors.light.border);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.md));
  });

  testWidgets('selected card uses accent border + surface3', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(selected: true, child: Text('x'))),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCard), matching: find.byType(Container)).first,
    );
    final deco = box.decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BloomColors.light.accent);
    expect(deco.color, BloomColors.light.surface3);
  });

  testWidgets('onTap makes it tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: BloomCard(onTap: () => taps++, child: const Text('x'))),
    ));
    await tester.tap(find.text('x'));
    expect(taps, 1);
  });

  testWidgets('tappable card paints its fill on an Ink layer (visible ripple)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: BloomCard(onTap: () {}, child: const Text('x'))),
    ));
    final ink = tester.widget<Ink>(
      find.descendant(of: find.byType(InkWell), matching: find.byType(Ink)),
    );
    final deco = ink.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.md));
  });

  testWidgets('non-interactive card stays a plain Container (no InkWell)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(child: Text('x'))),
    ));
    expect(
      find.descendant(of: find.byType(BloomCard), matching: find.byType(InkWell)),
      findsNothing,
    );
  });
}
