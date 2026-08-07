import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';

class Part6ResultScreen extends ConsumerStatefulWidget {
  const Part6ResultScreen({super.key, required this.result});
  final Part6SessionResult result;

  @override
  ConsumerState<Part6ResultScreen> createState() => _Part6ResultScreenState();
}

class _Part6ResultScreenState extends ConsumerState<Part6ResultScreen> {
  Part6SessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  int get _totalQuestions =>
      result.set.passages.fold(0, (sum, p) => sum + p.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _passagesText => result.set.passages.map((p) => p.passageText).join(' ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalQuestions;

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
                    for (var p = 0; p < result.set.passages.length; p++) ...[
                      if (p > 0) const SizedBox(height: 16),
                      _PassageBreakdown(
                        passageIndex: p,
                        passage: result.set.passages[p],
                        selectedAnswers: result.selectedAnswers,
                      ),
                    ],
                    ResultSuggestionsSection(
                      text: _passagesText,
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
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part6');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _PassageBreakdown extends StatelessWidget {
  const _PassageBreakdown({
    required this.passageIndex,
    required this.passage,
    required this.selectedAnswers,
  });

  final int passageIndex;
  final Part6Passage passage;
  final List<int?> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đoạn ${passageIndex + 1}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              passage.passageText,
              style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 8),
            for (var q = 0; q < passage.questions.length; q++)
              _QuestionBreakdown(
                blankNumber: q + 1,
                question: passage.questions[q],
                selected: selectedAnswers[Part6SessionState.flatIndex(passageIndex, q)],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.blankNumber, required this.question, required this.selected});

  final int blankNumber;
  final Part6Question question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Chỗ trống ($blankNumber)', style: theme.textTheme.titleSmall),
            ],
          ),
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
          Text(
            'Giải thích: ${question.explanation}',
            style: webScaled(
              (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12))
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
