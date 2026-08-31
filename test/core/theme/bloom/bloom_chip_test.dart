import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_chip.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

Finder _decoratedContainer() => find.descendant(
      of: find.byType(BloomChip),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );

void main() {
  testWidgets('active chip fills with accent', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'General', style: BloomChipStyle.active),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.accent);
  });

  testWidgets('topic chip uses sageBg', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'Business', style: BloomChipStyle.topic),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sageBg);
  });

  testWidgets(
      'tappable chip paints its fill in the widget layer with a real ripple '
      'above it', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      BloomChip(
        label: 'General',
        style: BloomChipStyle.active,
        onTap: () => taps++,
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.accent);

    final material = tester.widget<Material>(
      find.descendant(
          of: _decoratedContainer(), matching: find.byType(Material)),
    );
    expect(material.color, Colors.transparent);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('General'));
    expect(taps, 1);
  });

  testWidgets(
      'regression: tappable chip on a BloomScaffold still paints its token '
      'ground, not the page gradient', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BloomScaffold(
        body: Center(
          child: BloomChip(
            label: 'General',
            style: BloomChipStyle.active,
            onTap: () {},
          ),
        ),
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.accent);
  });

  testWidgets('BloomCefrPill shows the level on a sage ground', (tester) async {
    await tester.pumpWidget(_host(const BloomCefrPill('B2')));
    expect(find.text('B2'), findsOneWidget);
    final box = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(BloomCefrPill), matching: find.byType(Container))
          .first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sage);
  });
}
