import 'package:go_router/go_router.dart';
import '../../features/dictionary/presentation/screens/lookup_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LookupScreen(),
    ),
  ],
);
