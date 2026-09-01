import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
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

class _SessionScaffold extends ConsumerStatefulWidget {
  const _SessionScaffold({required this.session});
  final Part6SessionState session;

  @override
  ConsumerState<_SessionScaffold> createState() => _SessionScaffoldState();
}

class _SessionScaffoldState extends ConsumerState<_SessionScaffold> {
  int _activePassage = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final notifier = ref.read(part6PracticeNotifierProvider.notifier);
    final passage = session.set.passages[_activePassage];
    final peek = MediaQuery.sizeOf(context).height * 0.16;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/part6');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Part 6 — Điền đoạn văn',
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
                            for (var p = 0; p < session.set.passages.length; p++)
                              'Đoạn ${p + 1}',
                          ],
                          activeIndex: _activePassage,
                          onChanged: (i) => setState(() => _activePassage = i),
                        ),
                        const SizedBox(height: BloomSpacing.md),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.only(bottom: peek + BloomSpacing.md),
                            children: [
                              for (var q = 0; q < passage.questions.length; q++) ...[
                                if (q > 0) const SizedBox(height: BloomSpacing.sm),
                                _BlankTile(
                                  key: ValueKey('$_activePassage-$q'),
                                  question: passage.questions[q],
                                  questionIndex: q,
                                  selected: session.selectedAnswers[
                                      Part6SessionState.flatIndex(_activePassage, q)],
                                  onSelected: (o) =>
                                      notifier.selectAnswer(_activePassage, q, o),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  BloomPassageSheet(
                    key: ValueKey(_activePassage),
                    tabs: const ['Văn bản'],
                    passages: [passage.passageText],
                    initialChildSize: 0.16,
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

class _BlankTile extends StatelessWidget {
  const _BlankTile({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.selected,
    required this.onSelected,
  });

  final Part6Question question;
  final int questionIndex;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final q = questionIndex;
    return BloomExpansionTile(
      title: 'Chỗ trống (${q + 1})',
      answered: selected != null,
      summary: selected == null
          ? 'Chưa trả lời'
          : 'Đã chọn: ${question.options[selected!]}',
      initiallyExpanded: selected == null && q == 0,
      child: Column(
        children: [
          for (var o = 0; o < question.options.length; o++) ...[
            if (o > 0) const SizedBox(height: BloomSpacing.sm),
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
