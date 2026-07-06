import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/practice/presentation/providers/notification_notifier.dart';

class _Dest {
  const _Dest({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

const _kDefaultDests = [
  _Dest(
    path: '/',
    icon: Icons.search_outlined,
    selectedIcon: Icons.search,
    label: 'Dictionary',
  ),
  _Dest(
    path: '/vocab',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: 'Vocab Bank',
  ),
  _Dest(
    path: '/practice',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    label: 'Luyện tập',
  ),
  _Dest(
    path: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Cài đặt',
  ),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      ref.read(notificationNotifierProvider.notifier).reschedule();
    }
  }

  List<_Dest> _destinations() => _kDefaultDests;

  int _selectedIndex(BuildContext context, List<_Dest> dests) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = dests.length - 1; i >= 0; i--) {
      final p = dests[i].path;
      if (p == '/' ? location == '/' : location.startsWith(p)) return i;
    }
    return 0;
  }

  void _navigateTo(BuildContext context, int index, List<_Dest> dests) {
    if (index < dests.length) context.go(dests[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final dests = _destinations();
    final selectedIndex = _selectedIndex(context, dests);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) =>
                      _navigateTo(context, i, dests),
                  destinations: dests
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: widget.child),
              ],
            ),
          );
        }
        return Scaffold(
          body: widget.child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => _navigateTo(context, i, dests),
            destinations: dests
                .map(
                  (d) => NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
