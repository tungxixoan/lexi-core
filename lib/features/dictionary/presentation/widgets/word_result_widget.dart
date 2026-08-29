// lib/features/dictionary/presentation/widgets/word_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';
import 'save_vocab_sheet.dart';

class WordResultWidget extends ConsumerWidget {
  const WordResultWidget({super.key, required this.result});

  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.headword,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (targetLanguage.ttsCloudCode != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Pronounce word',
                    onPressed: () => tts.pronounce(result.headword, targetLanguage,
                        tier: PronunciationTier.word),
                  ),
              ],
            ),
            if (result.ipa.isNotEmpty)
              Text(
                result.ipa,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            Text(result.meaning, style: theme.textTheme.bodyLarge),
            if (result.definition.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                result.definition,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (result.synonyms.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result.synonyms
                    .map((s) => Chip(
                          label: Text(s, style: theme.textTheme.bodySmall),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
                        ))
                    .toList(),
              ),
            ],
            if (result.examples.isNotEmpty) ...[
              const Divider(height: 24),
              ...result.examples.map(
                (ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ex,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                      if (targetLanguage.ttsCloudCode != null)
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 18),
                          tooltip: 'Pronounce example',
                          onPressed: () =>
                              tts.pronounce(ex, targetLanguage, tier: PronunciationTier.sentence),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (result.suggestedTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: result.suggestedTopics
                    .map((t) => Chip(
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            _SaveButton(result: result),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.result});
  final WordPhraseResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final settings = ref.read(userSettingsNotifierProvider);

    final isSaved = vocabAsync.valueOrNull?.any(
          (r) =>
              r.headword.toLowerCase() == result.headword.toLowerCase() &&
              r.targetLanguage == settings.targetLanguage,
        ) ??
        false;

    if (isSaved) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
          SizedBox(width: 4),
          Text('Saved', style: TextStyle(color: Colors.green, fontSize: 13)),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
        label: const Text('Save'),
        onPressed: () async {
          await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SaveVocabSheet(result: result),
          );
        },
      ),
    );
  }
}
