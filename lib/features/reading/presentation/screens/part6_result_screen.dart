import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
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
    final total = _totalQuestions;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/part6');
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
    return BloomCard(
      padding: const EdgeInsets.all(BloomSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đoạn ${passageIndex + 1}',
            style: TextStyle(fontWeight: FontWeight.w700, color: context.bloom.ink),
          ),
          const SizedBox(height: 8),
          Text(
            passage.passageText,
            style: webScaled(const TextStyle(fontSize: 13.5))
                .copyWith(color: context.bloom.inkSoft),
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
                color: isCorrect ? context.bloom.success : context.bloom.danger,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Chỗ trống ($blankNumber)',
                style: theme.textTheme.titleSmall?.copyWith(color: context.bloom.ink),
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
