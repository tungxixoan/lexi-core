import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

enum BloomChipStyle { neutral, active, topic, clear }

/// Pill chip. `neutral` = `surface2` + border; `active` = accent fill;
/// `topic` = sage-tinted; `clear` = danger-tinted (for a "remove filters"
/// action).
class BloomChip extends StatelessWidget {
  const BloomChip({
    super.key,
    required this.label,
    this.onTap,
    this.style = BloomChipStyle.neutral,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final BloomChipStyle style;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    late final Color bg;
    late final Color fg;
    late final Color border;
    switch (style) {
      case BloomChipStyle.neutral:
        bg = c.surface2;
        fg = c.inkSoft;
        border = c.border;
      case BloomChipStyle.active:
        bg = c.accent;
        fg = c.accentInk;
        border = c.accent;
      case BloomChipStyle.topic:
        bg = c.sageBg;
        fg = c.sage;
        border = c.sageBg;
      case BloomChipStyle.clear:
        bg = c.dangerBg;
        fg = c.danger;
        border = c.danger;
    }

    final decoration = BoxDecoration(
      color: bg,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(BloomRadii.pill),
    );
    const contentPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );

    if (onTap == null) {
      return Container(
        padding: contentPadding,
        decoration: decoration,
        child: row,
      );
    }
    // Interactive path: decoration in the widget layer (always visible), then
    // a fresh transparent Material + InkWell above it for the ripple. On `Ink`
    // the fill/border would sink into the ancestor Material below the page
    // gradient (see bloom_card.dart for the same fix).
    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BloomRadii.pill),
          child: Padding(padding: contentPadding, child: row),
        ),
      ),
    );
  }
}

/// A tiny 800-weight CEFR badge on a sage ground.
class BloomCefrPill extends StatelessWidget {
  const BloomCefrPill(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.sage,
        borderRadius: BorderRadius.circular(BloomRadii.pill),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
            color: c.accentInk, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}
