import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../features/settings/presentation/screens/sign_in_screen.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_hub_screen.dart';
import '../../features/practice/presentation/screens/practice_home_screen.dart';
import '../../features/practice/presentation/screens/practice_session_screen.dart';
import '../../features/practice/presentation/screens/progress_screen.dart';
import '../../features/practice/presentation/screens/session_result_screen.dart';
import '../../features/practice/domain/entities/exercise_result.dart';
import '../../features/word_radar/presentation/screens/word_radar_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/reading/presentation/screens/reading_home_screen.dart';
import '../../features/reading/presentation/screens/reading_session_screen.dart';
import '../../features/reading/presentation/screens/reading_result_screen.dart';
import '../../features/reading/presentation/providers/reading_practice_provider.dart';
import '../../features/reading/presentation/screens/reading_hub_screen.dart';
import '../../features/reading/presentation/screens/part5_home_screen.dart';
import '../../features/reading/presentation/screens/part5_session_screen.dart';
import '../../features/reading/presentation/screens/part5_result_screen.dart';
import '../../features/reading/presentation/providers/part5_practice_provider.dart';
import '../../features/reading/presentation/screens/part6_home_screen.dart';
import '../../features/reading/presentation/screens/part6_session_screen.dart';
import '../../features/reading/presentation/screens/part6_result_screen.dart';
import '../../features/reading/presentation/providers/part6_practice_provider.dart';
import '../../features/reading/presentation/screens/part7_home_screen.dart';
import '../../features/reading/presentation/screens/part7_session_screen.dart';
import '../../features/reading/presentation/screens/part7_result_screen.dart';
import '../../features/reading/presentation/providers/part7_practice_provider.dart';
import '../../features/listening/presentation/screens/listening_home_screen.dart';
import '../../features/listening/presentation/screens/dictation_home_screen.dart';
import '../../features/listening/presentation/screens/dictation_session_screen.dart';
import '../../features/listening/presentation/screens/dictation_result_screen.dart';
import '../../features/listening/presentation/providers/dictation_practice_provider.dart';
import '../../features/listening/presentation/screens/comprehension_home_screen.dart';
import '../../features/listening/presentation/screens/comprehension_session_screen.dart';
import '../../features/listening/presentation/screens/comprehension_result_screen.dart';
import '../../features/listening/presentation/providers/listening_comprehension_provider.dart';

/// Pure redirect decision, extracted so it's unit-testable without a full
/// widget tree or a faked FirebaseAuth — see test/core/router/auth_redirect_test.dart.
/// Returns the path to redirect to, or null to stay on [matchedLocation].
String? authRedirectDecision({
  required String matchedLocation,
  required bool hasResolved,
  required bool signedIn,
}) {
  if (!hasResolved) {
    return matchedLocation == '/splash' ? null : '/splash';
  }
  if (!signedIn) {
    return matchedLocation == '/sign-in' ? null : '/sign-in';
  }
  // Signed in: /splash auto-proceeds to home. /sign-in does NOT — the
  // sign-in screen itself navigates away only once its post-sign-in
  // migration step has genuinely settled (see sign_in_screen.dart), so a
  // migration failure can show a real error + retry instead of being
  // raced away by this redirect.
  if (matchedLocation == '/splash') return '/';
  return null;
}

/// Bridges Firebase's async auth-state stream into something GoRouter's
/// `refreshListenable` can react to, and tracks whether the stream has
/// emitted at least once — until it has, [authRedirectDecision] can't yet
/// tell whether the user is signed in, so it must not redirect prematurely
/// (which would otherwise flash the sign-in screen for an already-
/// authenticated user whose session Firebase hasn't finished restoring yet).
class _AuthRefreshStream extends ChangeNotifier {
  _AuthRefreshStream() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      hasResolved = true;
      notifyListeners();
    });
  }

  bool hasResolved = false;
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Shown at app launch while Firebase Auth resolves whether a session
/// already exists. For an already-authenticated returning user, `/splash`
/// auto-redirects straight to `/` (see [authRedirectDecision]) without ever
/// visiting `/sign-in` — so this is the ONLY reachable place to run
/// AiSettingsSyncService.bootstrapSync on every normal app launch, not just
/// right after an interactive sign-in. Fire-and-forget: the fetched
/// settings land in UserSettingsNotifier's state reactively, so any screen
/// already watching it updates itself once the merge completes; this must
/// not block the redirect the way sign_in_screen.dart's own bootstrapSync
/// call blocks navigation there (that one has a real reason to wait — see
/// its own comment).
/// Waits for FirebaseAuth to resolve its current user (falling back to the
/// first authStateChanges() event when currentUser isn't populated
/// synchronously yet, as on Flutter Web) rather than assuming a
/// synchronous null means signed-out.
class _SplashScreen extends ConsumerStatefulWidget {
  const _SplashScreen();

