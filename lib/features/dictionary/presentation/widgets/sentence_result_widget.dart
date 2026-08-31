// lib/features/dictionary/presentation/widgets/sentence_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';
import 'pronounce_button.dart';

class SentenceResultWidget extends ConsumerWidget {
  const SentenceResultWidget({super.key, required this.result});

  final SentenceResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final tts = ref.read(ttsServiceProvider);
    final c = context.bloom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: BloomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(result.original,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (targetLanguage.ttsCloudCode != null) ...[
                  const SizedBox(width: 8),
                  PronounceButton(
                    tooltip: 'Phát âm câu',
                    onPressed: () => tts.pronounce(result.original,
                        targetLanguage, tier: PronunciationTier.sentence),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(result.translation,
                style: TextStyle(fontSize: 18, color: c.inkSoft)),
          ],
        ),
      ),
    );
  }
}
