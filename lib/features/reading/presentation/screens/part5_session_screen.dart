import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5SessionScreen extends ConsumerWidget {
  const Part5SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part5SessionState?>>(part5PracticeNotifierProvider,
        (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part5SessionResult(
            set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part5/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part5PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part5');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (session.isSubmitted) return const Scaffold(body: SizedBox.shrink());
        return _SessionScaffold(session: session);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final Part5SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part5PracticeNotifierProvider.notifier);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/part5');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 5 — Điền câu',
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0;
                          i < session.set.questions.length;
                          i++) ...[
                        if (i > 0) const SizedBox(height: BloomSpacing.md),
                        _QuestionCard(
                          index: i,
                          question: session.set.questions[i],
                          selected: session.selectedAnswers[i],
                          onSelected: (optionIndex) =>
                              notifier.selectAnswer(i, optionIndex),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: BloomSpacing.sm),
                child: BloomSubmitBar(
                  answered:
                      session.selectedAnswers.where((a) => a != null).length,
                  total: session.selectedAnswers.length,
                  onSubmit: session.canSubmit ? notifier.submit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int index;
  final Part5Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.sentenceWithBlank}',
            style: webScaled(
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                .copyWith(color: context.bloom.ink),
          ),
          const SizedBox(height: BloomSpacing.md),
          for (var i = 0; i < question.options.length; i++) ...[
            if (i > 0) const SizedBox(height: BloomSpacing.sm),
            BloomMcOption(
              label: question.options[i],
              leading: String.fromCharCode(65 + i),
              onTap: () => onSelected(i),
              state:
                  selected == i ? BloomMcState.selected : BloomMcState.neutral,
            ),
          ],
        ],
      ),
    );
  }
}
