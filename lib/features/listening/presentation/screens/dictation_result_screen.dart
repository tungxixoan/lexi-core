import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/dictation_practice_provider.dart';

class DictationResultScreen extends ConsumerStatefulWidget {
  const DictationResultScreen({super.key, required this.result});
  final DictationSessionResult result;

  @override
  ConsumerState<DictationResultScreen> createState() =>
      _DictationResultScreenState();
}

class _DictationResultScreenState extends ConsumerState<DictationResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSm2());
  }

  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);
    // vocabBankProvider reads synchronously off the underlying async
    // notifier and returns [] while it's still loading, which races the
    // fetch below. Await the notifier's future so the vocab list is
    // guaranteed to be populated before we look up records to update.
    final vocabRecords = await ref.read(vocabBankNotifierProvider.future);
    final quality = widget.result.sm2Quality;

    for (final id in widget.result.item.vocabIds) {
      try {
        final record = vocabRecords.firstWhere((r) => r.id == id);
        final updated = computeUseCase.compute(record, quality);
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash the result screen on an SM-2 update failure
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final scorePct = (result.finalScore * 100).toStringAsFixed(0);
    final elapsed = _formatDuration(result.duration);

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Điểm', value: '$scorePct%'),
                _StatCard(label: 'Nghe lại', value: '${result.replayCount}'),
                _StatCard(label: 'Thời gian', value: elapsed),
              ],
            ),
            const SizedBox(height: 24),
            Text('Bạn đã gõ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _DiffText(
              typed: result.typed,
              target: result.item.target,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Câu đúng', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.item.target, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            Text('Nghĩa', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(result.item.vietnamese, style: theme.textTheme.bodyLarge),
            const Spacer(),
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Câu khác'),
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
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/listening/dictation');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _DiffText extends StatelessWidget {
  const _DiffText({required this.typed, required this.target, this.style});
  final String typed;
  final String target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    for (int i = 0; i < typed.length; i++) {
      final correct = i < target.length && typed[i] == target[i];
      spans.add(TextSpan(
        text: typed[i],
        style: (style ?? const TextStyle()).copyWith(
          color: correct ? Colors.green : theme.colorScheme.error,
          backgroundColor:
              correct ? null : theme.colorScheme.error.withValues(alpha: 0.1),
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans, style: style));
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
