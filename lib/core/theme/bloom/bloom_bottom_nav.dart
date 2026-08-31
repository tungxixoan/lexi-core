import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

class BloomNavItem {
  const BloomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Bottom navigation, Bloom-styled: `surface2` bar with a top border; the
/// selected item's icon sits on a `surface3` "pill" and its label is accent.
class BloomBottomNav extends StatelessWidget {
  const BloomBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BloomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavCell(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.selected, required this.onTap});
  final BloomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final color = selected ? c.accent : c.inkFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? c.surface3 : Colors.transparent,
                borderRadius: BorderRadius.circular(BloomRadii.pill),
              ),
              child: Icon(item.icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(item.label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Wide-screen rail. A restyled `NavigationRail` — NOT a web-style labelled
/// sidebar. Same item set as [BloomBottomNav].
class BloomNavRail extends StatelessWidget {
  const BloomNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.extended = false,
  });

  final List<BloomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return NavigationRail(
      extended: extended,
      backgroundColor: c.surface2,
      selectedIndex: selectedIndex,
      indicatorColor: c.surface3,
      onDestinationSelected: onSelected,
      selectedIconTheme: IconThemeData(color: c.accent),
      unselectedIconTheme: IconThemeData(color: c.inkFaint),
      selectedLabelTextStyle:
          TextStyle(color: c.accent, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: c.inkFaint),
      destinations: [
        for (final it in items)
          NavigationRailDestination(
            icon: Icon(it.icon),
            label: Text(it.label),
          ),
      ],
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
    );
  }
}
