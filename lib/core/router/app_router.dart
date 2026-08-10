import 'package:go_router/go_router.dart';
import '../widgets/app_shell.dart';
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
