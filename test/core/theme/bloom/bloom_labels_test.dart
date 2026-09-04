// test/core/theme/bloom/bloom_labels_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_labels.dart';

void main() {
  testWidgets('section header is uppercased, spaced, soft', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomSectionHeader('Tài khoản')),
    ));
    final txt = tester.widget<Text>(find.byType(Text));
    expect(txt.data, 'TÀI KHOẢN');
    expect(txt.style?.letterSpacing, greaterThan(0));
    expect(txt.style?.color, BloomColors.light.inkSoft);
  });

  testWidgets('leaf mark paints a gradient teardrop', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomLeafMark()),
    ));
    final box = tester.widget<Container>(find.byType(Container).first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.gradient, isNotNull);
    expect(deco.borderRadius, isNotNull);
  });
}
