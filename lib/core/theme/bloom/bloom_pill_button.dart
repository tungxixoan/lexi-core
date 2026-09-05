import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

enum BloomButtonVariant { primary, secondary, sage, danger, link }

/// Bloom's one button. Pill-shaped, 700 weight. Pass `onPressed: null` to
/// disable (renders at 50% opacity).
class BloomPillButton extends StatelessWidget {
  const BloomPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BloomButtonVariant.primary,
    this.block = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BloomButtonVariant variant;
  final bool block;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;

    late final Color bg;
    late final Color fg;
    late final BorderSide side;
    switch (variant) {
      case BloomButtonVariant.primary:
        bg = c.accent;
        fg = c.accentInk;
        side = BorderSide.none;
      case BloomButtonVariant.secondary:
        bg = c.surface;
        fg = c.ink;
        side = BorderSide(color: c.border);
      case BloomButtonVariant.sage:
        bg = c.sageBg;
        fg = c.sage;
        side = BorderSide(color: c.sage);
      case BloomButtonVariant.danger:
        bg = c.dangerBg;
        fg = c.danger;
        side = BorderSide(color: c.danger);
      case BloomButtonVariant.link:
        bg = Colors.transparent;
        fg = c.accent;
        side = BorderSide.none;
    }

    final textColor = onPressed == null ? fg.withValues(alpha: 0.5) : fg;
    final textStyle =
        TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: textColor);
    final child = icon == null
        ? Text(label, style: textStyle)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(label, style: textStyle)
            ],
          );

    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        disabledForegroundColor: fg.withValues(alpha: 0.5),
        padding: EdgeInsets.symmetric(
            horizontal: variant == BloomButtonVariant.link ? 4 : 20,
            vertical: block ? 14 : 10),
        shape: StadiumBorder(side: side),
      ),
      child: child,
    );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}
