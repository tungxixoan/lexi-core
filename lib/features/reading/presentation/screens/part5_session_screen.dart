import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5SessionScreen extends ConsumerWidget {
  const Part5SessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<Part5SessionState?>>(part5PracticeNotifierProvider, (prev, next) {
      final session = next.valueOrNull;
      if (session == null) return;
      if (session.isSubmitted) {
        final result = Part5SessionResult(set: session.set, selectedAnswers: session.selectedAnswers);
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Part 5 — Điền câu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < session.set.questions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _QuestionCard(
                        index: i,
                        question: session.set.questions[i],
                        selected: session.selectedAnswers[i],
                        onSelected: (optionIndex) => notifier.selectAnswer(i, optionIndex),
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
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${index + 1}. ${question.sentenceWithBlank}',
                style: webScaled(theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)),
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
        ),
      ),
    );
  }
}
