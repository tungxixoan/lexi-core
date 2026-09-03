import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A labelled statistic: a small uppercase [label], a large tabular [value],
/// and an optional [foot] sub-line. Used on the Progress dashboard and the
/// dictation result screen. Ports web's `.dash-stat-card` / `.reading-stat-card`.
class BloomStatCard extends StatelessWidget {
  const BloomStatCard({
    super.key,
    required this.label,
    required this.value,
    this.foot,
  });

  final String label;
  final String value;
  final String? foot;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      padding: const EdgeInsets.all(BloomSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: c.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (foot != null) ...[
            const SizedBox(height: 4),
            Text(foot!, style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
          ],
        ],
      ),
    );
  }
}
