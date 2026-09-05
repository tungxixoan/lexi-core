import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_pill_button.dart';

Widget _host(Widget child) => MaterialApp(
    theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('primary: accent fill, pill shape, fires onPressed',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      BloomPillButton(label: 'Lưu từ', onPressed: () => taps++),
    ));
    await tester.tap(find.text('Lưu từ'));
    expect(taps, 1);
    final material = tester.widget<Material>(
      find
          .descendant(
              of: find.byType(BloomPillButton), matching: find.byType(Material))
          .last,
    );
    expect(material.color, BloomColors.light.accent);
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('null onPressed disables it', (tester) async {
    await tester.pumpWidget(_host(
      const BloomPillButton(label: 'X', onPressed: null),
    ));
    expect(tester.widget<TextButton>(find.byType(TextButton)).enabled, isFalse);
  });

  testWidgets('danger variant tints text/border with danger', (tester) async {
    await tester.pumpWidget(_host(
      BloomPillButton(
          label: 'Xoá', onPressed: () {}, variant: BloomButtonVariant.danger),
    ));
    final txt = tester.widget<Text>(find.text('Xoá'));
    expect(txt.style?.color, BloomColors.light.danger);
  });

  testWidgets('disabled: label text renders dimmed', (tester) async {
    await tester.pumpWidget(_host(
      const BloomPillButton(
          label: 'X', onPressed: null, variant: BloomButtonVariant.link),
    ));
    final txt = tester.widget<Text>(find.text('X'));
    expect(txt.style?.color, BloomColors.light.accent.withValues(alpha: 0.5));
  });
}
