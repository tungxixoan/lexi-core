import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_mc_option.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('neutral option is tappable and reports the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'apologized', onTap: () => taps++),
    ));
    await tester.tap(find.text('apologized'));
    expect(taps, 1);
  });

  testWidgets('null onTap disables the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      const BloomMcOption(label: 'x', onTap: null),
    ));
    await tester.tap(find.text('x'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('correct state paints a success ground', (tester) async {
    await tester.pumpWidget(_host(
      const BloomMcOption(label: 'x', onTap: null, state: BloomMcState.correct),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomMcOption), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.successBg);
  });

  testWidgets('wrong state paints a danger ground; selected uses surface3',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: const [
      BloomMcOption(label: 'w', onTap: null, state: BloomMcState.wrong),
      BloomMcOption(label: 's', onTap: null, state: BloomMcState.selected),
    ])));
    final boxes = tester.widgetList<Container>(
      find.descendant(of: find.byType(BloomMcOption), matching: find.byType(Container)),
    ).toList();
    expect((boxes.first.decoration as BoxDecoration).color, BloomColors.light.dangerBg);
  });

  testWidgets('renders a leading label when given', (tester) async {
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'x', onTap: () {}, leading: 'A'),
    ));
    expect(find.text('A'), findsOneWidget);
  });
}
