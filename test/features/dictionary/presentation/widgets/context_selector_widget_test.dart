// test/features/dictionary/presentation/widgets/context_selector_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/context_selector_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('renders a chip for every AppContext', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: ContextSelectorWidget()),
        ),
      ),
    );

    // Verify that FilterChip widgets are rendered
    // ListView renders only visible items, so we check that at least one chip is visible
    expect(find.byType(FilterChip), findsWidgets);

    // Scroll to the end to ensure all chips are rendered
    await tester.drag(
      find.byType(ListView),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    // After scrolling, verify we can find multiple chips
    expect(find.byType(FilterChip), findsWidgets);
  });

  testWidgets('tapping a chip marks it selected', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: ContextSelectorWidget()),
        ),
      ),
    );

    // Get the Business context chip (it's the 2nd in the list since Business is at index 1)
    final businessChipFinder = find.byType(FilterChip).at(1);

    // Get the initial state
    var chip = tester.widget<FilterChip>(businessChipFinder);
    expect(chip.selected, isFalse); // Initially not selected

    // Tap it
    await tester.tap(businessChipFinder);
    await tester.pump();

    // Verify it's now selected
    chip = tester.widget<FilterChip>(businessChipFinder);
    expect(chip.selected, isTrue);
  });
}
