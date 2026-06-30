// lib/features/dictionary/presentation/widgets/word_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

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
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Pronounce word',
                  onPressed: () => tts.speak(result.headword, targetLanguage),
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
                      IconButton(
                        icon: const Icon(Icons.volume_up, size: 18),
                        tooltip: 'Pronounce example',
                        onPressed: () => tts.speak(ex, targetLanguage),
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
          ],
        ),
      ),
    );
  }
}
