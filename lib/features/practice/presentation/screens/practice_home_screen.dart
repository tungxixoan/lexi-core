import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeHomeScreen extends ConsumerStatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  ConsumerState<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends ConsumerState<PracticeHomeScreen> {
  String? _selectedTopicId;
  int? _wordLimit = 10; // null = All
  CEFRLevel? _maxCefrLevel; // null = show all levels

  static const _limits = [5, 10, 20, null];
  static const _limitLabels = ['5', '10', '20', 'Tất cả'];

  @override
  void initState() {
    super.initState();
    // Initialize CEFR filter from the user's default setting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      setState(() => _maxCefrLevel = settings.targetCefrLevel);
    });
  }

  Future<void> _start() async {
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          topicId: _selectedTopicId,
          maxCefrLevel: _maxCefrLevel,
        );
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào ở cấp độ này.')),
        );
      }
      return;
    }
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    final limited =
        _wordLimit == null ? shuffled : shuffled.take(_wordLimit!).toList();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: limited));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    // CEFR segments: A1 A2 B1 B2 C1 C2 | Tất cả (null)
    final cefrSegments = <ButtonSegment<CEFRLevel?>>[
      ...CEFRLevel.values.map(
        (l) => ButtonSegment<CEFRLevel?>(value: l, label: Text(l.label)),
      ),
      const ButtonSegment<CEFRLevel?>(value: null, label: Text('Tất cả')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện tập'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: 'Tiến độ học',
            onPressed: () => context.push('/practice/progress'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Topic filter ────────────────────────────────
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
                    onSelected: (_) =>
                        setState(() => _selectedTopicId = null),
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

            // ── CEFR level filter ───────────────────────────
            Text('Cấp độ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<CEFRLevel?>(
                segments: cefrSegments,
                selected: {_maxCefrLevel},
                onSelectionChanged: (s) =>
                    setState(() => _maxCefrLevel = s.first),
              ),
            ),

            const SizedBox(height: 24),

            // ── Word limit ──────────────────────────────────
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
