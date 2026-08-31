import 'package:flutter/material.dart';
import '../../../../core/theme/bloom_tokens.dart';

/// A small round speaker button matching Bloom's `.pron-btn` (`bloom.css`).
class PronounceButton extends StatelessWidget {
  const PronounceButton({super.key, required this.onPressed, this.size = 26});

  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: onPressed,
        iconSize: size * 0.6,
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.volume_up),
        color: c.inkSoft,
        style: IconButton.styleFrom(
          backgroundColor: c.surface2,
          side: BorderSide(color: c.border),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
