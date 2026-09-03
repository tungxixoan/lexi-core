import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_switch.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders title + subtitle and reflects value', (tester) async {
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'Nhắc nhở hàng ngày',
      subtitle: 'Thông báo khi có từ cần ôn',
      value: true,
      onChanged: (_) {},
    )));
    expect(find.text('Nhắc nhở hàng ngày'), findsOneWidget);
    expect(find.text('Thông báo khi có từ cần ôn'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('tapping the row toggles the value', (tester) async {
    bool? got;
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'X',
      value: false,
      onChanged: (v) => got = v,
    )));
    await tester.tap(find.text('X'));
    expect(got, isTrue);
  });

  testWidgets('flipping the Switch reports the new value', (tester) async {
    bool? got;
    await tester.pumpWidget(_host(BloomSwitch(
      title: 'X',
      value: true,
      onChanged: (v) => got = v,
    )));
    await tester.tap(find.byType(Switch));
    expect(got, isFalse);
  });

  testWidgets('subtitle omitted when null', (tester) async {
    await tester.pumpWidget(
        _host(BloomSwitch(title: 'Only', value: false, onChanged: (_) {})));
    expect(find.byType(Text), findsOneWidget);
  });
}
