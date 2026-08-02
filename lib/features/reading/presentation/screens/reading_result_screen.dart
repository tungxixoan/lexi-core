import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends ConsumerStatefulWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  ConsumerState<ReadingResultScreen> createState() => _ReadingResultScreenState();
}

class _ReadingResultScreenState extends ConsumerState<ReadingResultScreen> {
  ReadingSessionResult get result => widget.result;

  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.vocabIds.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: result.passage.fullText,
            targetLanguage: result.passage.targetLanguage,
            targetCefrLevel: result.passage.level,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }

  @override
  Widget build(BuildContext context) {
    final vocabRecords = ref.watch(vocabBankProvider);
    final theme = Theme.of(context);

    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);
    final scorePct = (result.finalScore * 100).toStringAsFixed(1);

    final usedRecords = result.passage.vocabIds
        .map((id) => vocabRecords.where((r) => r.id == id).firstOrNull)
        .whereType<VocabRecord>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép đoạn văn',
            onPressed: () => _copyPassage(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(label: 'Độ chính xác', value: '$accuracyPct%'),
                _StatCard(label: 'Tốc độ', value: '$wpm WPM'),
                _StatCard(label: 'Thời gian', value: elapsed),
                _StatCard(label: 'Điểm', value: '$scorePct%'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (usedRecords.isNotEmpty) ...[
                      Text('Từ vựng đã luyện', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: usedRecords.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final record = usedRecords[i];
                          return ListTile(
                            title: Text(record.headword),
                            subtitle: Text(
                              record.meaning,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            dense: true,
                          );
                        },
                      ),
                    ],
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            FilledButton(
              onPressed: () => _regenerate(context, ref),
              child: const Text('Sinh bài mới'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _goHome(context, ref),
              child: const Text('Về trang chính'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(
              onPressed: _loadSuggestions,
              child: const Text('Thử lại'),
            ),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }

  void _copyPassage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.passage.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép đoạn văn.')),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
