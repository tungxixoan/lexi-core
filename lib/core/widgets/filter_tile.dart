// lib/core/widgets/filter_tile.dart
import 'package:flutter/material.dart';
import '../theme/bloom_tokens.dart';

/// A compact row that shows a label + current value and opens a picker
/// (typically a bottom sheet) when tapped. Used to keep filter/option rows
/// consistent across screens instead of native dropdowns or long chip rows.
///
/// Bloom look: a full-width pill with a `surface2` fill and a 1px `border`
/// outline, tappable via [InkWell].
class FilterTile extends StatelessWidget {
  const FilterTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(BloomRadii.pill),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(BloomRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: c.inkFaint),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: c.inkSoft,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.ink),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
