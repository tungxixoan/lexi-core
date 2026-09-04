import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom_speed_slider.dart';

Widget _host(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('renders the 0.5–2.0 slider and the ×N readout', (tester) async {
    await tester
        .pumpWidget(_host(BloomSpeedSlider(value: 1.0, onChanged: (_) {})));
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0.5);
    expect(slider.max, 2.0);
    expect(slider.value, 1.0);
    expect(find.text('1.00×'), findsOneWidget);
    expect(find.text('Tốc độ'), findsOneWidget);
  });

  testWidgets('dragging reports onChanged', (tester) async {
    double? got;
    await tester.pumpWidget(
        _host(BloomSpeedSlider(value: 1.0, onChanged: (v) => got = v)));
    await tester.drag(find.byType(Slider), const Offset(60, 0));
    expect(got, isNotNull);
    expect(got, greaterThan(1.0));
  });

  testWidgets('clamps an out-of-range value into the track', (tester) async {
    await tester
        .pumpWidget(_host(BloomSpeedSlider(value: 5.0, onChanged: (_) {})));
    expect(tester.widget<Slider>(find.byType(Slider)).value, 2.0);
  });
}
