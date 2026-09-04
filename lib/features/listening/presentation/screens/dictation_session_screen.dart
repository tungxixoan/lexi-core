import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/blank_span.dart';
import '../providers/dictation_practice_provider.dart';

class DictationSessionScreen extends ConsumerStatefulWidget {
  const DictationSessionScreen({super.key});

  @override
  ConsumerState<DictationSessionScreen> createState() =>
      _DictationSessionScreenState();
}

class _DictationSessionScreenState
    extends ConsumerState<DictationSessionScreen> {
  late final TextEditingController _ctrl;
  List<TextEditingController>? _blankCtrls;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _blankCtrls?.forEach((c) => c.dispose());
    super.dispose();
  }

  /// Lazily creates one controller per blank, once per screen lifetime —
  /// blanks never change after generation, so these stay stable across
  /// rebuilds (unlike constructing a fresh controller in build(), which
  /// would reset the user's cursor/focus on every keystroke).
  List<TextEditingController> _blankControllersFor(
      DictationSessionState session) {
    _blankCtrls ??= List.generate(
      session.blanks.length,
      (i) => TextEditingController(text: session.blankAnswers[i]),
    );
    return _blankCtrls!;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DictationSessionState?>>(
      dictationPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        if (session.isComplete) {
          final result = DictationSessionResult(
            item: session.item,
            typed: session.typedText,
            replayCount: session.replayCount,
            duration: DateTime.now().difference(session.startedAt),
            difficulty: session.difficulty,
            blanks: session.blanks,
            blankAnswers: session.blankAnswers,
            seekCount: session.seekCount,
            seekPenaltyTotal: session.seekPenaltyTotal,
            reusedFromId: session.reusedFromId,
            generationFilters: session.generationFilters,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/listening/dictation/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/listening/dictation');
          });
          return const BloomScaffold(body: SizedBox.shrink());
        }
        // Safety guard: navigation to the result route is already scheduled
        // via ref.listen above once isComplete flips to true.
        if (session.isComplete) {
          return const BloomScaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(
          session: session,
          ctrl: _ctrl,
          blankCtrls:
              session.isClozeMode ? _blankControllersFor(session) : const [],
        );
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
  const _SessionScaffold({
    required this.session,
    required this.ctrl,
    required this.blankCtrls,
  });

  final DictationSessionState session;
  final TextEditingController ctrl;
  final List<TextEditingController> blankCtrls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(dictationPracticeNotifierProvider.notifier);
    final canSubmit = session.hasPlayedOnce &&
        (session.isClozeMode
            ? session.allBlanksFilled
            : session.typedText.trim().isNotEmpty);

    final wordCount = session.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/listening/dictation');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Nghe chép',
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              BloomCard(
                child: Column(
                  children: [
                    BloomAudioControls.playOnly(
                      isPlaying: false,
                      onPlayPause: notifier.play,
                      playLabel: session.hasPlayedOnce
                          ? 'Nghe lại (${session.replayCount})'
                          : 'Phát',
                    ),
                    const SizedBox(height: BloomSpacing.md),
                    Center(
                      child: _SpeedSelector(
                        speed: session.speedMultiplier,
                        onChanged: notifier.setSpeed,
                      ),
                    ),
                    const SizedBox(height: BloomSpacing.md),
                    _SeekSlider(totalWords: wordCount, onSeek: notifier.seekTo),
                  ],
                ),
              ),
              const SizedBox(height: BloomSpacing.xxl),
              if (session.isClozeMode)
                _ClozeInput(
                  target: session.item.target,
                  blanks: session.blanks,
                  controllers: blankCtrls,
                  onBlankChanged: notifier.updateBlankAnswer,
                )
              else
                TextField(
                  controller: ctrl,
                  maxLines: null,
                  cursorColor: context.bloom.accent,
                  style: webScaled(
                    TextStyle(
                      fontFamilyFallback: const [
                        'ui-monospace',
                        'SF Mono',
                        'Menlo',
                        'monospace',
                      ],
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 18,
                      color: context.bloom.ink,
                    ),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.bloom.surface2,
                    hintText: 'Gõ lại những gì bạn nghe được...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BloomRadii.md),
                      borderSide: BorderSide(color: context.bloom.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BloomRadii.md),
                      borderSide: BorderSide(color: context.bloom.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BloomRadii.md),
                      borderSide: BorderSide(color: context.bloom.accent),
                    ),
                  ),
                  onChanged: notifier.updateTypedText,
                ),
              const Spacer(),
              BloomPillButton(
                label: 'Nộp bài',
                variant: BloomButtonVariant.primary,
                block: true,
                onPressed: canSubmit ? notifier.submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders [target] with each [blanks] entry replaced by an inline editable
/// text field, and everything else as plain visible text — a cloze
/// (fill-in-the-blank) layout for Dễ/Trung bình.
class _ClozeInput extends StatelessWidget {
  const _ClozeInput({
    required this.target,
    required this.blanks,
    required this.controllers,
    required this.onBlankChanged,
  });

  final String target;
  final List<BlankSpan> blanks;
  final List<TextEditingController> controllers;
  final void Function(int blankIndex, String text) onBlankChanged;

  @override
  Widget build(BuildContext context) {
    final words =
        target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final theme = Theme.of(context);
    final baseStyle =
        webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16));
    final fieldStyle = baseStyle.copyWith(
      fontFamilyFallback: const [
        'ui-monospace',
        'SF Mono',
        'Menlo',
        'monospace'
      ],
      fontFeatures: const [FontFeature.tabularFigures()],
      color: context.bloom.ink,
    );

    final children = <Widget>[];
    var wordIndex = 0;
    for (var blankIdx = 0; blankIdx < blanks.length; blankIdx++) {
      final blank = blanks[blankIdx];
      if (blank.startWordIndex > wordIndex) {
        final visible =
            words.sublist(wordIndex, blank.startWordIndex).join(' ');
        children.add(Text('$visible ', style: baseStyle));
      }
      children.add(
        IntrinsicWidth(
          child: TextField(
            key: ValueKey('blank-$blankIdx'),
            controller: controllers[blankIdx],
            style: fieldStyle,
            textAlign: TextAlign.center,
            cursorColor: context.bloom.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: context.bloom.surface2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BloomRadii.sm),
                borderSide: BorderSide(color: context.bloom.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BloomRadii.sm),
                borderSide: BorderSide(color: context.bloom.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BloomRadii.sm),
                borderSide: BorderSide(color: context.bloom.accent),
              ),
            ),
            onChanged: (text) => onBlankChanged(blankIdx, text),
          ),
        ),
      );
      children.add(const Text(' '));
      wordIndex = blank.startWordIndex + blank.wordCount;
    }
    if (wordIndex < words.length) {
      children.add(Text(words.sublist(wordIndex).join(' '), style: baseStyle));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

class _SeekSlider extends StatefulWidget {
  const _SeekSlider({required this.totalWords, required this.onSeek});
  final int totalWords;
  final ValueChanged<int> onSeek;

  @override
  State<_SeekSlider> createState() => _SeekSliderState();
}

class _SeekSliderState extends State<_SeekSlider> {
  int? _restWordIndex;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    if (widget.totalWords <= 1) return const SizedBox.shrink();
    final value = (_restWordIndex ?? 0).toDouble();
    return Column(
      children: [
        if (_isDragging && _restWordIndex != null)
          Text('Từ ${_restWordIndex! + 1}/${widget.totalWords}'),
        BloomWordSeekBar(
          value: value,
          max: (widget.totalWords - 1).toDouble(),
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
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) =>
      BloomSpeedSlider(value: speed, onChanged: onChanged);
}
