import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/ai_key_missing_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../practice/domain/entities/saved_exercise.dart';
import '../../domain/entities/economy_volume.dart';
import '../../domain/entities/part5_question.dart';
import '../providers/part5_practice_provider.dart';

class Part5Options extends ConsumerStatefulWidget {
  const Part5Options({super.key});

  @override
  ConsumerState<Part5Options> createState() => _Part5OptionsState();
}

class _Part5OptionsState extends ConsumerState<Part5Options> {
  late Language _language;
  late AppContext _context;
  final Set<EconomyVolume> _volumes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = AppContext.general;
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
    if (result != null) setState(() => _language = result.value);
  }

  Future<void> _pickContext() async {
    final result = await showSingleSelectSheet<AppContext>(
      context: context,
      title: 'Chủ đề',
      options: AppContext.values
          .map((c) => SelectOption(value: c, label: c.label, emoji: c.emoji))
          .toList(),
      selected: _context,
    );
    if (result != null) setState(() => _context = result.value);
  }

  Future<void> _pickVolumes() async {
    final result = await showMultiSelectSheet<EconomyVolume>(
      context: context,
      title: 'Độ khó',
      options: EconomyVolume.values
          .map((v) => SelectOption(value: v, label: v.label))
          .toList(),
      initialSelected: _volumes,
    );
    if (result != null) {
      setState(() {
        _volumes
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final sessionAsync = ref.watch(part5PracticeNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI tạo 15 câu điền từ/ngữ pháp kiểu TOEIC Part 5. Chọn đáp án đúng cho mỗi câu.',
          style: TextStyle(fontSize: 14, color: context.bloom.inkSoft),
        ),
        const SizedBox(height: 16),
        FilterTile(
          icon: Icons.language_outlined,
          label: 'Ngôn ngữ',
          value: _language.label,
          onTap: _pickLanguage,
        ),
        FilterTile(
          icon: Icons.sell_outlined,
          label: 'Chủ đề',
          value: '${_context.emoji} ${_context.label}',
          onTap: _pickContext,
        ),
        FilterTile(
          icon: Icons.speed_outlined,
          label: 'Độ khó',
          value: _volumes.isEmpty ? 'Tất cả' : '${_volumes.length} đã chọn',
          onTap: _pickVolumes,
        ),
        const SizedBox(height: 16),
        if (!settings.aiAvailable)
          const AiKeyMissingCard()
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
                  onPressed: () => _generate(context, ref),
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
                  onPressed: () => _generate(context, ref),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The raw `{topicIds, volumes}` map both `_generate` (threaded to the result
  /// screen's "Lưu bài") and `_reuse` (matched against saved docs) build from
  /// the current filter selection.
  Map<String, dynamic> _filters() => <String, dynamic>{
        'topicIds': <String>[],
        'volumes': _volumes.map((v) => v.name).toList(),
      };

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(part5PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
          generationFilters: _filters(),
        );
    if (context.mounted) {
      final session = ref.read(part5PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part5/session');
    }
  }

  Future<void> _reuse(BuildContext context, WidgetRef ref) async {
    final filters = _filters();
    final result = await ref.read(savedExercisesServiceProvider).getRandom(
          type: SavedExerciseType.part5,
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
    // A web-saved TOEIC set omits only `targetLanguage` from the passage
    // sub-object; the rest is tolerated by Part5Set.fromJson's guarded defaults.
    final passageJson = <String, dynamic>{
      ...result.passageJson,
      'targetLanguage': _language.name,
    };
    ref.read(part5PracticeNotifierProvider.notifier).loadSaved(
          Part5Set.fromJson(passageJson),
          savedId: result.id,
          generationFilters: filters,
        );
    final session = ref.read(part5PracticeNotifierProvider).valueOrNull;
    if (session != null) context.go('/reading/part5/session');
  }
}
