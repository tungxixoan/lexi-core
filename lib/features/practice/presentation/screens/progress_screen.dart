import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/exercise_result.dart';
import '../../domain/entities/learning_stats.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';

String _dateKey(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

String _weekdayLabel(DateTime d) =>
    ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][d.weekday - 1];

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(learningStatsProvider);

    return statsAsync.when(
      loading: () => const BloomScaffold(
        appBar: BloomAppBar(title: 'Tiến độ học'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BloomScaffold(
        appBar: const BloomAppBar(title: 'Tiến độ học'),
        body: Center(
          child: Text(
            'Không tải được dữ liệu tiến độ.',
            style: TextStyle(color: context.bloom.inkSoft),
          ),
        ),
      ),
      data: (stats) => _buildDashboard(context, stats),
    );
  }

  Widget _buildDashboard(BuildContext context, LearningStats stats) {
    final c = context.bloom;
    final streak = stats.currentStreak;
    final today = DateTime.now();
    final last7Days =
        List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return BloomScaffold(
      appBar: const BloomAppBar(title: 'Tiến độ học'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Streak banner
          BloomCard(
            child: Row(
              children: [
                Text(
                  streak > 0 ? '🔥' : '❄️',
                  style: const TextStyle(fontSize: 34),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (streak > 0)
                        Text(
                          '$streak',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: c.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      Text(
                        streak > 0 ? 'ngày liên tiếp' : 'Chưa có streak',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        streak > 0
                            ? 'Tiếp tục giữ streak nhé!'
                            : 'Bắt đầu hôm nay nhé!',
                        style: TextStyle(fontSize: 13, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stat grid
          Row(
            children: [
              Expanded(
                child: BloomStatCard(
                  label: 'Hôm nay',
                  value: '${stats.dueCount}',
                ),
              ),
              const SizedBox(width: BloomSpacing.md),
              Expanded(
                child: BloomStatCard(
                  label: 'Đã thuộc',
                  value: '${stats.masteredCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.dueCount > 0) ...[
            BloomPillButton(
              label: 'Ôn ${stats.dueCount} từ ngay',
              icon: Icons.play_arrow,
              variant: BloomButtonVariant.primary,
              block: true,
              onPressed: _loading ? null : () => _startDueSession(context),
            ),
            const SizedBox(height: 24),
          ],
          // Weekly activity chart
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('7 ngày qua'),
                const SizedBox(height: BloomSpacing.sm),
                BloomBarChart(
                  bars: [
                    for (final d in last7Days)
                      BloomBarChartBar(
                        label: _weekdayLabel(d),
                        value: stats.weeklyLog[_dateKey(d)] ?? 0,
                        highlight: _dateKey(d) == _dateKey(today),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // CEFR breakdown
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BloomSectionHeader('Theo cấp độ'),
                for (final level in CEFRLevel.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            level.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: c.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: BloomSpacing.md),
                        Expanded(
                          child: BloomProgressBar(
                            value: stats.totalCount == 0
                                ? 0.0
                                : (stats.cefrBreakdown[level] ?? 0) /
                                    stats.totalCount,
                            height: 8,
                          ),
                        ),
                        const SizedBox(width: BloomSpacing.md),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${stats.cefrBreakdown[level] ?? 0}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDueSession(BuildContext context) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final language = ref.read(userSettingsNotifierProvider).targetLanguage;
      final words = await ref
          .read(getVocabListUseCaseProvider)
          .execute(language: language, dueOnly: true);
      if (words.isEmpty || !context.mounted) return;
      final shuffled = List<VocabRecord>.from(words)..shuffle();
      context.push(
        '/practice/session',
        extra: SessionConfig(words: shuffled, aiRatio: 0.0),
      );
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
