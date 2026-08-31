import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Small uppercase group label, letter-spaced, `inkFaint`.
class BloomSectionHeader extends StatelessWidget {
  const BloomSectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c.inkFaint,
        ),
      ),
    );
  }
}

/// The LexiCore "leaf" — a teardrop with an accent->sage gradient.
class BloomLeafMark extends StatelessWidget {
  const BloomLeafMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BloomGradients.leafMark(context.bloom),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(999),
          topRight: Radius.circular(999),
          bottomLeft: Radius.circular(999),
          bottomRight: Radius.circular(4),
        ),
      ),
    );
  }
}
