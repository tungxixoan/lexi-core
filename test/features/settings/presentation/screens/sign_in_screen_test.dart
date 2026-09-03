// test/features/settings/presentation/screens/sign_in_screen_test.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import 'package:lexi_core/features/settings/presentation/providers/auth_notifier.dart';
import 'package:lexi_core/features/settings/presentation/screens/sign_in_screen.dart';

enum _SignInBehavior { hang, throwError }

/// Fake [AuthNotifier] whose [signInWithGoogle] is a spy. It never touches real
/// Firebase: with [_SignInBehavior.hang] the call parks forever (so `_signIn`
/// never advances to the un-fakeable `FirebaseAuth.instance.currentUser` read),
/// with [_SignInBehavior.throwError] it throws to exercise the error branch.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.behavior);

  final _SignInBehavior behavior;
  int signInCount = 0;
  final Completer<void> _hang = Completer<void>();

  @override
  Stream<User?> build() => const Stream<User?>.empty();

  @override
  Future<void> signInWithGoogle() async {
    signInCount++;
    if (behavior == _SignInBehavior.throwError) {
      throw Exception('sign-in failed');
    }
    await _hang.future;
  }
}

Widget _harness(_FakeAuthNotifier auth) {
  final router = GoRouter(
    initialLocation: '/sign-in',
    routes: [
      GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home-stub')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authNotifierProvider.overrideWith(() => auth)],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('renders the leaf mark, title, subtitle and Google pill button',
      (tester) async {
    await tester.pumpWidget(_harness(_FakeAuthNotifier(_SignInBehavior.hang)));
    await tester.pump();

    expect(find.byType(BloomLeafMark), findsOneWidget);
    expect(find.text('LexiCore'), findsOneWidget);
    expect(find.text('Đăng nhập để tiếp tục'), findsOneWidget);
    expect(
      find.widgetWithText(BloomPillButton, 'Đăng nhập với Google'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tapping the button calls signInWithGoogle and shows the spinner',
      (tester) async {
    final auth = _FakeAuthNotifier(_SignInBehavior.hang);
    await tester.pumpWidget(_harness(auth));
    await tester.pump();

    await tester.tap(
      find.widgetWithText(BloomPillButton, 'Đăng nhập với Google'),
    );
    await tester.pump();

    expect(auth.signInCount, 1);
    // `_step` moved to signingIn: the pill button is replaced by the raw
    // spinner, and no error text is shown. The spy call parks on its
    // completer, so `_signIn` never reaches the un-fakeable Firebase read.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.widgetWithText(BloomPillButton, 'Đăng nhập với Google'),
      findsNothing,
    );
    expect(find.text('Đăng nhập thất bại. Thử lại.'), findsNothing);
  });

  testWidgets(
      'a failed sign-in shows the error text in the danger colour and '
      'restores the sign-in button', (tester) async {
    final auth = _FakeAuthNotifier(_SignInBehavior.throwError);
    await tester.pumpWidget(_harness(auth));
    await tester.pump();

    await tester.tap(
      find.widgetWithText(BloomPillButton, 'Đăng nhập với Google'),
    );
    await tester.pump();
    await tester.pump();

    expect(auth.signInCount, 1);

    // `_signIn`'s catch sets `_step = idle` + `_signInError`. The screen has no
    // dedicated "Thử lại" button for a sign-in error (that block only renders
    // for `_migrationError`); the retry affordance is the sign-in button
    // reappearing, since `loading` is false again.
    final errorFinder = find.text('Đăng nhập thất bại. Thử lại.');
    expect(errorFinder, findsOneWidget);
    expect(
      tester.widget<Text>(errorFinder).style?.color,
      BloomColors.light.danger,
    );
    expect(
      find.widgetWithText(BloomPillButton, 'Đăng nhập với Google'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
