import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_word_seek_bar.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders a Slider with the given value and max, plus the label', (tester) async {
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 2, max: 5, label: 'Tua theo từ', onChanged: (_) {},
    )));
    expect(find.text('Tua theo từ'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 2);
    expect(slider.max, 5);
  });

  testWidgets('enabled: false gives the Slider a null onChanged', (tester) async {
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 0, max: 3, enabled: false, onChanged: (_) {},
    )));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('dragging reports onChanged and onChangeEnd', (tester) async {
    double? changed;
    double? ended;
    await tester.pumpWidget(_host(BloomWordSeekBar(
      value: 0, max: 4,
      onChanged: (v) => changed = v,
      onChangeEnd: (v) => ended = v,
    )));
    await tester.drag(find.byType(Slider), const Offset(200, 0));
    expect(changed, isNotNull);
    expect(ended, isNotNull);
  });
}
