import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/part7_passage.dart';
import '../providers/part7_practice_provider.dart';

class Part7ResultScreen extends ConsumerStatefulWidget {
  const Part7ResultScreen({super.key, required this.result});
  final Part7SessionResult result;

  @override
  ConsumerState<Part7ResultScreen> createState() => _Part7ResultScreenState();
}

class _Part7ResultScreenState extends ConsumerState<Part7ResultScreen> {
  Part7SessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  int get _totalQuestions =>
      result.set.passageGroups.fold(0, (sum, g) => sum + g.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _documentsText =>
      result.set.passageGroups.expand((g) => g.documents).join(' ');

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
                    for (var g = 0; g < result.set.passageGroups.length; g++) ...[
                      if (g > 0) const SizedBox(height: 16),
                      _PassageGroupBreakdown(
                        groupIndex: g,
                        group: result.set.passageGroups[g],
                        allGroups: result.set.passageGroups,
                        selectedAnswers: result.selectedAnswers,
                      ),
                    ],
                    ResultSuggestionsSection(
                      text: _documentsText,
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
    ref.read(part7PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part7');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part7PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _PassageGroupBreakdown extends StatelessWidget {
  const _PassageGroupBreakdown({
    required this.groupIndex,
    required this.group,
    required this.allGroups,
    required this.selectedAnswers,
  });

  final int groupIndex;
  final Part7PassageGroup group;
  final List<Part7PassageGroup> allGroups;
  final List<int?> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDouble = group.documents.length == 2;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDouble ? 'Đoạn ${groupIndex + 1} (2 văn bản liên quan)' : 'Đoạn ${groupIndex + 1}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var d = 0; d < group.documents.length; d++) ...[
              if (d > 0) const SizedBox(height: 12),
              Text(
                group.documents[d],
                style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
              ),
            ],
            const SizedBox(height: 8),
            for (var q = 0; q < group.questions.length; q++)
              _QuestionBreakdown(
                questionNumber: q + 1,
                question: group.questions[q],
                selected: selectedAnswers[Part7SessionState.flatIndex(allGroups, groupIndex, q)],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.questionNumber, required this.question, required this.selected});

  final int questionNumber;
  final Part7Question question;
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
              Expanded(
                child: Text(
                  '$questionNumber. ${question.question}',
                  style: webScaled(theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)),
                ),
              ),
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
