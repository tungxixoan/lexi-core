import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/ai_key_missing_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/economy_volume.dart';
import '../providers/part7_practice_provider.dart';

class Part7HomeScreen extends ConsumerStatefulWidget {
  const Part7HomeScreen({super.key});

  @override
  ConsumerState<Part7HomeScreen> createState() => _Part7HomeScreenState();
}

class _Part7HomeScreenState extends ConsumerState<Part7HomeScreen> {
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
    final sessionAsync = ref.watch(part7PracticeNotifierProvider);

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Part 7 — Đọc hiểu',
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
              'AI tạo 2 đoạn văn đơn + 1 bộ đoạn văn đôi (2 văn bản liên quan), kèm câu hỏi '
              'trắc nghiệm kiểu TOEIC Part 7. Trả lời hết rồi nộp bài.',
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
                data: (_) => BloomPillButton(
                  label: 'Tạo bài luyện',
                  icon: Icons.auto_awesome,
                  variant: BloomButtonVariant.primary,
                  block: true,
                  onPressed: () => _generate(context, ref),
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

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(part7PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part7PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part7/session');
    }
  }
}
