import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/save_vocab_sheet.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/word_radar_ai_result.dart';
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
  final Set<String> _dismissedHeadwords = {};

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
    if (mounted && saved == true) {
      setState(() => _savedHeadwords.add(suggestion.headword));
    }
  }

  /// Best-effort bulk save: builds each record the same way [SaveVocabSheet]
  /// would with its defaults (no per-item editing UI), skipping any that
  /// fail (e.g. a duplicate headword already in the Vocab Bank) so one bad
  /// item doesn't block the rest of the batch.
  Future<void> _saveAll(List<WordPhraseResult> suggestions) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final topics = await ref.read(topicsNotifierProvider.future);
    final toSave = suggestions
        .where((s) =>
            !_savedHeadwords.contains(s.headword) &&
            !_dismissedHeadwords.contains(s.headword))
        .toList();

    var savedCount = 0;
    for (final s in toSave) {
      final topicIds = <String>[];
      for (final suggestedTopic in s.suggestedTopics) {
        final match =
            topics.where((t) => t.name.toLowerCase() == suggestedTopic.toLowerCase());
        if (match.isNotEmpty && topicIds.length < 2) {
          topicIds.add(match.first.id);
        }
      }
      final record = VocabRecord(
        id: const Uuid().v4(),
        headword: s.headword,
        inputType: s.inputType,
        ipa: s.ipa,
        meaning: s.meaning,
        examples: s.examples,
        personalNotes: '',
        topicIds: topicIds,
        targetLanguage: settings.targetLanguage,
        cefrLevel: s.cefrLevel ?? CEFRLevel.b1,
        activeContext: settings.activeContext,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        definition: s.definition,
        synonyms: s.synonyms,
      );
      try {
        await ref.read(vocabBankNotifierProvider.notifier).save(record);
        savedCount++;
        if (mounted) setState(() => _savedHeadwords.add(s.headword));
      } catch (_) {
        // Likely a duplicate headword — skip it, keep saving the rest.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã lưu $savedCount/${toSave.length} từ.')),
      );
    }
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
    final visibleSuggestions = result.suggestions
        .where((s) => !_dismissedHeadwords.contains(s.headword))
        .toList();
    final hasUnsaved =
        visibleSuggestions.any((s) => !_savedHeadwords.contains(s.headword));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.translation.isNotEmpty) ...[
          Text('Bản dịch', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _HighlightedText(
            text: result.translation,
            highlights: knownMeanings,
          ),
          const SizedBox(height: 24),
        ],
        Row(
          children: [
            Text('Gợi ý từ mới', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (hasUnsaved)
              TextButton.icon(
                onPressed: () => _saveAll(visibleSuggestions),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Lưu tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (visibleSuggestions.isEmpty)
          const Text('Không có gợi ý mới.')
        else
          Column(
            children: visibleSuggestions.map((s) {
              final isSaved = _savedHeadwords.contains(s.headword);
              return Card(
                child: ListTile(
                  onTap: isSaved ? null : () => _openSaveSheet(s),
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
                  trailing: isSaved
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Bỏ qua gợi ý này',
                          onPressed: () =>
                              setState(() => _dismissedHeadwords.add(s.headword)),
                        ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    this.onTapHighlight,
  });

  final String text;
  final List<String> highlights;
  final void Function(String matched)? onTapHighlight;

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
