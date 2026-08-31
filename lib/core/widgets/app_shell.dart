import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/bloom/bloom.dart';
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

  static const _destinations = [
    _Dest(
      path: '/',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
      label: 'Tra từ',
    ),
    _Dest(
      path: '/vocab',
      icon: Icons.library_books_outlined,
      selectedIcon: Icons.library_books,
      label: 'Từ vựng',
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

  static const _navItems = <BloomNavItem>[
    BloomNavItem(icon: Icons.search, label: 'Tra từ'),
    BloomNavItem(icon: Icons.library_books, label: 'Từ vựng'),
    BloomNavItem(icon: Icons.school, label: 'Luyện tập'),
    BloomNavItem(icon: Icons.settings, label: 'Cài đặt'),
  ];

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final dests = _destinations;
        final selectedIndex = _selectedIndex(context, dests);

        if (constraints.maxWidth >= 600) {
          return BloomScaffold(
            body: Row(
              children: [
                BloomNavRail(
                  items: _navItems,
                  selectedIndex: selectedIndex,
                  onSelected: (i) => _navigateTo(context, i, dests),
                  extended: constraints.maxWidth >= 1200,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.bloom.border,
                ),
                Expanded(child: widget.child),
              ],
            ),
          );
        }
        return BloomScaffold(
          body: widget.child,
          bottomNavigationBar: BloomBottomNav(
            items: _navItems,
            selectedIndex: selectedIndex,
            onSelected: (i) => _navigateTo(context, i, dests),
          ),
        );
      },
    );
  }
}
