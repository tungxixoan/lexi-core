import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

// chart-internal geometry (px), not on the BloomSpacing scale
const _captionSlotHeight = 14.0;
const _labelGap = 6.0;

/// One column of a [BloomBarChart].
class BloomBarChartBar {
  const BloomBarChartBar({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final int value;
  final bool highlight;
}

/// A compact 7-ish-column activity chart — the "today" column tinted accent,
/// each non-zero bar captioned with its count. Ports web's `.dash-chart`.
class BloomBarChart extends StatelessWidget {
  const BloomBarChart({super.key, required this.bars, this.height = 120});

  final List<BloomBarChartBar> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final maxValue = bars.fold<int>(0, (m, b) => math.max(m, b.value));

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bar in bars)
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: _captionSlotHeight,
                    child: bar.value > 0
                        ? Center(
                            child: Text('${bar.value}',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.0,
                                    fontWeight: FontWeight.w700,
                                    color: c.inkSoft)),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: _fraction(bar.value, maxValue),
                        widthFactor: 0.55,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: bar.highlight ? c.accent : c.surface3,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(BloomRadii.sm)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: _labelGap),
                  Text(
                    bar.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: bar.highlight ? c.accent : c.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _fraction(int value, int maxValue) {
    if (maxValue == 0 || value == 0) return 0.04;
    return math.max(0.10, value / maxValue);
  }
}
