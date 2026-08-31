import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_progress_bar.dart';

void main() {
  testWidgets('clamps value and fills a fraction of the track', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SizedBox(width: 200, child: BloomProgressBar(value: 0.5)),
      ),
    ));
    final fill = tester.getSize(find.byKey(const ValueKey('bloom-progress-fill')));
    final track = tester.getSize(find.byKey(const ValueKey('bloom-progress-track')));
    expect(fill.width, closeTo(track.width * 0.5, 1.0));
    // The fill must span the full track height (6px), not collapse to zero.
    expect(fill.height, track.height);
    expect(fill.height, 6);
  });

  testWidgets('value above 1 is clamped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SizedBox(width: 200, child: BloomProgressBar(value: 5)),
      ),
    ));
    final fill = tester.getSize(find.byKey(const ValueKey('bloom-progress-fill')));
    final track = tester.getSize(find.byKey(const ValueKey('bloom-progress-track')));
    expect(fill.width, closeTo(track.width, 1.0));
  });
}
