import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/widgets/ai_key_missing_card.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/part5_home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

UserSettingsState _settings({bool aiAvailable = true}) =>
    UserSettingsState.defaults.copyWith(
      providerConfigs: {
        AiProvider.gemini: ProviderConfig(
          apiKeyCiphertext: aiAvailable ? 'ck' : null,
          model: 'gemini-2.5-flash',
        ),
      },
    );

Widget _buildHome({required UserSettingsState settings}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (ctx, state) => const Part5HomeScreen()),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('Settings stub')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider
          .overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the missing-API-key card when no key is set',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(aiAvailable: false),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AiKeyMissingCard), findsOneWidget);
    expect(find.textContaining('Chưa có API key cho nhà cung cấp AI'),
        findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI is enabled (no vocab gate)',
      (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, context and difficulty pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: _settings(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Độ khó'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget); // no volumes selected yet
  });
}
