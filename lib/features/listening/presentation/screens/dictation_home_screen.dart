import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/ai_disabled_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/topic.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../domain/entities/dictation_difficulty.dart';
import '../providers/dictation_practice_provider.dart';

class DictationHomeScreen extends ConsumerStatefulWidget {
  const DictationHomeScreen({super.key});

  @override
  ConsumerState<DictationHomeScreen> createState() =>
      _DictationHomeScreenState();
}

class _DictationHomeScreenState extends ConsumerState<DictationHomeScreen> {
  static const _minVocabWords = 2;

  late Language _language;
  final Set<String> _topicIds = {};
  CEFRLevel? _level;
  DictationDifficulty _difficulty = DictationDifficulty.hard;

  List<VocabRecord>? _matchingWords; // null while loading

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _level = settings.targetCefrLevel;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _matchingWords = null);
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          language: _language,
          maxCefrLevel: _level,
        );
    var filtered = words;
    if (_topicIds.isNotEmpty) {
      filtered =
          filtered.where((r) => r.topicIds.any(_topicIds.contains)).toList();
    }
    if (mounted) setState(() => _matchingWords = filtered);
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values
          .map((l) => SelectOption(value: l, label: l.label))
          .toList(),
      selected: _language,
    );
    if (result != null) {
      setState(() => _language = result.value);
      _reload();
    }
  }

  Future<void> _pickTopics(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Chủ đề',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _topicIds,
    );
    if (result != null) {
      setState(() {
        _topicIds
          ..clear()
          ..addAll(result);
      });
      _reload();
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
      selected: _level,
    );
    if (result != null) {
      setState(() => _level = result.value);
      _reload();
    }
  }

  Future<void> _pickDifficulty() async {
    final result = await showSingleSelectSheet<DictationDifficulty>(
      context: context,
      title: 'Mức độ',
      options: DictationDifficulty.values
          .map((d) => SelectOption(value: d, label: d.label))
          .toList(),
      selected: _difficulty,
    );
    if (result != null) {
      setState(() => _difficulty = result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final sessionAsync = ref.watch(dictationPracticeNotifierProvider);
    final theme = Theme.of(context);
    final words = _matchingWords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe chép'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo một câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác '
                'những gì bạn nghe được — nghe lại càng nhiều lần, điểm càng thấp.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),

            FilterTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: _language.label,
              onTap: _pickLanguage,
            ),
            topicsAsync.when(
              data: (topics) => FilterTile(
                icon: Icons.sell_outlined,
                label: 'Chủ đề',
                value: _topicIds.isEmpty
                    ? 'Tất cả'
                    : '${_topicIds.length} đã chọn',
                onTap: () => _pickTopics(topics),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            FilterTile(
              icon: Icons.tune,
              label: 'Mức độ',
              value: _difficulty.label,
              onTap: _pickDifficulty,
            ),
            const SizedBox(height: 16),

            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (words == null)
              const Center(child: CircularProgressIndicator())
            else if (words.length < _minVocabWords)
              AiDisabledCard(
                message:
                    'Hãy lưu ít nhất 2 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref, words),
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
                      onPressed: () => _generate(context, ref, words),
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

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    List<VocabRecord> eligibleWords,
  ) async {
    final settings = ref.read(userSettingsNotifierProvider);

    final now = DateTime.now();
    bool isDue(VocabRecord r) =>
        r.nextReviewAt == null || r.nextReviewAt!.isBefore(now);
    final dueWords = eligibleWords.where(isDue).toList()..shuffle();
    final notDueWords = eligibleWords.where((r) => !isDue(r)).toList()..shuffle();
    final prioritized = [...dueWords, ...notDueWords];
    final words = prioritized.take(2).toList();

    await ref.read(dictationPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: _language,
          difficulty: _difficulty,
        );

    if (context.mounted) {
      final session = ref.read(dictationPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/listening/dictation/session');
      }
    }
  }
}

