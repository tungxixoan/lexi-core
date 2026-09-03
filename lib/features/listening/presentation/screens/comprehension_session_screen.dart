import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionSessionScreen extends ConsumerWidget {
  const ComprehensionSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<ListeningSessionState?>>(
      listeningComprehensionNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isSubmitted) {
          final result = ComprehensionSessionResult(
            passage: session.passage,
            selectedAnswers: session.selectedAnswers,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go('/listening/comprehension/session/result',
                  extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(listeningComprehensionNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/listening/comprehension');
          });
          return const BloomScaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isSubmitted flips to true.
        if (session.isSubmitted) {
          return const BloomScaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(session: session);
      },
      loading: () =>
          const BloomScaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BloomScaffold(
        body: Center(
          child: Text('Lỗi: $e', style: TextStyle(color: context.bloom.danger)),
        ),
      ),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({required this.session});
  final ListeningSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(listeningComprehensionNotifierProvider.notifier);
    final isFirstTurn = session.currentTurnIndex == 0;
    final isLastTurn =
        session.currentTurnIndex == session.passage.turns.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/listening/comprehension');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Nghe hiểu',
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BloomCard(
                child: Column(
                  children: [
                    Text(
                      'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}'
                      '${session.currentTurn.speaker != null ? ' — Người nói ${session.currentTurn.speaker}' : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.bloom.inkSoft,
                      ),
                    ),
                    const SizedBox(height: BloomSpacing.sm),
                    _SeekSlider(
                      passage: session.passage,
                      onSeek: notifier.seekToWord,
                    ),
                    const SizedBox(height: BloomSpacing.sm),
                    BloomAudioControls.transport(
                      isPlaying: session.isSpeaking,
                      onPlayPause: session.isSpeaking
                          ? notifier.stopPlayback
                          : notifier.playCurrentTurn,
                      onPrevious: isFirstTurn ? null : notifier.previousTurn,
                      onNext: isLastTurn ? null : notifier.nextTurn,
                      onReplay: notifier.replayFromStart,
                    ),
                    const SizedBox(height: BloomSpacing.md),
                    _SpeedSelector(
                      speed: session.speedMultiplier,
                      onChanged: notifier.setSpeed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0;
                          i < session.passage.questions.length;
                          i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        _QuestionCard(
                          index: i,
                          question: session.passage.questions[i],
                          selected: session.selectedAnswers[i],
                          onSelected: (optionIndex) =>
                              notifier.selectAnswer(i, optionIndex),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              BloomPillButton(
                label: 'Nộp bài',
                variant: BloomButtonVariant.primary,
                block: true,
                onPressed: session.canSubmit ? notifier.submit : null,
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
  final ListeningQuestion question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BloomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${index + 1}. ${question.question}',
            style: webScaled(
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))
                .copyWith(color: context.bloom.ink),
          ),
          const SizedBox(height: BloomSpacing.md),
          for (var o = 0; o < question.options.length; o++) ...[
            if (o > 0) const SizedBox(height: BloomSpacing.sm),
            BloomMcOption(
              label: question.options[o],
              leading: String.fromCharCode(65 + o),
              onTap: () => onSelected(o),
              state:
                  selected == o ? BloomMcState.selected : BloomMcState.neutral,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeekSlider extends StatefulWidget {
  const _SeekSlider({required this.passage, required this.onSeek});
  final ListeningPassage passage;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  int? _restWordIndex;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final total = totalWordsOf(widget.passage);
    if (total <= 1) return const SizedBox.shrink();
    final value = (_restWordIndex ?? 0).toDouble();
    return Column(
      children: [
        if (_isDragging && _restWordIndex != null)
          Text(_previewLabel(_restWordIndex!)),
        BloomWordSeekBar(
          value: value,
          max: (total - 1).toDouble(),
          label: 'Tua theo từ',
          onChanged: (v) => setState(() {
            _isDragging = true;
            _restWordIndex = v.round();
          }),
          onChangeEnd: (v) {
            setState(() {
              _isDragging = false;
              _restWordIndex = v.round();
            });
            widget.onSeek(v.round());
          },
        ),
      ],
    );
  }

  String _previewLabel(int globalWordIndex) {
    var remaining = globalWordIndex;
    for (var t = 0; t < widget.passage.turns.length; t++) {
      final wordCount = widget.passage.turns[t].text
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .length;
      if (remaining < wordCount) {
        return 'Lượt ${t + 1}/${widget.passage.turns.length} · Từ ${remaining + 1}/$wordCount';
      }
      remaining -= wordCount;
    }
    return '';
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 0.75, label: Text('0.75x')),
        ButtonSegment(value: 1.0, label: Text('1x')),
        ButtonSegment(value: 1.25, label: Text('1.25x')),
      ],
      selected: {speed},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}
