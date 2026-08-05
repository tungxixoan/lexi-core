import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';

class Part6SessionScreen extends ConsumerWidget {
  const Part6SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part6SessionState?>>(part6PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part6SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part6/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part6PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part6');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        if (session.isSubmitted) return const Scaffold(body: SizedBox.shrink());
        return _SessionScaffold(session: session);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final Part6SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part6PracticeNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Part 6 — Điền đoạn văn'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var p = 0; p < session.set.passages.length; p++) ...[
                      if (p > 0) const SizedBox(height: 16),
                      _PassageCard(
                        passageIndex: p,
                        passage: session.set.passages[p],
                        selectedAnswers: session.selectedAnswers,
                        onSelected: (questionIndex, optionIndex) =>
                            notifier.selectAnswer(p, questionIndex, optionIndex),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: session.canSubmit ? notifier.submit : null,
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassageCard extends StatelessWidget {
  const _PassageCard({
    required this.passageIndex,
    required this.passage,
    required this.selectedAnswers,
    required this.onSelected,
  });

  final int passageIndex;
  final Part6Passage passage;
  final List<int?> selectedAnswers;
  final void Function(int questionIndex, int optionIndex) onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đoạn ${passageIndex + 1}', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(passage.passageText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var q = 0; q < passage.questions.length; q++) ...[
              if (q > 0) const Divider(height: 1),
              _QuestionGroup(
                blankNumber: q + 1,
                question: passage.questions[q],
                selected: selectedAnswers[Part6SessionState.flatIndex(passageIndex, q)],
                onSelected: (optionIndex) => onSelected(q, optionIndex),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestionGroup extends StatelessWidget {
  const _QuestionGroup({
    required this.blankNumber,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int blankNumber;
  final Part6Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text('Chỗ trống ($blankNumber)', style: Theme.of(context).textTheme.labelMedium),
        ),
        ...question.options.asMap().entries.map(
              (entry) => RadioListTile<int>(
                value: entry.key,
                groupValue: selected,
                title: Text(entry.value),
                dense: true,
                onChanged: (v) {
                  if (v != null) onSelected(v);
                },
              ),
            ),
      ],
    );
  }
}
