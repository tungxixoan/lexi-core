import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/ai_disabled_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/economy_volume.dart';
import '../providers/part6_practice_provider.dart';

class Part6HomeScreen extends ConsumerStatefulWidget {
  const Part6HomeScreen({super.key});

  @override
  ConsumerState<Part6HomeScreen> createState() => _Part6HomeScreenState();
}

class _Part6HomeScreenState extends ConsumerState<Part6HomeScreen> {
  late Language _language;
  late AppContext _context;
  final Set<EconomyVolume> _volumes = {};

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = settings.activeContext;
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values.map((l) => SelectOption(value: l, label: l.label)).toList(),
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
      options: EconomyVolume.values.map((v) => SelectOption(value: v, label: v.label)).toList(),
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
    final sessionAsync = ref.watch(part6PracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Part 6 — Điền đoạn văn'),
        leading: BackButton(onPressed: () => context.go('/reading')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo 3 đoạn văn ngắn (email/thông báo/thư...) mỗi đoạn có 4 chỗ trống '
                'kiểu TOEIC Part 6. Chọn đáp án đúng cho từng chỗ trống.',
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
            if (!settings.aiEnabled)
              AiDisabledCard(
                message: 'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref),
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
                    Text('Lỗi tạo bài: $e', style: TextStyle(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref),
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

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    await ref.read(part6PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part6PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part6/session');
    }
  }
}

