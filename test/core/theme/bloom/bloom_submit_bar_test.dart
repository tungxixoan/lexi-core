import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('shows "Đã trả lời N/M câu" and a Nộp bài button',
      (tester) async {
    await tester.pumpWidget(
        _host(BloomSubmitBar(answered: 3, total: 12, onSubmit: () {})));
    expect(find.text('Đã trả lời 3/12 câu'), findsOneWidget);
    expect(find.widgetWithText(BloomPillButton, 'Nộp bài'), findsOneWidget);
  });

  testWidgets('null onSubmit disables the button', (tester) async {
    await tester.pumpWidget(
        _host(const BloomSubmitBar(answered: 0, total: 5, onSubmit: null)));
    expect(
      tester
          .widget<BloomPillButton>(
              find.widgetWithText(BloomPillButton, 'Nộp bài'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('tapping the button fires onSubmit', (tester) async {
    var hits = 0;
    await tester.pumpWidget(
        _host(BloomSubmitBar(answered: 5, total: 5, onSubmit: () => hits++)));
    await tester.tap(find.text('Nộp bài'));
    expect(hits, 1);
  });
}
