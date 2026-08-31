import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';

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
    final box = tester.widget<Ink>(
      find
          .descendant(of: find.byType(FilterTile), matching: find.byType(Ink))
          .first,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface2);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.pill));

    // Ripple: an interactive tile paints its fill on an Ink layer inside the
    // InkWell, so the splash is visible.
    expect(
      find.descendant(of: find.byType(InkWell), matching: find.byType(Ink)),
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
}
