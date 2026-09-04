import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/ai_key_missing_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/home_notice_card.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../practice/domain/entities/saved_exercise.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/domain/entities/topic.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../domain/entities/dictation_difficulty.dart';
import '../../domain/entities/dictation_item.dart';
import '../providers/dictation_practice_provider.dart';

class DictationOptions extends ConsumerStatefulWidget {
  const DictationOptions({super.key});

  @override
  ConsumerState<DictationOptions> createState() => _DictationOptionsState();
}

class _DictationOptionsState extends ConsumerState<DictationOptions> {
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
    final words = _matchingWords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI tạo một câu từ Vocab Bank của bạn. Nghe và gõ lại chính xác '
          'những gì bạn nghe được — nghe lại càng nhiều lần, điểm càng thấp.',
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
            value: _topicIds.isEmpty ? 'Tất cả' : '${_topicIds.length} đã chọn',
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
        if (!settings.aiAvailable)
          const AiKeyMissingCard()
        else if (_language.ttsCloudCode == null)
          HomeNoticeCard(
            message: 'Tính năng này chưa hỗ trợ ${_language.label}. '
                'Hãy chọn Tiếng Việt hoặc English.',
          )
        else if (words == null)
          const Center(child: CircularProgressIndicator())
        else if (words.length < _minVocabWords)
          HomeNoticeCard(
            message:
                'Hãy lưu ít nhất 2 từ khớp với bộ lọc trên vào Vocab Bank. '
                'Hiện có ${words.length} từ.',
          )
        else
          sessionAsync.when(
            data: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BloomPillButton(
                  label: 'Tạo bài luyện',
                  icon: Icons.auto_awesome,
                  variant: BloomButtonVariant.primary,
                  block: true,
                  onPressed: () => _generate(context, ref, words),
                ),
                const SizedBox(height: 10),
                BloomPillButton(
                  label: 'Lấy bài có sẵn',
                  variant: BloomButtonVariant.secondary,
                  block: true,
                  onPressed: () => _reuse(context, ref),
                ),
              ],
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
    final notDueWords = eligibleWords.where((r) => !isDue(r)).toList()
      ..shuffle();
    final prioritized = [...dueWords, ...notDueWords];
    final words = prioritized.take(2).toList();

    await ref.read(dictationPracticeNotifierProvider.notifier).generate(
          words: words,
          level: _level ?? settings.targetCefrLevel ?? CEFRLevel.b1,
          context: AppContext.general,
          targetLanguage: _language,
          difficulty: _difficulty,
          generationFilters: _filters(),
        );

    if (context.mounted) {
      final session = ref.read(dictationPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/listening/dictation/session');
      }
    }
  }

  /// The raw `{difficulty}` map both `_generate` (threaded to the result
  /// screen's "Lưu bài") and `_reuse` (matched against saved docs) build from
  /// the current filter selection.
  Map<String, dynamic> _filters() => <String, dynamic>{
        'difficulty': _difficulty.name,
      };

  Future<void> _reuse(BuildContext context, WidgetRef ref) async {
    final filters = _filters();
    final result = await ref.read(savedExercisesServiceProvider).getRandom(
          type: SavedExerciseType.dictation,
          targetLanguage: _language,
          filters: filters,
        );
    if (!context.mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có bài đã lưu khớp bộ lọc.')),
      );
      return;
    }
    // A web-saved dictation item omits only `targetLanguage` from the item
    // sub-object; the rest is tolerated by DictationItem.fromJson's guarded
    // defaults.
    final passageJson = <String, dynamic>{
      ...result.passageJson,
      'targetLanguage': _language.name,
    };
    ref.read(dictationPracticeNotifierProvider.notifier).loadSaved(
          DictationItem.fromJson(passageJson),
          savedId: result.id,
          generationFilters: filters,
          difficulty: _difficulty,
        );
    final session = ref.read(dictationPracticeNotifierProvider).valueOrNull;
    if (session != null && !session.isComplete) {
      context.go('/listening/dictation/session');
    }
  }
}
