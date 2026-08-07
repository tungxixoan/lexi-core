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
import '../providers/part5_practice_provider.dart';

class Part5HomeScreen extends ConsumerStatefulWidget {
  const Part5HomeScreen({super.key});

  @override
  ConsumerState<Part5HomeScreen> createState() => _Part5HomeScreenState();
}

class _Part5HomeScreenState extends ConsumerState<Part5HomeScreen> {
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
    final sessionAsync = ref.watch(part5PracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Part 5 — Điền câu'),
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
                'AI tạo 15 câu điền từ/ngữ pháp kiểu TOEIC Part 5. Chọn đáp án đúng cho mỗi câu.',
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
    await ref.read(part5PracticeNotifierProvider.notifier).generate(
          context: _context,
          targetLanguage: _language,
          volumes: _volumes,
        );
    if (context.mounted) {
      final session = ref.read(part5PracticeNotifierProvider).valueOrNull;
      if (session != null) context.go('/reading/part5/session');
    }
  }
}

