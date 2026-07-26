import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/save_vocab_sheet.dart';
import '../providers/word_radar_provider.dart';

const _maxInputLength = 3000;

class WordRadarScreen extends ConsumerStatefulWidget {
  const WordRadarScreen({super.key});

  @override
  ConsumerState<WordRadarScreen> createState() => _WordRadarScreenState();
}

class _WordRadarScreenState extends ConsumerState<WordRadarScreen> {
  final _controller = TextEditingController();
  final Set<String> _savedHeadwords = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() {
    return ref.read(wordRadarNotifierProvider.notifier).scan(_controller.text);
  }

  Future<void> _openSaveSheet(WordPhraseResult suggestion) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SaveVocabSheet(result: suggestion),
    );
    if (saved == true) {
      setState(() => _savedHeadwords.add(suggestion.headword));
    }
  }

  Future<void> _openKnownWord(String headword) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final repo = ref.read(vocabRepositoryProvider);
    final record = await repo.getByHeadword(headword, settings.targetLanguage);
    if (record != null && mounted) {
      context.push('/vocab/${record.id}');
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
          if (radarState.knownHeadwords != null) ...[
            Text('Văn bản', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _HighlightedText(
              text: _controller.text,
              highlights: radarState.knownHeadwords!,
              onTapHighlight: _openKnownWord,
            ),
            const SizedBox(height: 24),
            Text('Gợi ý từ mới', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _buildSuggestions(radarState),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestions(WordRadarState radarState) {
    final suggestions = radarState.suggestions;
    if (suggestions == null) {
      return const Text('Bật AI trong Cài đặt để nhận gợi ý từ mới.');
    }
    return suggestions.when(
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
      data: (list) {
        if (list.isEmpty) return const Text('Không có gợi ý mới.');
        return Column(
          children: list
              .map(
                (s) => Card(
                  child: ListTile(
                    title: Text(s.headword),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${s.ipa}  •  ${s.meaning}'),
                        if (s.cefrLevel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Chip(
                              label: Text(s.cefrLevel!.label),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    trailing: _savedHeadwords.contains(s.headword)
                        ? const Text('Đã lưu')
                        : TextButton(
                            onPressed: () => _openSaveSheet(s),
                            child: const Text('Lưu'),
                          ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    required this.onTapHighlight,
  });

  final String text;
  final List<String> highlights;
  final void Function(String headword) onTapHighlight;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty || text.isEmpty) {
      return Text(text);
    }
    const highlightStyle = TextStyle(
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
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => onTapHighlight(tappedWord),
          child: Text(matchedText, style: highlightStyle),
        ),
      ));
      remaining = remaining.substring(earliestStart + earliestWord.length);
    }
    return Text.rich(TextSpan(children: spans));
  }
}
