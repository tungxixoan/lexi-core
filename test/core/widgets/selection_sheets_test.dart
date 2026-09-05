import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_pill_button.dart';
import 'package:lexi_core/core/widgets/selection_sheets.dart';

void main() {
  testWidgets('single-select returns the picked option', (tester) async {
    SelectOption<String>? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              picked = await showSingleSelectSheet<String>(
                context: context,
                title: 'Ngữ cảnh',
                options: const [
                  SelectOption(value: 'a', label: 'General'),
                  SelectOption(value: 'b', label: 'Business'),
                ],
                selected: 'a',
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business'));
    await tester.pumpAndSettle();
    expect(picked?.value, 'b');
  });

  testWidgets(
      'multi-select confirm returns the checked values via BloomPillButton',
      (tester) async {
    Set<String>? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showMultiSelectSheet<String>(
                context: context,
                title: 'Chủ đề',
                options: const [
                  SelectOption(value: 'a', label: 'General'),
                  SelectOption(value: 'b', label: 'Business'),
                ],
                initialSelected: const {},
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business'));
    await tester.pumpAndSettle();

    // Confirm button is a BloomPillButton now.
    expect(find.byType(BloomPillButton), findsWidgets);
    await tester.tap(find.text('Áp dụng (1)'));
    await tester.pumpAndSettle();
    expect(result, {'b'});
  });

  testWidgets('multi-select "Bỏ chọn hết" clears the selection',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              await showMultiSelectSheet<String>(
                context: context,
                title: 'Chủ đề',
                options: const [
                  SelectOption(value: 'a', label: 'General'),
                  SelectOption(value: 'b', label: 'Business'),
                ],
                initialSelected: const {'a', 'b'},
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Áp dụng (2)'), findsOneWidget);
    await tester.tap(find.text('Bỏ chọn hết'));
    await tester.pumpAndSettle();
    expect(find.text('Xem tất cả'), findsOneWidget);
  });
}
