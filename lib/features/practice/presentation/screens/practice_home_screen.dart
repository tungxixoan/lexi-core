import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeHomeScreen extends ConsumerStatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  ConsumerState<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends ConsumerState<PracticeHomeScreen> {
  String? _selectedTopicId;
  int? _wordLimit = 10; // null = All

  static const _limits = [5, 10, 20, null];
  static const _limitLabels = ['5', '10', '20', 'All'];

  Future<void> _start() async {
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          topicId: _selectedTopicId,
        );
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào để luyện tập.')),
        );
      }
      return;
    }
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    final limited = _wordLimit == null ? shuffled : shuffled.take(_wordLimit!).toList();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: limited));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Luyện tập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chủ đề', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            topicsAsync.when(
              data: (topics) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _selectedTopicId == null,
                    onSelected: (_) => setState(() => _selectedTopicId = null),
                  ),
                  ...topics.map(
                    (t) => FilterChip(
                      label: Text('${t.emoji} ${t.name}'),
                      selected: _selectedTopicId == t.id,
                      onSelected: (_) =>
                          setState(() => _selectedTopicId = t.id),
                    ),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            const SizedBox(height: 24),
            Text('Số từ mỗi session', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int?>(
              segments: List.generate(
                _limits.length,
                (i) => ButtonSegment<int?>(
                  value: _limits[i],
                  label: Text(_limitLabels[i]),
                ),
              ),
              selected: {_wordLimit},
              onSelectionChanged: (s) => setState(() => _wordLimit = s.first),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu luyện tập'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
