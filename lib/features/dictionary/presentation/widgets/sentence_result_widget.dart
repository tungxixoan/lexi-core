// lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';

class SentenceResultWidget extends ConsumerWidget {
  const SentenceResultWidget({super.key, required this.result});

  final SentenceResult result;

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
                    result.original,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                if (targetLanguage.ttsCloudCode != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Pronounce sentence',
                    onPressed: () => tts.pronounce(result.original, targetLanguage,
                        tier: PronunciationTier.sentence),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              result.translation,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
