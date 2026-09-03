import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionResultScreen extends ConsumerStatefulWidget {
  const ComprehensionResultScreen({super.key, required this.result});
  final ComprehensionSessionResult result;

  @override
  ConsumerState<ComprehensionResultScreen> createState() =>
      _ComprehensionResultScreenState();
}

class _ComprehensionResultScreenState
    extends ConsumerState<ComprehensionResultScreen> {
  ComprehensionSessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
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

  String get _transcriptText =>
      result.passage.turns.map((t) => t.text).join(' ');

  @override
  Widget build(BuildContext context) {
    final total = result.passage.questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/listening/comprehension');
      },
      child: BloomScaffold(
        appBar: const BloomAppBar(
          title: 'Kết quả',
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
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
              for (var i = 0; i < result.passage.questions.length; i++) ...[
                if (i > 0) const SizedBox(height: BloomSpacing.md),
                _QuestionBreakdown(
                  index: i,
                  question: result.passage.questions[i],
                  selected: result.selectedAnswers[i],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Bản ghi âm',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.bloom.ink,
                ),
              ),
              const SizedBox(height: 8),
              BloomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var t = 0; t < result.passage.turns.length; t++) ...[
                      if (t > 0) const SizedBox(height: 4),
                      Text(
                        result.passage.turns[t].speaker != null
                            ? '${result.passage.turns[t].speaker}: ${result.passage.turns[t].text}'
                            : result.passage.turns[t].text,
                        style: webScaled(const TextStyle(fontSize: 14))
                            .copyWith(color: context.bloom.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ResultSuggestionsSection(
                text: _transcriptText,
                targetLanguage: result.passage.targetLanguage,
                targetCefrLevel: result.passage.level,
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
    final isCorrect = selected == question.correctIndex;

    return BloomCard(
      padding: const EdgeInsets.all(BloomSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? context.bloom.success : context.bloom.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${index + 1}. ${question.question}',
                  style: webScaled(const TextStyle(fontSize: 14)).copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.bloom.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var o = 0; o < question.options.length; o++) ...[
            if (o > 0) const SizedBox(height: BloomSpacing.sm),
            BloomMcOption(
              label: question.options[o],
              leading: String.fromCharCode(65 + o),
              onTap: null,
              state: o == question.correctIndex
                  ? BloomMcState.correct
                  : (o == selected ? BloomMcState.wrong : BloomMcState.neutral),
            ),
          ],
        ],
      ),
    );
  }
}
