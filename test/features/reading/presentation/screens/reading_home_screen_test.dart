import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_home_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHome({
  required UserSettingsState settings,
  required List<dynamic> vocabItems,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ReadingHomeScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
      vocabBankProvider.overrideWith((_) => vocabItems.cast()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
      vocabItems: List.filled(10, null),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows low vocab message when fewer than 5 words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.filled(3, null),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 từ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI enabled and >= 5 vocab words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.filled(5, null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });
}
