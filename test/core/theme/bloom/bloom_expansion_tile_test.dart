import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_expansion_tile.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('collapsed by default: shows title + summary, hides child',
      (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'Chỗ trống (1)',
      summary: 'Chưa trả lời',
      child: Text('BODY'),
    )));
    expect(find.text('Chỗ trống (1)'), findsOneWidget);
    expect(find.text('Chưa trả lời'), findsOneWidget);
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('tapping the header reveals the child', (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'S', child: Text('BODY'),
    )));
    await tester.tap(find.text('T'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('initiallyExpanded: true shows the child immediately',
      (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'S', initiallyExpanded: true, child: Text('BODY'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('answered summary is drawn in sage, unanswered in inkFaint',
      (tester) async {
    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'Đã chọn: on', answered: true, child: SizedBox(),
    )));
    final answered = tester.widget<Text>(find.text('Đã chọn: on'));
    expect(answered.style!.color, BloomColors.light.sage);

    await tester.pumpWidget(_host(const BloomExpansionTile(
      title: 'T', summary: 'Chưa trả lời', child: SizedBox(),
    )));
    final unanswered = tester.widget<Text>(find.text('Chưa trả lời'));
    expect(unanswered.style!.color, BloomColors.light.inkFaint);
  });
}
