import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

void main() {
  test('light theme carries the Bloom extension and accent as primary', () {
    final t = AppTheme.light;
    final bloom = t.extension<BloomColors>();
    expect(bloom, isNotNull);
    expect(bloom!.accent, BloomColors.light.accent);
    expect(t.colorScheme.primary, BloomColors.light.accent);
    expect(t.colorScheme.error, BloomColors.light.danger);
  });

  test('dark theme carries the dark Bloom extension', () {
    expect(AppTheme.dark.extension<BloomColors>()!.accent, BloomColors.dark.accent);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('text theme uses Be Vietnam Pro', () {
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
    expect(AppTheme.light.textTheme.titleLarge?.fontWeight, FontWeight.w800);
  });
}
