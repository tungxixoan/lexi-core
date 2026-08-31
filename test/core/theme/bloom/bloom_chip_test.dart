import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_chip.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('active chip fills with accent', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'General', style: BloomChipStyle.active),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomChip), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.accent);
  });

  testWidgets('topic chip uses sageBg', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'Business', style: BloomChipStyle.topic),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomChip), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sageBg);
  });

  testWidgets('tappable chip paints its fill on an Ink layer (visible ripple)',
      (tester) async {
    await tester.pumpWidget(_host(
      BloomChip(label: 'General', style: BloomChipStyle.active, onTap: () {}),
    ));
    final ink = tester.widget<Ink>(
      find.descendant(of: find.byType(InkWell), matching: find.byType(Ink)),
    );
    expect((ink.decoration as BoxDecoration).color, BloomColors.light.accent);
  });

  testWidgets('BloomCefrPill shows the level on a sage ground', (tester) async {
    await tester.pumpWidget(_host(const BloomCefrPill('B2')));
    expect(find.text('B2'), findsOneWidget);
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCefrPill), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sage);
  });
}
