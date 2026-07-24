import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends ConsumerWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabRecords = ref.watch(vocabBankProvider);
    final theme = Theme.of(context);

    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);
    final scorePct = (result.finalScore * 100).toStringAsFixed(1);

    final usedRecords = result.passage.vocabIds
        .map((id) => vocabRecords.where((r) => r.id == id).firstOrNull)
        .whereType<VocabRecord>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Độ chính xác', value: '$accuracyPct%'),
                _StatCard(label: 'Tốc độ', value: '$wpm WPM'),
                _StatCard(label: 'Thời gian', value: elapsed),
                _StatCard(label: 'Điểm', value: '$scorePct%'),
              ],
            ),
            const SizedBox(height: 24),
            if (usedRecords.isNotEmpty) ...[
              Text(
                'Từ vựng đã luyện',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: usedRecords.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final record = usedRecords[i];
                    return ListTile(
                      title: Text(record.headword),
                      subtitle: Text(
                        record.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const Spacer(),
            // Action buttons
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Sinh bài mới'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _goHome(context, ref),
              child: const Text('Về trang chính'),
            ),
          ],
        ),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
