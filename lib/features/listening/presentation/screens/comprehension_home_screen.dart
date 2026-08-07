import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/ai_disabled_card.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
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
    _context = settings.activeContext;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe hiểu'),
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
                'AI tạo một đoạn hội thoại hoặc bài nói ngắn. Nghe và trả lời '
                '3 câu hỏi trắc nghiệm về nội dung — giống phần nghe TOEIC.',
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
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            const SizedBox(height: 16),

            if (!settings.aiEnabled)
              AiDisabledCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
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
                    Text(
                      'Lỗi tạo bài: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
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
    await ref.read(listeningComprehensionNotifierProvider.notifier).generate(
          level: _level ?? CEFRLevel.b1,
          context: _context,
          targetLanguage: _language,
        );

    if (context.mounted) {
      final session =
          ref.read(listeningComprehensionNotifierProvider).valueOrNull;
      if (session != null) {
        context.go('/listening/comprehension/session');
      }
    }
  }
}

