// test/core/theme/bloom_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

void main() {
  test('light and dark accents match bloom.css verbatim', () {
    expect(BloomColors.light.accent, const Color(0xFFC9587A));
    expect(BloomColors.dark.accent, const Color(0xFFE693AC));
    expect(BloomColors.light.border, const Color(0xFFEFDDE3));
    expect(BloomColors.dark.surface, const Color(0xFF2A2028));
  });

  test('lerp(0) is this, lerp(1) is other', () {
    final mid = BloomColors.light.lerp(BloomColors.dark, 1.0);
    expect(mid.accent, BloomColors.dark.accent);
    expect(BloomColors.light.lerp(BloomColors.dark, 0.0).accent,
        BloomColors.light.accent);
  });

  testWidgets('context.bloom resolves the extension', (tester) async {
    late BloomColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [BloomColors.light]),
      home: Builder(builder: (context) {
        seen = context.bloom;
        return const SizedBox();
      }),
    ));
    expect(seen.accent, BloomColors.light.accent);
  });

  testWidgets('context.bloom falls back to light when no extension present',
      (tester) async {
    late BloomColors seen;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        seen = context.bloom;
        return const SizedBox();
      }),
    ));
    expect(seen.accent, BloomColors.light.accent);
  });

  group('layout tokens', () {
    test('radii match the constrained set', () {
      expect(BloomRadii.sm, 10);
      expect(BloomRadii.md, 16);
      expect(BloomRadii.lg, 20);
      expect(BloomRadii.pill, 999);
    });

    test('pageBackground is a sweep of two radial layers over surface', () {
      final g = BloomGradients.pageBackground(BloomColors.light);
      expect(g, isA<Gradient>());
    });

    test('progressFill runs sage -> accent', () {
      final g =
          BloomGradients.progressFill(BloomColors.light) as LinearGradient;
      expect(g.colors.first, BloomColors.light.sage);
      expect(g.colors.last, BloomColors.light.accent);
    });

    test('warm shadow is darker in dark mode', () {
      expect(BloomShadows.warm(true).first.color.a,
          greaterThan(BloomShadows.warm(false).first.color.a));
    });
  });
}
