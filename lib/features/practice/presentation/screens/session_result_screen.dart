// lib/features/practice/presentation/screens/session_result_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/exercise_result.dart';
import '../providers/notification_notifier.dart';

class SessionResultScreen extends ConsumerStatefulWidget {
  const SessionResultScreen({super.key, required this.result});
  final SessionResult result;

  @override
  ConsumerState<SessionResultScreen> createState() => _SessionResultScreenState();
}

class _SessionResultScreenState extends ConsumerState<SessionResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSm2());
  }

  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);

    for (final result in widget.result.results) {
      try {
        final word = widget.result.words.firstWhere(
          (w) => w.id == result.vocabRecordId,
        );
        final updated = computeUseCase.compute(word, result.quality);
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash result screen on SM-2 update failure
      }
    }

    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(widget.result.totalCount);
      await ref.read(notificationNotifierProvider.notifier).reschedule();
    } catch (_) {
      // best-effort: don't crash on stats/notification failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = widget.result.correctCount;
    final total = widget.result.totalCount;
    final pct = total > 0 ? (correct / total * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      '$pct%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: pct >= 70 ? Colors.green.shade700 : theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('$correct / $total từ đúng', style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.result.results.length,
                itemBuilder: (context, i) {
                  final r = widget.result.results[i];
                  final word = widget.result.words.firstWhere(
                    (w) => w.id == r.vocabRecordId,
                    orElse: () => widget.result.words[i],
                  );
                  return ListTile(
                    leading: Icon(
                      r.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: r.isCorrect ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      word.headword,
                      style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
                    ),
                    subtitle: Text(
                      word.meaning,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/practice/vocab'),
              child: const Text('Luyện tập lại'),
            ),
          ],
        ),
      ),
    );
  }
}
