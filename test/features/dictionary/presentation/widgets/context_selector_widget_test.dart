// test/features/dictionary/presentation/widgets/context_selector_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/context_selector_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildWidget() => ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          home: Scaffold(body: ContextSelectorWidget()),
        ),
      );

  testWidgets('shows the current context as a tappable tile', (tester) async {
    await tester.pumpWidget(buildWidget());

    expect(find.text('Ngữ cảnh'), findsOneWidget);
    expect(find.textContaining(AppContext.general.label), findsOneWidget);
  });

  testWidgets('tapping the tile opens a bottom sheet listing contexts',
      (tester) async {
    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Ngữ cảnh'));
    await tester.pumpAndSettle();

    // The sheet's list is lazily built, so only assert on entries near the
    // top plus one reached by scrolling — not every AppContext value.
    expect(find.textContaining(AppContext.general.label), findsWidgets);
    expect(find.textContaining(AppContext.business.label), findsWidgets);
    await tester.dragUntilVisible(
      find.textContaining(AppContext.socialCasual.label),
      find.byType(ListView),
      const Offset(0, -50),
    );
    expect(find.textContaining(AppContext.socialCasual.label), findsWidgets);
  });

  testWidgets('picking a context updates the displayed value', (tester) async {
    await tester.pumpWidget(buildWidget());

    await tester.tap(find.text('Ngữ cảnh'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining(AppContext.business.label).last);
    await tester.pumpAndSettle();

    expect(find.textContaining(AppContext.business.label), findsOneWidget);
  });
}
