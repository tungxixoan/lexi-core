import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/part7_passage.dart';
import '../providers/part7_practice_provider.dart';

class Part7SessionScreen extends ConsumerWidget {
  const Part7SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part7SessionState?>>(part7PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part7SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/reading/part7/session/result', extra: result);
          }
        });
      }
    });

    final sessionAsync = ref.watch(part7PracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/reading/part7');
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
  final Part7SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(part7PracticeNotifierProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Part 7 — Đọc hiểu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var g = 0; g < session.set.passageGroups.length; g++) ...[
                      if (g > 0) const SizedBox(height: 16),
                      _PassageGroupCard(
                        groupIndex: g,
                        group: session.set.passageGroups[g],
                        allGroups: session.set.passageGroups,
                        selectedAnswers: session.selectedAnswers,
                        onSelected: (questionIndex, optionIndex) =>
                            notifier.selectAnswer(g, questionIndex, optionIndex),
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

class _PassageGroupCard extends StatelessWidget {
  const _PassageGroupCard({
    required this.groupIndex,
    required this.group,
    required this.allGroups,
    required this.selectedAnswers,
    required this.onSelected,
  });

  final int groupIndex;
  final Part7PassageGroup group;
  final List<Part7PassageGroup> allGroups;
  final List<int?> selectedAnswers;
  final void Function(int questionIndex, int optionIndex) onSelected;

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
              style: theme.textTheme.titleSmall,
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
            for (var q = 0; q < group.questions.length; q++) ...[
              if (q > 0) const Divider(height: 1),
              _QuestionGroup(
                questionNumber: q + 1,
                question: group.questions[q],
                selected: selectedAnswers[Part7SessionState.flatIndex(allGroups, groupIndex, q)],
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
    required this.questionNumber,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  final int questionNumber;
  final Part7Question question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            '$questionNumber. ${question.question}',
            style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
          ),
        ),
        ...question.options.asMap().entries.map(
              (entry) => RadioListTile<int>(
                value: entry.key,
                groupValue: selected,
                title: Text(
                  entry.value,
                  style: webScaled(theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)),
                ),
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
