import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_mc_option.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

Finder _decoratedContainer() => find.descendant(
      of: find.byType(BloomMcOption),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );

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
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect(
        (box.decoration as BoxDecoration).color, BloomColors.light.successBg);
  });

  testWidgets('wrong state paints a danger ground; selected uses surface3',
      (tester) async {
    await tester.pumpWidget(_host(Column(children: const [
      BloomMcOption(label: 'w', onTap: null, state: BloomMcState.wrong),
      BloomMcOption(label: 's', onTap: null, state: BloomMcState.selected),
    ])));
    final boxes = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(BloomMcOption),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration is BoxDecoration,
            ),
          ),
        )
        .toList();
    expect((boxes.first.decoration as BoxDecoration).color,
        BloomColors.light.dangerBg);
    expect((boxes.last.decoration as BoxDecoration).color,
        BloomColors.light.surface3);
  });

  testWidgets(
      'interactive option paints its fill in the widget layer with a '
      'real ripple above it', (tester) async {
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'x', onTap: () {}),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.surface2);
    final material = tester.widget<Material>(
      find.descendant(
          of: _decoratedContainer(), matching: find.byType(Material)),
    );
    expect(material.color, Colors.transparent);
    expect(
      find.descendant(
          of: find.byType(Material), matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets(
      'regression: interactive option on a BloomScaffold still paints '
      'its ground, not the page gradient', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BloomScaffold(
        body: Center(child: BloomMcOption(label: 'x', onTap: () {})),
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.surface2);
  });

  testWidgets('label text carries a real style (webScaled wrapper present)',
      (tester) async {
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'apologized', onTap: () {}),
    ));
    final txt = tester.widget<Text>(find.text('apologized'));
    // kIsWeb is false under `flutter test`, so webScaled is a no-op → 15.
    expect(txt.style?.fontSize, 15);
    expect(txt.style?.color, BloomColors.light.ink);
  });

  testWidgets('renders a leading label when given', (tester) async {
    await tester.pumpWidget(_host(
      BloomMcOption(label: 'x', onTap: () {}, leading: 'A'),
    ));
    expect(find.text('A'), findsOneWidget);
  });
}
