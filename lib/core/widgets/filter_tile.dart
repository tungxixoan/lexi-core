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
    // Paint the decoration in the widget layer (a plain Container) so the fill
    // and border are always visible, then a fresh transparent Material +
    // InkWell above it for the ripple. Putting the decoration on `Ink` instead
    // pushes it into the nearest ancestor Material's ink layer, which under
    // BloomScaffold sits *below* the page gradient — the fill/border vanish
    // (see bloom_card.dart for the same fix).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(BloomRadii.pill),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(BloomRadii.pill),
            onTap: onTap,
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
      ),
    );
  }
}
