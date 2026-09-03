import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import 'bloom_card.dart';

/// A navigation row inside a hub screen: a 40×40 sage icon tile, a title +
/// subtitle stack, and a trailing chevron, all wrapped in a tappable
/// [BloomCard]. Pass [selected] to mark the focal card in the list — it tints
/// the icon tile and forwards to [BloomCard.selected].
class BloomNavCard extends StatelessWidget {
  const BloomNavCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return BloomCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.surface : c.sageBg,
              borderRadius: BorderRadius.circular(BloomRadii.md),
            ),
            child: Icon(icon, size: 20, color: selected ? c.accent : c.sage),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: c.inkFaint),
        ],
      ),
    );
  }
}
