import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
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

class _SessionScaffold extends ConsumerStatefulWidget {
  const _SessionScaffold({required this.session});
  final Part7SessionState session;

  @override
  ConsumerState<_SessionScaffold> createState() => _SessionScaffoldState();
}

class _SessionScaffoldState extends ConsumerState<_SessionScaffold> {
  int _activeGroup = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final notifier = ref.read(part7PracticeNotifierProvider.notifier);
    final group = session.set.passageGroups[_activeGroup];
    final peek = MediaQuery.sizeOf(context).height * 0.20;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/part7');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 7 — Đọc hiểu',
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        BloomGroupChips(
                          labels: [
                            for (var g = 0; g < session.set.passageGroups.length; g++)
                              'Đoạn ${g + 1}',
                          ],
                          activeIndex: _activeGroup,
                          onChanged: (i) => setState(() => _activeGroup = i),
                        ),
                        const SizedBox(height: BloomSpacing.md),
                        Expanded(
                          // A plain scroll view (not a lazy ListView): every
                          // question in the group stays laid out while it sits
                          // behind the peeking passage sheet, so reaching the
                          // last question of a long group is only a scroll.
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(bottom: peek + BloomSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var q = 0; q < group.questions.length; q++) ...[
                                  if (q > 0) const SizedBox(height: BloomSpacing.sm),
                                  _QuestionCard(
                                    question: group.questions[q],
                                    questionIndex: q,
                                    selected: session.selectedAnswers[
                                        Part7SessionState.flatIndex(
                                            session.set.passageGroups, _activeGroup, q)],
                                    onSelected: (o) => notifier.selectAnswer(_activeGroup, q, o),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  BloomPassageSheet(
                    key: ValueKey(_activeGroup),
                    tabs: group.documents.length == 2
                        ? const ['Văn bản 1', 'Văn bản 2']
                        : const ['Văn bản'],
                    passages: group.documents,
                    initialChildSize: 0.20,
                    minChildSize: 0.12,
                    maxChildSize: 0.9,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, BloomSpacing.sm, 16, BloomSpacing.md),
              child: BloomPillButton(
                label: 'Nộp bài',
                variant: BloomButtonVariant.primary,
                block: true,
                onPressed: session.canSubmit ? notifier.submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.questionIndex,
    required this.selected,
    required this.onSelected,
  });

  final Part7Question question;
  final int questionIndex;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${questionIndex + 1}. ${question.question}',
            style: webScaled(const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                .copyWith(color: context.bloom.ink),
          ),
          for (var o = 0; o < question.options.length; o++) ...[
            const SizedBox(height: BloomSpacing.sm),
            BloomMcOption(
              label: question.options[o],
              leading: String.fromCharCode(65 + o),
              onTap: () => onSelected(o),
              state: selected == o ? BloomMcState.selected : BloomMcState.neutral,
            ),
          ],
        ],
      ),
    );
  }
}