  @override
  ConsumerState<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Capture both provider reads synchronously, before any await — ref
    // must not be touched after this widget could have been disposed.
    final service = ref.read(aiSettingsSyncServiceProvider);
    final notifier = ref.read(userSettingsNotifierProvider.notifier);
    unawaited(() async {
      // On Flutter Web, FirebaseAuth.instance.currentUser stays null until
      // the JS SDK finishes restoring the session from IndexedDB — reading
      // it synchronously here would silently skip bootstrapSync for a
      // returning web user (mobile seeds currentUser synchronously before
      // runApp, so this only matters on web, but web is a live deployed
      // surface until the domain cutover — see CLAUDE.md). Falling back to
      // the first authStateChanges() event waits for that resolution
      // instead of guessing null.
      final user = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance.authStateChanges().first;
      if (user != null) await service.bootstrapSync(user.uid, notifier);
    }());
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

final _authRefreshStream = _AuthRefreshStream();

final appRouter = GoRouter(
  initialLocation: '/splash',
  refreshListenable: _authRefreshStream,
  redirect: (context, state) => authRedirectDecision(
    matchedLocation: state.matchedLocation,
    hasResolved: _authRefreshStream.hasResolved,
    signedIn: FirebaseAuth.instance.currentUser != null,
  ),
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const _SplashScreen(),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LookupScreen()),
        GoRoute(
          path: '/vocab',
          builder: (context, state) => const VocabBankScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) => VocabDetailScreen(
                id: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/practice',
          builder: (context, state) => const PracticeHubScreen(),
          routes: [
            GoRoute(
              path: 'vocab',
              builder: (context, state) => const PracticeHomeScreen(),
            ),
            GoRoute(
              path: 'progress',
              builder: (context, state) => const ProgressScreen(),
            ),
            GoRoute(
              path: 'session',
              builder: (context, state) => PracticeSessionScreen(
                config: state.extra as SessionConfig,
              ),
              routes: [
                GoRoute(
                  path: 'result',
                  builder: (context, state) => SessionResultScreen(
                    result: state.extra as SessionResult,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'radar',
              builder: (context, state) => const WordRadarScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/reading',
          builder: (context, state) => const ReadingHubScreen(),
          routes: [
            GoRoute(
              path: 'bilingual',
              builder: (context, state) => const ReadingHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const ReadingSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! ReadingSessionResult) {
                          return '/reading/bilingual';
                        }
                        return null;
                      },
                      builder: (context, state) => ReadingResultScreen(
                        result: state.extra as ReadingSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'part5',
              builder: (context, state) => const Part5HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part5SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part5SessionResult) return '/reading/part5';
                        return null;
                      },
                      builder: (context, state) => Part5ResultScreen(
                        result: state.extra as Part5SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'part6',
              builder: (context, state) => const Part6HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part6SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part6SessionResult) return '/reading/part6';
                        return null;
                      },
                      builder: (context, state) => Part6ResultScreen(
                        result: state.extra as Part6SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'part7',
              builder: (context, state) => const Part7HomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const Part7SessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! Part7SessionResult) return '/reading/part7';
                        return null;
                      },
                      builder: (context, state) => Part7ResultScreen(
                        result: state.extra as Part7SessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/listening',
          builder: (context, state) => const ListeningHomeScreen(),
          routes: [
            GoRoute(
              path: 'dictation',
              builder: (context, state) => const DictationHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const DictationSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! DictationSessionResult) {
                          return '/listening/dictation';
                        }
                        return null;
                      },
                      builder: (context, state) => DictationResultScreen(
                        result: state.extra as DictationSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: 'comprehension',
              builder: (context, state) => const ComprehensionHomeScreen(),
              routes: [
                GoRoute(
                  path: 'session',
                  builder: (context, state) => const ComprehensionSessionScreen(),
                  routes: [
                    GoRoute(
                      path: 'result',
                      redirect: (context, state) {
                        if (state.extra is! ComprehensionSessionResult) {
                          return '/listening/comprehension';
                        }
                        return null;
                      },
                      builder: (context, state) => ComprehensionResultScreen(
                        result: state.extra as ComprehensionSessionResult,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
