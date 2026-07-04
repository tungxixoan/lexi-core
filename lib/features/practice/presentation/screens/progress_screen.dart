import 'dart:math' show max;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/exercise_result.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(learningStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tiến độ học')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StreakBanner(streak: stats.currentStreak),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Hôm nay',
                  value: '${stats.dueCount}',
                  icon: Icons.today_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Đã thuộc',
                  value: '${stats.masteredCount}',
                  icon: Icons.military_tech_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.dueCount > 0) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : () => _startDueSession(context),
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_loading ? 'Đang tải...' : 'Ôn ${stats.dueCount} từ ngay'),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('7 ngày qua', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _WeeklyChart(weeklyLog: stats.weeklyLog),
          const SizedBox(height: 24),
          Text('Theo cấp độ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _CefrBreakdown(
              breakdown: stats.cefrBreakdown, total: stats.totalCount),
        ],
      ),
    );
  }

  Future<void> _startDueSession(BuildContext context) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final words =
          await ref.read(getVocabListUseCaseProvider).execute(dueOnly: true);
      if (words.isEmpty || !context.mounted) return;
      final shuffled = List<VocabRecord>.from(words)..shuffle();
      context.push('/practice/session', extra: SessionConfig(words: shuffled));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Không thể bắt đầu ôn tập. Thử lại nhé!')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: streak > 0 ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              streak > 0 ? '🔥' : '❄️',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streak > 0
                        ? '$streak ngày liên tiếp'
                        : 'Chưa có streak',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    streak > 0
                        ? 'Tiếp tục giữ streak nhé!'
                        : 'Bắt đầu hôm nay nhé!',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.weeklyLog});
  final Map<String, int> weeklyLog;

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final counts = days.map((d) => weeklyLog[_dateKey(d)] ?? 0).toList();
    final labels = days
        .map((d) => ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1])
        .toList();
    final color = Theme.of(context).colorScheme.primary;
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _WeeklyChartPainter(
            counts: counts, labels: labels, color: color, labelColor: labelColor),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WeeklyChartPainter extends CustomPainter {
  _WeeklyChartPainter(
      {required this.counts,
      required this.labels,
      required this.color,
      required this.labelColor});
  final List<int> counts;
  final List<String> labels;
  final Color color;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.isEmpty ? 0 : counts.reduce(max);
    final barWidth = size.width / counts.length;
    const minBarHeight = 4.0;
    const labelHeight = 20.0;
    final chartHeight = size.height - labelHeight;

    final barPaint = Paint()..color = color;
    final textStyle = TextStyle(fontSize: 10, color: labelColor);

    for (int i = 0; i < counts.length; i++) {
      final barHeight = maxCount == 0
          ? minBarHeight
          : (counts[i] / maxCount * (chartHeight - minBarHeight)) +
              minBarHeight;
      final x = i * barWidth;
      final y = chartHeight - barHeight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 4, y, barWidth - 8, barHeight),
          const Radius.circular(4),
        ),
        barPaint,
      );
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(x + (barWidth - tp.width) / 2, chartHeight + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _WeeklyChartPainter old) =>
      !listEquals(old.counts, counts) ||
      !listEquals(old.labels, labels) ||
      old.color != color ||
      old.labelColor != labelColor;
}

class _CefrBreakdown extends StatelessWidget {
  const _CefrBreakdown({required this.breakdown, required this.total});
  final Map<CEFRLevel, int> breakdown;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: CEFRLevel.values.map((level) {
        final count = breakdown[level] ?? 0;
        final fraction = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(level.label,
                    style: theme.textTheme.labelMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(value: fraction),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text('$count',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
