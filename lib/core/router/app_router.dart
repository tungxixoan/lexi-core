import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_home_screen.dart';
import '../../features/practice/presentation/screens/practice_session_screen.dart';
import '../../features/practice/presentation/screens/progress_screen.dart';
import '../../features/practice/presentation/screens/session_result_screen.dart';
import '../../features/practice/domain/entities/exercise_result.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/reading/presentation/screens/reading_home_screen.dart';
import '../../features/reading/presentation/screens/reading_session_screen.dart';
import '../../features/reading/presentation/screens/reading_result_screen.dart';
import '../../features/reading/presentation/providers/reading_practice_provider.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
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
          builder: (context, state) => const PracticeHomeScreen(),
          routes: [
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
          ],
        ),
        GoRoute(
          path: '/reading',
          builder: (context, state) => const ReadingHomeScreen(),
          routes: [
            GoRoute(
              path: 'session',
              builder: (context, state) => const ReadingSessionScreen(),
              routes: [
                GoRoute(
                  path: 'result',
                  redirect: (context, state) {
                    if (state.extra is! ReadingSessionResult) return '/reading';
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
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
