import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/word_radar_ai_result.dart';
import '../providers/word_radar_provider.dart';
import '../widgets/vocab_suggestions_section.dart';

const _maxInputLength = 3000;

class WordRadarScreen extends ConsumerStatefulWidget {
  const WordRadarScreen({super.key});

  @override
  ConsumerState<WordRadarScreen> createState() => _WordRadarScreenState();
}

class _WordRadarScreenState extends ConsumerState<WordRadarScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() {
    return ref.read(wordRadarNotifierProvider.notifier).scan(_controller.text);
  }

  void _openKnownWord(String headword) {
    final records =
        ref.read(wordRadarNotifierProvider).knownRecords ?? const [];
    for (final record in records) {
      if (record.headword == headword) {
        context.push('/vocab/${record.id}');
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final radarState = ref.watch(wordRadarNotifierProvider);
    final theme = Theme.of(context);
    final c = context.bloom;
    final textLength = _controller.text.length;

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Quét từ vựng',
        leading: BloomIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => context.go('/practice'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BloomTextField(
                  controller: _controller,
                  hintText: 'Dán văn bản vào đây...',
                  maxLines: 8,
                  minLines: 6,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxInputLength),
                  ],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: BloomSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_controller.text.characters.length}/$_maxInputLength',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.inkFaint,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: BloomSpacing.md),
          SizedBox(
            width: double.infinity,
            child: BloomPillButton(
              label: 'Quét',
              icon: Icons.radar,
              variant: BloomButtonVariant.primary,
              block: true,
              onPressed: textLength == 0 ? null : _scan,
            ),
          ),
          const SizedBox(height: 24),
          if (radarState.knownRecords != null) ...[
            BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BloomSectionHeader('Văn bản'),
                  const SizedBox(height: 8),
                  _HighlightedText(
                    text: _controller.text,
                    highlights: radarState.knownRecords!
                        .map((r) => r.headword)
                        .toList(),
                    onTapHighlight: _openKnownWord,
                    style: webScaled(
                      theme.textTheme.bodyLarge ??
                          const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildAiSection(radarState),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSection(WordRadarState radarState) {
    final theme = Theme.of(context);
    final c = context.bloom;
    final aiResult = radarState.aiResult;
    if (aiResult == null) {
      return Container(
        padding: const EdgeInsets.all(BloomSpacing.md),
        decoration: BoxDecoration(
          color: c.amberBg,
          borderRadius: BorderRadius.circular(BloomRadii.md),
        ),
        child: Text(
          'Bật AI trong Cài đặt để nhận gợi ý từ mới.',
          style: TextStyle(color: c.amber, fontWeight: FontWeight.w600),
        ),
      );
    }
    return aiResult.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => BloomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Không tải được gợi ý: $e',
              style: TextStyle(color: c.danger),
            ),
            const SizedBox(height: BloomSpacing.md),
            BloomPillButton(
              label: 'Thử lại',
              variant: BloomButtonVariant.secondary,
              onPressed: () => ref
                  .read(wordRadarNotifierProvider.notifier)
                  .retrySuggestions(_controller.text),
            ),
          ],
        ),
      ),
      data: (result) => _buildAiResult(result, radarState, theme),
    );
  }

  Widget _buildAiResult(
    WordRadarAiResult result,
    WordRadarState radarState,
    ThemeData theme,
  ) {
    final knownMeanings = (radarState.knownRecords ?? const [])
        .map((r) => r.meaning)
        .where((m) => m.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.translation.isNotEmpty) ...[
          BloomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BloomSectionHeader('Bản dịch'),
                const SizedBox(height: 8),
                _HighlightedText(
                  text: result.translation,
                  highlights: knownMeanings,
                  style: webScaled(
                    theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        VocabSuggestionsSection(suggestions: result.suggestions),
      ],
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    this.onTapHighlight,
    this.style,
  });

  final String text;
  final List<String> highlights;
  final void Function(String matched)? onTapHighlight;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final baseStyle = (style ?? const TextStyle()).copyWith(color: c.ink);
    if (highlights.isEmpty || text.isEmpty) {
      return Text(text, style: baseStyle);
    }
    final highlightStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: c.sage,
      backgroundColor: c.sageBg,
    );
    final spans = <InlineSpan>[];
    String remaining = text;
    while (remaining.isNotEmpty) {
      int? earliestStart;
      String? earliestWord;
      for (final word in highlights) {
        if (word.isEmpty) continue;
        final idx = remaining.toLowerCase().indexOf(word.toLowerCase());
        if (idx >= 0 && (earliestStart == null || idx < earliestStart)) {
          earliestStart = idx;
          earliestWord = word;
        }
      }
      if (earliestStart == null || earliestWord == null) {
        spans.add(TextSpan(text: remaining, style: baseStyle));
        break;
      }
      if (earliestStart > 0) {
        spans.add(
          TextSpan(
              text: remaining.substring(0, earliestStart), style: baseStyle),
        );
      }
      final matchedText = remaining.substring(
          earliestStart, earliestStart + earliestWord.length);
      final tappedWord = earliestWord;
      final onTap = onTapHighlight;
      spans.add(
        onTap == null
            ? TextSpan(text: matchedText, style: highlightStyle)
            : WidgetSpan(
                child: GestureDetector(
                  onTap: () => onTap(tappedWord),
                  child: Text(matchedText, style: highlightStyle),
                ),
              ),
      );
      remaining = remaining.substring(earliestStart + earliestWord.length);
    }
    return Text.rich(TextSpan(children: spans));
  }
}
