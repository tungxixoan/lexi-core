import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_text_field.dart';

void main() {
  testWidgets('accepts input and reports changes', (tester) async {
    String? last;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(hintText: 'Tra từ', onChanged: (v) => last = v),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'resilient');
    expect(last, 'resilient');
    expect(find.text('resilient'), findsOneWidget); // entered text renders
  });

  testWidgets('single-line uses a pill border', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomTextField(hintText: 'x')),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.enabledBorder as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(999));
  });

  testWidgets('forwards focusNode, keyboardType, textInputAction, readOnly',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(
          focusNode: node,
          hintText: 'x',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.search,
          readOnly: true,
        ),
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode, same(node));
    expect(field.keyboardType, TextInputType.emailAddress);
    expect(field.textInputAction, TextInputAction.search);
    expect(field.readOnly, isTrue);
  });

  testWidgets('forwards inputFormatters (a length limit truncates input)',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(
          controller: controller,
          hintText: 'x',
          inputFormatters: [LengthLimitingTextInputFormatter(5)],
        ),
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.inputFormatters, isNotNull);

    await tester.enterText(find.byType(TextField), 'abcdefghij');
    expect(controller.text, 'abcde');
  });

  testWidgets('renders a prefix icon and a suffix widget', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(
          hintText: 'x',
          prefixIcon: Icons.search,
          suffix: const Text('clear'),
        ),
      ),
    ));
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('clear'), findsOneWidget);
  });
}
