import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A thin rounded track with a sage->accent gradient fill.
class BloomProgressBar extends StatelessWidget {
  const BloomProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(BloomRadii.pill),
      child: Container(
        key: const ValueKey('bloom-progress-track'),
        height: height,
        color: c.surface3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            heightFactor: 1,
            child: DecoratedBox(
              key: const ValueKey('bloom-progress-fill'),
              decoration:
                  BoxDecoration(gradient: BloomGradients.progressFill(c)),
            ),
          ),
        ),
      ),
    );
  }
}
