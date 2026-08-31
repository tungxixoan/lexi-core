import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/search_bar_widget.dart';

Future<Widget> _buildBar({required bool aiEnabled}) async {
  SharedPreferences.setMockInitialValues({'ai_enabled': aiEnabled});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: SearchBarWidget()),
    ),
  );
}

void main() {
  testWidgets('renders the search field and the Khám phá button when AI is on',
      (tester) async {
    await tester.pumpWidget(await _buildBar(aiEnabled: true));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Khám phá'), findsOneWidget);
  });

  testWidgets('hides the Khám phá button when AI is off', (tester) async {
    await tester.pumpWidget(await _buildBar(aiEnabled: false));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Khám phá'), findsNothing);
  });
}
