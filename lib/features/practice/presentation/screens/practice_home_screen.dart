import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/topic.dart';
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
  int _dueCount = 0;

  static const _limits = [5, 10, 20, null];
  static const _limitLabels = ['5', '10', '20', 'Tất cả'];

  @override
  void initState() {
    super.initState();
    // Initialize CEFR filter from the user's default setting, and load due count
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      setState(() => _maxCefrLevel = settings.targetCefrLevel);
      try {
        final stats = await ref
            .read(statsServiceProvider)
            .computeStats(settings.targetLanguage);
        if (!mounted) return;
        setState(() => _dueCount = stats.dueCount);
      } catch (_) {
        // Best-effort: leave _dueCount at its initial 0 on failure.
      }
    });
  }

  Future<void> _pickTopic(List<Topic> topics) async {
    final result = await showSingleSelectSheet<String?>(
      context: context,
      title: 'Chủ đề',
      options: [
        const SelectOption<String?>(value: null, label: 'Tất cả'),
        ...topics.map(
            (t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji)),
      ],
      selected: _selectedTopicId,
    );
    if (result != null) {
      setState(() => _selectedTopicId = result.value);
    }
  }

  Future<void> _pickLevel() async {
    final result = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Cấp độ',
      options: [
        ...CEFRLevel.values.map((l) => SelectOption(value: l, label: l.label)),
        const SelectOption<CEFRLevel?>(value: null, label: 'Tất cả'),
      ],
      selected: _maxCefrLevel,
    );
    if (result != null) {
      setState(() => _maxCefrLevel = result.value);
    }
  }

  Future<void> _pickWordLimit() async {
    final result = await showSingleSelectSheet<int?>(
      context: context,
      title: 'Số từ mỗi session',
      options: List.generate(
        _limits.length,
        (i) => SelectOption(value: _limits[i], label: _limitLabels[i]),
      ),
      selected: _wordLimit,
    );
    if (result != null) {
      setState(() => _wordLimit = result.value);
    }
  }

  Future<void> _start() async {
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          language: language,
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

  Future<void> _startDueSession() async {
    final language = ref.read(userSettingsNotifierProvider).targetLanguage;
    final words = await ref
        .read(getVocabListUseCaseProvider)
        .execute(language: language, dueOnly: true);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào cần ôn hôm nay.')),
        );
      }
      return;
    }
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: shuffled));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Từ vựng cách khoảng',
        leading: BloomIconButton(
          icon: Icons.arrow_back,
          onPressed: () => context.go('/practice'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            topicsAsync.when(
              data: (topics) {
                final selected =
                    topics.where((t) => t.id == _selectedTopicId).toList();
                return FilterTile(
                  icon: Icons.sell_outlined,
                  label: 'Chủ đề',
                  value: selected.isEmpty
                      ? 'Tất cả'
                      : '${selected.first.emoji} ${selected.first.name}',
                  onTap: () => _pickTopic(topics),
                );
              },
              loading: () => const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                e.toString(),
                style: TextStyle(color: context.bloom.danger),
              ),
            ),
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _maxCefrLevel?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            FilterTile(
              icon: Icons.format_list_numbered,
              label: 'Số từ mỗi session',
              value: _wordLimit?.toString() ?? 'Tất cả',
              onTap: _pickWordLimit,
            ),

            const Spacer(),

            BloomPillButton(
              label: _dueCount == 0
                  ? 'Hôm nay đã ôn xong ✓'
                  : 'Ôn hôm nay ($_dueCount từ)',
              variant: BloomButtonVariant.secondary,
              block: true,
              icon: Icons.today_outlined,
              onPressed: _dueCount == 0 ? null : _startDueSession,
            ),
            const SizedBox(height: 8),

            BloomPillButton(
              label: 'Bắt đầu luyện tập',
              variant: BloomButtonVariant.primary,
              block: true,
              icon: Icons.play_arrow,
              onPressed: _start,
            ),
          ],
        ),
      ),
    );
  }
}
