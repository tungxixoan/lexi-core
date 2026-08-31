import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Bloom surface card: a `surface` ground, a 1px `border` outline, `md`
/// radius, and no shadow by default. Opt into a warm shadow with [elevated];
/// mark the focal card in a group with [selected].
class BloomCard extends StatelessWidget {
  const BloomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: selected ? c.surface3 : c.surface,
      border: Border.all(color: selected ? c.accent : c.border),
      borderRadius: BorderRadius.circular(BloomRadii.md),
      boxShadow: elevated ? BloomShadows.warm(isDark) : null,
    );
    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.md),
      child: Ink(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
