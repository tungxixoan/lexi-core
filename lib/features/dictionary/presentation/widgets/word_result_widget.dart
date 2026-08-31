// lib/features/dictionary/presentation/widgets/word_result_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../../services/tts_service.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/user_settings_provider.dart';
import 'pronounce_button.dart';
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
    final c = context.bloom;
    final canSpeak = targetLanguage.ttsCloudCode != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: BloomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.headword,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                if (canSpeak) ...[
                  const SizedBox(width: 8),
                  PronounceButton(
                    tooltip: 'Phát âm từ',
                    onPressed: () => tts.pronounce(result.headword,
                        targetLanguage, tier: PronunciationTier.word),
                  ),
                ],
                if (result.cefrLevel != null) ...[
                  const SizedBox(width: 8),
                  BloomCefrPill(result.cefrLevel!.label),
                ],
              ],
            ),
            if (result.ipa.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(result.ipa,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: c.inkSoft)),
            ],
            const SizedBox(height: 10),
            Text(result.meaning,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            if (result.definition.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(result.definition,
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: c.inkSoft)),
            ],
            if (result.synonyms.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in result.synonyms) BloomChip(label: s),
                ],
              ),
            ],
            if (result.examples.isNotEmpty) ...[
              Divider(height: 24, color: c.border),
              for (final ex in result.examples)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(ex,
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: c.inkSoft)),
                      ),
                      if (canSpeak) ...[
                        const SizedBox(width: 8),
                        PronounceButton(
                          size: 22,
                          tooltip: 'Phát âm ví dụ',
                          onPressed: () => tts.pronounce(ex, targetLanguage,
                              tier: PronunciationTier.sentence),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            if (result.suggestedTopics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in result.suggestedTopics)
                    BloomChip(label: t, style: BloomChipStyle.topic),
                ],
              ),
            ],
            const SizedBox(height: 14),
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
    final c = context.bloom;

    final isSaved = vocabAsync.valueOrNull?.any(
          (r) =>
              r.headword.toLowerCase() == result.headword.toLowerCase() &&
              r.targetLanguage == settings.targetLanguage,
        ) ??
        false;

    if (isSaved) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: c.sage),
          const SizedBox(width: 4),
          Text('Đã lưu',
              style: TextStyle(
                  color: c.sage, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      );
    }

    return BloomPillButton(
      label: 'Lưu từ',
      block: true,
      onPressed: () async {
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SaveVocabSheet(result: result),
        );
      },
    );
  }
}
