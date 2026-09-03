import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/ai_key_missing_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/home_notice_card.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../features/dictionary/domain/entities/app_context.dart';
import '../../../../features/dictionary/domain/entities/language.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/domain/entities/topic.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/topics_provider.dart';
import '../providers/reading_practice_provider.dart';

class ReadingHomeScreen extends ConsumerStatefulWidget {
  const ReadingHomeScreen({super.key});

  @override
  ConsumerState<ReadingHomeScreen> createState() => _ReadingHomeScreenState();
}

class _ReadingHomeScreenState extends ConsumerState<ReadingHomeScreen> {
  static const _minVocabWords = 5;
  static const _wordCounts = <int?>[5, 10, 20, null];
  static const _wordCountLabels = ['5', '10', '20', 'Tất cả'];

  late Language _language;
  final Set<String> _topicIds = {};
  CEFRLevel? _level;
  int? _wordCount = 10;

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
    // Language and level are filtered server-side — topic can be
    // multi-selected, so it's applied locally below.
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

  Future<void> _pickWordCount() async {
    final result = await showSingleSelectSheet<int?>(
      context: context,
      title: 'Số từ dùng để tạo bài',
      options: List.generate(
        _wordCounts.length,
        (i) => SelectOption(value: _wordCounts[i], label: _wordCountLabels[i]),
      ),
      selected: _wordCount,
    );
    if (result != null) {
      setState(() => _wordCount = result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final sessionAsync = ref.watch(readingPracticeNotifierProvider);
    final words = _matchingWords;

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Luyện đọc & gõ',
        leading: BloomIconButton(
          icon: Icons.arrow_back_ios_new,
          onPressed: () => context.go('/reading'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI tạo một đoạn văn song ngữ từ Vocab Bank của bạn. '
              'Đọc đoạn văn bằng ngôn ngữ mục tiêu, sau đó gõ lại từng câu.',
              style: TextStyle(fontSize: 14, color: context.bloom.inkSoft),
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
              icon: Icons.format_list_numbered,
              label: 'Số từ dùng để tạo bài',
              value: _wordCount?.toString() ?? 'Tất cả',
              onTap: _pickWordCount,
            ),
            const SizedBox(height: 16),
            if (!settings.aiAvailable)
              const AiKeyMissingCard()
            else if (words == null)
              const Center(child: CircularProgressIndicator())
            else if (words.length < _minVocabWords)
              HomeNoticeCard(
                message:
                    'Hãy lưu ít nhất 5 từ khớp với bộ lọc trên vào Vocab Bank. '
                    'Hiện có ${words.length} từ.',
              )
            else
              sessionAsync.when(
                data: (_) => BloomPillButton(
                  label: 'Tạo bài luyện',
                  icon: Icons.auto_awesome,
                  variant: BloomButtonVariant.primary,
                  block: true,
                  onPressed: () => _generate(context, ref, words),
                ),
                loading: () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Đang tạo bài...',
                      style: TextStyle(color: context.bloom.inkSoft),
                    ),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lỗi tạo bài: $e',
                      style: TextStyle(color: context.bloom.danger),
                    ),
                    const SizedBox(height: 8),
                    BloomPillButton(
                      label: 'Thử lại',
                      variant: BloomButtonVariant.secondary,
                      onPressed: () => _generate(context, ref, words),
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
    List<VocabRecord> vocabItems,
  ) async {
    final settings = ref.read(userSettingsNotifierProvider);

    final now = DateTime.now();
    bool isDue(VocabRecord r) =>
        r.nextReviewAt == null || r.nextReviewAt!.isBefore(now);
    final dueWords = vocabItems.where(isDue).toList()..shuffle();
    final notDueWords = vocabItems.where((r) => !isDue(r)).toList()..shuffle();
    final prioritized = [...dueWords, ...notDueWords];
    final words =
        (_wordCount == null ? prioritized : prioritized.take(_wordCount!))
            .toList()
            .cast<VocabRecord>();

    await ref.read(readingPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: _language,
        );

    if (context.mounted) {
      final session = ref.read(readingPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/reading/bilingual/session');
      }
    }
  }
}
