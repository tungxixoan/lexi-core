import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Bloom top bar: transparent over the scaffold gradient, no elevation,
/// 800-weight title.
class BloomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BloomAppBar({super.key, required this.title, this.leading, this.actions});

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: leading == null ? 20 : 8,
      leading: leading == null
          ? null
          : Padding(padding: const EdgeInsets.only(left: 16), child: leading),
      leadingWidth: leading == null ? null : 44,
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, color: c.ink),
      ),
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: 12),
            ],
    );
  }
}

/// Round icon button on a `surface2` chip with a `border` outline.
class BloomIconButton extends StatelessWidget {
  const BloomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: c.inkSoft,
      style: IconButton.styleFrom(
        backgroundColor: c.surface2,
        side: BorderSide(color: c.border),
        shape: const CircleBorder(),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
