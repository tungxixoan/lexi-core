import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Continuous playback-speed control (0.5×–2.0×, 0.05 steps) for the listening
/// session screens — matches the web's `<input type="range">` speed selector.
class BloomSpeedSlider extends StatelessWidget {
  const BloomSpeedSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  static const _min = 0.5;
  static const _max = 2.0;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Row(
      children: [
        Text('Tốc độ', style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: c.accent,
              inactiveTrackColor: c.surface3,
              thumbColor: c.accent,
              overlayColor: c.accent.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(_min, _max),
              min: _min,
              max: _max,
              divisions: 30, // (2.0 - 0.5) / 0.05
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('${value.toStringAsFixed(2)}×',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                color: c.ink,
                fontFeatures: const [],
              )),
        ),
      ],
    );
  }
}
