import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/reading_practice_provider.dart';

class ReadingHomeScreen extends ConsumerWidget {
  const ReadingHomeScreen({super.key});

  static const _minVocabWords = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final vocabItems = ref.watch(vocabBankProvider);
    final sessionAsync = ref.watch(readingPracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đọc & gõ'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI tạo một đoạn văn song ngữ từ Vocab Bank của bạn. '
              'Đọc đoạn văn bằng ngôn ngữ mục tiêu, sau đó gõ lại từng câu.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Ngôn ngữ', value: settings.targetLanguage.label),
            _InfoRow(
              label: 'Cấp độ',
              value: settings.targetCefrLevel?.label ?? 'Tất cả',
            ),
            _InfoRow(
              label: 'Ngữ cảnh',
              value: settings.activeContext.label,
            ),
            const SizedBox(height: 32),
            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (vocabItems.length < _minVocabWords)
              _ErrorCard(
                message:
                    'Hãy lưu ít nhất 5 từ vào Vocab Bank để dùng tính năng này. '
                    'Hiện có ${vocabItems.length} từ.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo bài luyện'),
                ),
                loading: () => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang tạo bài...'),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lỗi tạo bài: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final vocabItems = ref.read(vocabBankProvider);

    final sorted = [...vocabItems]..sort((a, b) {
        final aDue = a.nextReviewAt == null ||
            a.nextReviewAt!.isBefore(DateTime.now());
        final bDue = b.nextReviewAt == null ||
            b.nextReviewAt!.isBefore(DateTime.now());
        if (aDue && !bDue) return -1;
        if (!aDue && bDue) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final words = sorted.take(10).toList().cast<VocabRecord>();

    await ref.read(readingPracticeNotifierProvider.notifier).generate(
          words: words,
          level: settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: settings.targetLanguage,
        );

    if (context.mounted) {
      final session = ref.read(readingPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/reading/session');
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
