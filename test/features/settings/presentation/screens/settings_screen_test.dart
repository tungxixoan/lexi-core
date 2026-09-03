// test/features/settings/presentation/screens/settings_screen_test.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/settings/presentation/providers/auth_notifier.dart';
import 'package:lexi_core/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal [User] stand-in — the screen only reads displayName/email/photoURL.
class _FakeUser implements User {
  _FakeUser({this.displayName, this.email});

  @override
  final String? displayName;
  @override
  final String? email;
  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);
  final User? _user;
  int signOutCount = 0;

  @override
  Stream<User?> build() => Stream.value(_user);

  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

Future<ProviderContainer> _makeContainer({
  Map<String, Object> prefs = const {},
  User? user,
  _FakeAuthNotifier? authNotifier,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sp),
    currentUidProvider.overrideWithValue(null),
    authNotifierProvider
        .overrideWith(() => authNotifier ?? _FakeAuthNotifier(user)),
  ]);
}

Future<void> _pumpScreen(
    WidgetTester tester, ProviderContainer container) async {
  // Tall surface so every section card is built (ListView only instantiates
  // children within the viewport + cache extent).
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const SettingsScreen(),
      ),
    ),
  );
  // Flush the auth stream's first event so `authAsync` lands on AsyncData
  // (and the loading LinearProgressIndicator is gone).
  await tester.pump(Duration.zero);
}

void main() {
  testWidgets('renders all 5 section headers', (tester) async {
    final container = await _makeContainer();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('TÀI KHOẢN'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('HỌC TẬP'), findsOneWidget);
    expect(find.text('GIAO DIỆN'), findsOneWidget);
    expect(find.text('THÔNG BÁO'), findsOneWidget);
  });

  testWidgets('no "Bật AI" toggle; Provider/Model/API Key rows always visible',
      (tester) async {
    final container = await _makeContainer();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('Bật AI'), findsNothing);
    expect(find.byType(BloomSegmented<AiProvider>), findsOneWidget);
    expect(find.widgetWithText(FilterTile, 'Model'), findsOneWidget);
    expect(find.widgetWithText(FilterTile, 'API Key'), findsOneWidget);
    // No key stored → "Chưa cài đặt".
    expect(find.text('Chưa cài đặt'), findsOneWidget);
  });

  testWidgets('Giao diện segmented reflects themePreference and updates it',
      (tester) async {
    final container =
        await _makeContainer(prefs: {'theme_preference': 'light'});
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    final segmented = tester.widget<BloomSegmented<ThemeMode>>(
        find.byType(BloomSegmented<ThemeMode>));
    expect(segmented.selected, ThemeMode.light);

    await tester.ensureVisible(find.text('Tối'));
    await tester.pump();
    await tester.tap(find.text('Tối'));
    await tester.pump();

    expect(container.read(userSettingsNotifierProvider).themePreference,
        ThemeMode.dark);
  });

  testWidgets('tapping a different Provider segment calls setActiveProvider',
      (tester) async {
    final container = await _makeContainer();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(container.read(userSettingsNotifierProvider).activeProvider,
        AiProvider.gemini);

    await tester.ensureVisible(find.text(AiProvider.groq.label));
    await tester.pump();
    await tester.tap(find.text(AiProvider.groq.label));
    await tester.pump();

    expect(container.read(userSettingsNotifierProvider).activeProvider,
        AiProvider.groq);
  });

  testWidgets('signed-in: shows name, email and a working Đăng xuất button',
      (tester) async {
    final auth = _FakeAuthNotifier(
      _FakeUser(displayName: 'Test User', email: 'test@example.com'),
    );
    final container = await _makeContainer(authNotifier: auth);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);

    final signOutBtn = find.widgetWithText(BloomPillButton, 'Đăng xuất');
    expect(signOutBtn, findsOneWidget);

    await tester.tap(signOutBtn);
    await tester.pump();
    expect(auth.signOutCount, 1);
  });

  testWidgets('signed-out: Tài khoản card shows no account row',
      (tester) async {
    final container = await _makeContainer(user: null);
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('TÀI KHOẢN'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsNothing);
  });
}
