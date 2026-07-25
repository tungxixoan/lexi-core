import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
              context.go('/listening/comprehension/session/result', extra: result);
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
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isSubmitted flips to true.
        if (session.isSubmitted) {
          return const Scaffold(body: SizedBox.shrink());
        }
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
  final ListeningSessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(listeningComprehensionNotifierProvider.notifier);
    final turn = session.currentTurn;
    final isFirstTurn = session.currentTurnIndex == 0;
    final isLastTurn = session.currentTurnIndex == session.passage.turns.length - 1;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nghe hiểu'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Lượt ${session.currentTurnIndex + 1}/${session.passage.turns.length}'
                      '${turn.speaker != null ? ' — Người nói ${turn.speaker}' : ''}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _SeekSlider(passage: session.passage, onSeek: notifier.seekToWord),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: isFirstTurn ? null : notifier.previousTurn,
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: Icon(
                            session.isSpeaking ? Icons.stop_circle : Icons.play_circle,
                          ),
                          onPressed: session.isSpeaking
                              ? notifier.stopPlayback
                              : notifier.playCurrentTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: isLastTurn ? null : notifier.nextTurn,
                        ),
                        IconButton(
                          icon: const Icon(Icons.replay),
                          onPressed: notifier.replayFromStart,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SpeedSelector(
                      speed: session.speedMultiplier,
                      onChanged: notifier.setSpeed,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < session.passage.questions.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _QuestionCard(
                        index: i,
                        question: session.passage.questions[i],
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
  final ListeningQuestion question;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${index + 1}. ${question.question}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
        ),
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
        if (_isDragging && _restWordIndex != null) Text(_previewLabel(_restWordIndex!)),
        Slider(
          value: value,
          min: 0,
          max: (total - 1).toDouble(),
          divisions: total - 1,
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
