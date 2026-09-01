import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
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
    final total = _totalQuestions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/part7');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Kết quả',
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  '${result.correctCount}/$total',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: result.correctCount == total
                        ? context.bloom.success
                        : context.bloom.accent,
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
              BloomPillButton(
                label: 'Bài khác',
                variant: BloomButtonVariant.primary,
                block: true,
                onPressed: () => _regenerate(context, ref),
              ),
              const SizedBox(height: 8),
              BloomPillButton(
                label: 'Về trang chính',
                variant: BloomButtonVariant.secondary,
                block: true,
                onPressed: () => _goHome(context, ref),
              ),
            ],
          ),
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
    final isDouble = group.documents.length == 2;
    return BloomCard(
      padding: const EdgeInsets.all(BloomSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDouble ? 'Đoạn ${groupIndex + 1} (2 văn bản liên quan)' : 'Đoạn ${groupIndex + 1}',
            style: TextStyle(fontWeight: FontWeight.w700, color: context.bloom.ink),
          ),
          const SizedBox(height: 8),
          for (var d = 0; d < group.documents.length; d++) ...[
            if (d > 0) const SizedBox(height: 12),
            Text(
              group.documents[d],
              style: webScaled(const TextStyle(fontSize: 13.5))
                  .copyWith(color: context.bloom.inkSoft),
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
                color: isCorrect ? context.bloom.success : context.bloom.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$questionNumber. ${question.question}',
                  style: webScaled(theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14))
                      .copyWith(color: context.bloom.ink),
                ),
              ),
            ],
          ),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: BloomMcOption(
                label: entry.value,
                leading: String.fromCharCode(65 + i),
                onTap: null,
                state: i == question.correctIndex
                    ? BloomMcState.correct
                    : (i == selected ? BloomMcState.wrong : BloomMcState.neutral),
              ),
            );
          }),
          Text(
            'Giải thích: ${question.explanation}',
            style: webScaled(
              (theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(
                fontStyle: FontStyle.italic,
                color: context.bloom.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
