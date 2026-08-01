import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionResultScreen extends ConsumerStatefulWidget {
  const ComprehensionResultScreen({super.key, required this.result});
  final ComprehensionSessionResult result;

  @override
  ConsumerState<ComprehensionResultScreen> createState() =>
      _ComprehensionResultScreenState();
}

class _ComprehensionResultScreenState extends ConsumerState<ComprehensionResultScreen> {
  ComprehensionSessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordPracticeSession());
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = result.passage.questions.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${result.correctCount}/$total',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.correctCount == total
                      ? Colors.green.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...result.passage.questions.asMap().entries.map((entry) {
                      final i = entry.key;
                      return _QuestionBreakdown(
                        index: i,
                        question: entry.value,
                        selected: result.selectedAnswers[i],
                      );
                    }),
                    const SizedBox(height: 16),
                    Text('Bản ghi âm', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...result.passage.turns.map(
                      (t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          t.speaker != null ? '${t.speaker}: ${t.text}' : t.text,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Bài khác'),
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
    ref.read(listeningComprehensionNotifierProvider.notifier).reset();
    context.go('/listening/comprehension');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(listeningComprehensionNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final ListeningQuestion question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${index + 1}. ${question.question}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...question.options.asMap().entries.map((entry) {
              final i = entry.key;
              final isCorrectOption = i == question.correctIndex;
              final isSelectedOption = i == selected;
              Color? color;
              if (isCorrectOption) {
                color = Colors.green;
              } else if (isSelectedOption) {
                color = theme.colorScheme.error;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  entry.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight:
                        (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
