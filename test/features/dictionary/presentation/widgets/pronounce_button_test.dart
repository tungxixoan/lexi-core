import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/pronounce_button.dart';

void main() {
  testWidgets('fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: PronounceButton(onPressed: () => taps++)),
    ));
    await tester.tap(find.byType(PronounceButton));
    expect(taps, 1);
  });
}
