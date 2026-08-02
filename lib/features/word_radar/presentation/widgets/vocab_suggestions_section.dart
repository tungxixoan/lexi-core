import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../dictionary/domain/entities/lookup_result.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../dictionary/presentation/widgets/save_vocab_sheet.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';

/// Tap-to-save cards for AI-suggested new vocabulary, with a "Lưu tất cả"
/// bulk-save button and a per-card dismiss (X) button. Shared by Word Radar
/// and by any screen offering the same "suggest new words from this text"
/// flow (Reading and Comprehension result screens).
class VocabSuggestionsSection extends ConsumerStatefulWidget {
  const VocabSuggestionsSection({super.key, required this.suggestions});
  final List<WordPhraseResult> suggestions;

  @override
  ConsumerState<VocabSuggestionsSection> createState() =>
      _VocabSuggestionsSectionState();
}

class _VocabSuggestionsSectionState extends ConsumerState<VocabSuggestionsSection> {
  final Set<String> _savedHeadwords = {};
  final Set<String> _dismissedHeadwords = {};

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleSuggestions = widget.suggestions
        .where((s) => !_dismissedHeadwords.contains(s.headword))
        .toList();
    final hasUnsaved =
        visibleSuggestions.any((s) => !_savedHeadwords.contains(s.headword));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
