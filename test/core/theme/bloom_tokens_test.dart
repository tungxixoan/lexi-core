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
}
