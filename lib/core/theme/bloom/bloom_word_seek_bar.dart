import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A thin Bloom skin over [Slider] for word-level audio seeking in the listening
/// sessions. Visual only — the drag-preview state stays with the caller.
class BloomWordSeekBar extends StatelessWidget {
  const BloomWordSeekBar({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.label,
    this.enabled = true,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final String? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: BloomSpacing.xs, left: BloomSpacing.sm),
            child: Text(label!, style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: c.accent,
            inactiveTrackColor: c.surface3,
            thumbColor: c.accent,
            overlayColor: c.accent.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: value.clamp(0, max),
            max: max,
            divisions: max.round().clamp(1, 1 << 20),
            onChanged: enabled ? onChanged : null,
            onChangeStart: onChangeStart,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
