import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';

Finder _decoratedContainer() => find.descendant(
      of: find.byType(FilterTile),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );

void main() {
  testWidgets('shows label + value, taps, pill-shaped surface2 ground',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FilterTile(
          icon: Icons.tune,
          label: 'Ngữ cảnh',
          value: '🌐 General',
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('Ngữ cảnh'), findsOneWidget);
    expect(find.text('🌐 General'), findsOneWidget);
    await tester.tap(find.text('Ngữ cảnh'));
    expect(taps, 1);

    final box = tester.widget<Container>(_decoratedContainer().first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface2);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.pill));

    // Ripple: a fresh transparent Material + InkWell sits above the fill.
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

  testWidgets('renders a chevron_right affordance, not a dropdown caret',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FilterTile(
          icon: Icons.tune,
          label: 'Ngữ cảnh',
          value: 'General',
          onTap: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets(
      'regression: on a BloomScaffold the fill is the surface2 token, not '
      'washed out by the page gradient (decoration in the widget layer)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: BloomScaffold(
        body: Center(
          child: FilterTile(
            icon: Icons.tune,
            label: 'Ngữ cảnh',
            value: 'General',
            onTap: () {},
          ),
        ),
      ),
    ));
    final box = tester.widget<Container>(_decoratedContainer().first);
    expect((box.decoration as BoxDecoration).color, BloomColors.light.surface2);
  });
}
