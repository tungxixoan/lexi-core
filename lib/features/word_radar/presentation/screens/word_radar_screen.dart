import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final records = ref.read(wordRadarNotifierProvider).knownRecords ?? const [];
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
    final textLength = _controller.text.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét từ vựng'),
        leading: BackButton(onPressed: () => context.go('/practice')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            maxLines: 8,
            maxLength: _maxInputLength,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Dán văn bản vào đây...',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: textLength == 0 ? null : _scan,
              child: const Text('Quét'),
            ),
          ),
          const SizedBox(height: 24),
          if (radarState.knownRecords != null) ...[
            Text('Văn bản', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _HighlightedText(
              text: _controller.text,
              highlights: radarState.knownRecords!.map((r) => r.headword).toList(),
              onTapHighlight: _openKnownWord,
              style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
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
    final aiResult = radarState.aiResult;
    if (aiResult == null) {
      return const Text('Bật AI trong Cài đặt để nhận gợi ý từ mới.');
    }
    return aiResult.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Không tải được gợi ý: $e'),
          TextButton(
            onPressed: () => ref
                .read(wordRadarNotifierProvider.notifier)
                .retrySuggestions(_controller.text),
            child: const Text('Thử lại'),
          ),
        ],
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
          Text('Bản dịch', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _HighlightedText(
            text: result.translation,
            highlights: knownMeanings,
            style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
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
    if (highlights.isEmpty || text.isEmpty) {
      return Text(text, style: style);
    }
    final highlightStyle = (style ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
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
        spans.add(TextSpan(text: remaining));
        break;
      }
      if (earliestStart > 0) {
        spans.add(TextSpan(text: remaining.substring(0, earliestStart)));
      }
      final matchedText =
          remaining.substring(earliestStart, earliestStart + earliestWord.length);
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
