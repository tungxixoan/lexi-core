import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../../core/widgets/save_exercise_button.dart';
import '../../../practice/domain/entities/saved_exercise.dart';
import '../../domain/entities/dictation_difficulty.dart';
import '../providers/dictation_practice_provider.dart';

class DictationResultScreen extends ConsumerStatefulWidget {
  const DictationResultScreen({super.key, required this.result});
  final DictationSessionResult result;

  @override
  ConsumerState<DictationResultScreen> createState() =>
      _DictationResultScreenState();
}

class _DictationResultScreenState extends ConsumerState<DictationResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSm2());
  }

  Future<void> _updateSm2() async {
    // Best-effort: SM-2 updates should never crash or block the result
    // screen. This wraps the whole method (including the vocab-bank fetch)
    // so a storage/permission error fetching the vocab list degrades the
    // same way a single record's update failure does, instead of
    // propagating uncaught from the fire-and-forget post-frame callback.
    try {
      final computeUseCase = ref.read(computeSm2UseCaseProvider);
      final updateUseCase = ref.read(updateVocabUseCaseProvider);
      // Resolve against the SESSION's own language, not the globally-scoped
      // vocabBankNotifierProvider (which follows userSettingsNotifierProvider's
      // targetLanguage). This screen's session may have been generated for a
      // language other than the current global setting (dictation_home_screen
      // has its own in-screen language picker), so fetching by the global
      // setting could silently miss every record and drop all SM-2 updates.
      final vocabRecords = await ref
          .read(getVocabListUseCaseProvider)
          .execute(language: widget.result.item.targetLanguage);
      final quality = widget.result.sm2Quality;

      for (final id in widget.result.item.vocabIds) {
        try {
          final record = vocabRecords.firstWhere((r) => r.id == id);
          final updated = computeUseCase.compute(record, quality);
          await updateUseCase.execute(updated);
        } catch (_) {
          // best-effort: don't let one bad record block the others
        }
      }
    } catch (_) {
      // best-effort: don't crash the result screen on an SM-2 update failure
    }

    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(widget.result.item.vocabIds.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final scorePct = (result.finalScore * 100).toStringAsFixed(0);
    final seekPenaltyPct = (result.seekPenaltyTotal * 100).toStringAsFixed(0);
    final elapsed = _formatDuration(result.duration);

    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: context.bloom.ink,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/listening/dictation');
      },
      child: BloomScaffold(
        appBar: const BloomAppBar(
          title: 'Kết quả',
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BloomStatCard(label: 'Điểm', value: '$scorePct%'),
                    ),
                    const SizedBox(width: BloomSpacing.md),
                    Expanded(
                      child: BloomStatCard(
                        label: 'Nghe lại',
                        value: '${result.replayCount}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BloomSpacing.md),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BloomStatCard(
                        label: 'Số lần tua',
                        value: '${result.seekCount} (−$seekPenaltyPct%)',
                      ),
                    ),
                    const SizedBox(width: BloomSpacing.md),
                    Expanded(
                      child: BloomStatCard(label: 'Thời gian', value: elapsed),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Bạn đã gõ', style: headerStyle),
              const SizedBox(height: 8),
              BloomCard(
                child: result.difficulty == DictationDifficulty.hard
                    ? _DiffText(
                        typed: result.typed,
                        target: result.item.target,
                        style: webScaled(theme.textTheme.bodyLarge ??
                            const TextStyle(fontSize: 16)),
                      )
                    : _ClozeResult(result: result),
              ),
              const SizedBox(height: 16),
              Text('Câu đúng', style: headerStyle),
              const SizedBox(height: 8),
              Text(
                result.item.target,
                style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 16),
              Text('Nghĩa', style: headerStyle),
              const SizedBox(height: 8),
              Text(
                result.item.vietnamese,
                style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 24),
              SaveExerciseButton(
                type: SavedExerciseType.dictation,
                reusedFromId: result.reusedFromId,
                buildPassageJson: () => result.item.toJson(),
                generationFilters: result.generationFilters ??
                    <String, dynamic>{'difficulty': result.difficulty.name},
                targetLanguage: result.item.targetLanguage,
              ),
              BloomPillButton(
                label: 'Câu khác',
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
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/listening/dictation');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(dictationPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _DiffText extends StatelessWidget {
  const _DiffText({required this.typed, required this.target, this.style});
  final String typed;
  final String target;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final spans = <TextSpan>[];
    for (int i = 0; i < typed.length; i++) {
      final correct = i < target.length && typed[i] == target[i];
      spans.add(TextSpan(
        text: typed[i],
        style: (style ?? const TextStyle()).copyWith(
          color: correct ? c.success : c.danger,
          backgroundColor: correct ? null : c.dangerBg,
        ),
      ));
    }
    return RichText(text: TextSpan(children: spans, style: style));
  }
}

class _ClozeResult extends StatelessWidget {
  const _ClozeResult({required this.result});
  final DictationSessionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.bloom;
    final baseStyle = webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16));
    final words = result.item.target
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final spans = <InlineSpan>[];
    var wordIndex = 0;
    for (var blankIdx = 0; blankIdx < result.blanks.length; blankIdx++) {
      final blank = result.blanks[blankIdx];
      if (blank.startWordIndex > wordIndex) {
        final visible = words.sublist(wordIndex, blank.startWordIndex).join(' ');
        spans.add(TextSpan(text: '$visible ', style: baseStyle));
      }
      final isCorrect = result.isBlankCorrect(blankIdx);
      final answer = result.blankAnswers[blankIdx];
      spans.add(TextSpan(
        text: answer.isEmpty ? '___' : answer,
        style: baseStyle.copyWith(
          color: isCorrect ? c.success : c.danger,
          backgroundColor: isCorrect ? null : c.dangerBg,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ));
      if (!isCorrect) {
        spans.add(TextSpan(
          text: ' (đúng: ${result.targetTextFor(blank)})',
          style: baseStyle.copyWith(
            color: c.inkSoft,
            fontStyle: FontStyle.italic,
          ),
        ));
      }
      spans.add(TextSpan(text: ' ', style: baseStyle));
      wordIndex = blank.startWordIndex + blank.wordCount;
    }
    if (wordIndex < words.length) {
      spans.add(TextSpan(text: words.sublist(wordIndex).join(' '), style: baseStyle));
    }

    return Text.rich(TextSpan(children: spans));
  }
}
