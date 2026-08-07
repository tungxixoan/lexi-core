import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5ResultScreen extends ConsumerStatefulWidget {
  const Part5ResultScreen({super.key, required this.result});
  final Part5SessionResult result;

  @override
  ConsumerState<Part5ResultScreen> createState() => _Part5ResultScreenState();
}

class _Part5ResultScreenState extends ConsumerState<Part5ResultScreen> {
  Part5SessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(result.set.questions.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _questionsText => result.set.questions.map((q) => q.sentenceWithBlank).join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = result.set.questions.length;

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
                    ...result.set.questions.asMap().entries.map((entry) {
                      final i = entry.key;
                      return _QuestionBreakdown(
                        index: i,
                        question: entry.value,
                        selected: result.selectedAnswers[i],
                      );
                    }),
                    ResultSuggestionsSection(
                      text: _questionsText,
                      targetLanguage: result.set.targetLanguage,
                      targetCefrLevel: null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _regenerate(context, ref), child: const Text('Bài khác')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _goHome(context, ref), child: const Text('Về trang chính')),
          ],
        ),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(part5PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part5');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part5PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.index, required this.question, required this.selected});

  final int index;
  final Part5Question question;
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
                    '${index + 1}. ${question.sentenceWithBlank}',
                    style: webScaled(theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)),
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
                  style: webScaled(
                    (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                      color: color,
                      fontWeight: (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            Text(
              'Giải thích: ${question.explanation}',
              style: webScaled(
                (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12))
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
