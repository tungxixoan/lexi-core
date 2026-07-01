import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_bank_screen.dart';
import '../../features/vocabulary/presentation/screens/vocab_detail_screen.dart';
import '../../features/practice/presentation/screens/practice_home_screen.dart';
import '../../features/practice/presentation/screens/practice_session_screen.dart';
import '../../features/practice/presentation/screens/session_result_screen.dart';
import '../../features/practice/domain/entities/exercise_result.dart';

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
      ],
    ),
  ],
);
