import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A percentage ring — `accent` arc over a `surface3` track, `label` centred
/// in the middle. Flutter equivalent of bloom.css `.practice-result-circle`.
class BloomResultRing extends StatelessWidget {
  const BloomResultRing({
    super.key,
    required this.percent,
    this.size = 140,
    this.label,
  });

  final int percent;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final clamped = percent.clamp(0, 100);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction: clamped / 100,
          arc: c.accent,
          track: c.surface3,
          stroke: size * 0.11,
        ),
        child: Center(
          child: Text(
            label ?? '$clamped%',
            style: TextStyle(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w800,
                color: c.ink),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.arc,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color arc;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = arc;
    canvas.drawCircle(center, radius, trackPaint);
    if (fraction > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, fraction * 2 * math.pi, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.arc != arc ||
      old.track != track ||
      old.stroke != stroke;
}
