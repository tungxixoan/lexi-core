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
import '../../domain/entities/listening_passage.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionHomeScreen extends ConsumerStatefulWidget {
  const ComprehensionHomeScreen({super.key});

  @override
  ConsumerState<ComprehensionHomeScreen> createState() =>
      _ComprehensionHomeScreenState();
}

class _ComprehensionHomeScreenState
    extends ConsumerState<ComprehensionHomeScreen> {
  late Language _language;
  late AppContext _context;
  CEFRLevel? _level;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = AppContext.general;
    _level = settings.targetCefrLevel;
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
    if (result != null) setState(() => _level = result.value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final sessionAsync = ref.watch(listeningComprehensionNotifierProvider);

    return BloomScaffold(
      appBar: const BloomAppBar(
        title: 'Nghe hiểu',
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI tạo một đoạn hội thoại hoặc bài nói ngắn. Nghe và trả lời '
              '3 câu hỏi trắc nghiệm về nội dung — giống phần nghe TOEIC.',
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
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            const SizedBox(height: 16),
            if (!settings.aiAvailable)
              const AiKeyMissingCard()
            else if (_language.ttsCloudCode == null)
              HomeNoticeCard(
                message: 'Tính năng này chưa hỗ trợ ${_language.label}. '
                    'Hãy chọn Tiếng Việt hoặc English.',
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
        ),
      ),
    );
  }

  /// The lookup filter `_reuse` matches saved docs against — `level` is nullable
  /// here ("match any level").
  Map<String, dynamic> _filters() => <String, dynamic>{
        'context': _context.name,
        'level': _level?.name,
      };

  /// What `_generate` persists as the saved doc's `generationFilters` — `level`
  /// is ALWAYS concrete here (mirrors web: a saved `generationFilters.level` is
  /// never null; only the lookup filter can be).
  Map<String, dynamic> _generationFilters() => <String, dynamic>{
        'context': _context.name,
        'level': (_level ?? CEFRLevel.b1).name,
      };

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(listeningComprehensionNotifierProvider.notifier).generate(
          level: _level ?? CEFRLevel.b1,
          context: _context,
          targetLanguage: _language,
          generationFilters: _generationFilters(),
        );

    if (context.mounted) {
      final session =
          ref.read(listeningComprehensionNotifierProvider).valueOrNull;
      if (session != null) {
        context.go('/listening/comprehension/session');
      }
    }
  }

  Future<void> _reuse(BuildContext context, WidgetRef ref) async {
    final filters = _filters();
    final result = await ref.read(savedExercisesServiceProvider).getRandom(
          type: SavedExerciseType.comprehension,
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
    // A web-saved comprehension `item` carries only
    // `{kind, turns, questions, speakerGenders}` — level/context/targetLanguage
    // live on the wrapper. Rebuild them from the current language and the
    // wrapper's own `generationFilters` (mirrors the web restore path in
    // apps/web listening/comprehension/page.tsx), not overwriting a real value
    // the doc already carries.
    final passageJson = <String, dynamic>{
      ...result.passageJson,
      'targetLanguage': _language.name,
      'level':
          result.generationFilters['level'] ?? result.passageJson['level'],
      'context':
          result.generationFilters['context'] ?? result.passageJson['context'],
    };
    ref.read(listeningComprehensionNotifierProvider.notifier).loadSaved(
          ListeningPassage.fromJson(passageJson),
          savedId: result.id,
          generationFilters: filters,
        );
    final session =
        ref.read(listeningComprehensionNotifierProvider).valueOrNull;
    if (session != null) {
      context.go('/listening/comprehension/session');
    }
  }
}
