import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/router/app_router.dart';

void main() {
  group('authRedirectDecision', () {
    test('before the auth stream resolves, stays on /splash', () {
      expect(
        authRedirectDecision(matchedLocation: '/splash', hasResolved: false, signedIn: false),
        isNull,
      );
    });

    test('before the auth stream resolves, redirects any other location to /splash', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: false, signedIn: false),
        '/splash',
      );
    });

    test('resolved + signed out + already on /sign-in stays put', () {
      expect(
        authRedirectDecision(matchedLocation: '/sign-in', hasResolved: true, signedIn: false),
        isNull,
      );
    });

    test('resolved + signed out + anywhere else redirects to /sign-in', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: true, signedIn: false),
        '/sign-in',
      );
    });

    test('resolved + signed in + on /splash redirects home', () {
      expect(
        authRedirectDecision(matchedLocation: '/splash', hasResolved: true, signedIn: true),
        '/',
      );
    });

    test('resolved + signed in + on /sign-in redirects home', () {
      expect(
        authRedirectDecision(matchedLocation: '/sign-in', hasResolved: true, signedIn: true),
        '/',
      );
    });

    test('resolved + signed in + anywhere else stays put (no redirect loop)', () {
      expect(
        authRedirectDecision(matchedLocation: '/vocab', hasResolved: true, signedIn: true),
        isNull,
      );
    });
  });
}
