import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_card.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';

Finder _decoratedContainer() => find.descendant(
      of: find.byType(BloomCard),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );

void main() {
  testWidgets('default card: surface ground, border outline, md radius',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(child: Text('x'))),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
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
    final box = tester.widget<Container>(_decoratedContainer().first);
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

  testWidgets('tappable card paints its fill in the widget layer (Container '
      'decoration) with a real ripple above it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: BloomCard(onTap: () {}, child: const Text('x'))),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.md));
    // Ripple comes from a fresh transparent Material + InkWell above the fill.
    final material = tester.widget<Material>(
      find.descendant(of: _decoratedContainer(), matching: find.byType(Material)),
    );
    expect(material.color, Colors.transparent);
    expect(
      find.descendant(of: find.byType(Material), matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets('selected + tappable card keeps its accent border visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomCard(selected: true, onTap: () {}, child: const Text('x')),
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    final deco = box.decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BloomColors.light.accent);
    expect(deco.color, BloomColors.light.surface3);
  });

  testWidgets('regression: tappable card on a BloomScaffold still paints '
      'surface, not the page gradient', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BloomScaffold(
        body: Center(child: BloomCard(onTap: () {}, child: const Text('x'))),
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.surface);
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
