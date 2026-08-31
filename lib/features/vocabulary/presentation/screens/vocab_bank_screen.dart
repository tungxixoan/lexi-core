// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/topic.dart';
import '../../domain/entities/vocab_record.dart';
import '../providers/topics_provider.dart';
import '../providers/vocab_bank_provider.dart';

class VocabBankScreen extends ConsumerStatefulWidget {
  const VocabBankScreen({super.key});

  @override
  ConsumerState<VocabBankScreen> createState() => _VocabBankScreenState();
}

class _VocabBankScreenState extends ConsumerState<VocabBankScreen> {
  final Set<String> _selectedTopicIds = {};
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTopicPicker(List<Topic> topics) async {
    final result = await showMultiSelectSheet<String>(
      context: context,
      title: 'Chủ đề',
      options: topics
          .map((t) => SelectOption(value: t.id, label: t.name, emoji: t.emoji))
          .toList(),
      initialSelected: _selectedTopicIds,
    );
    if (result != null) {
      setState(() {
        _selectedTopicIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  List<VocabRecord> _filter(List<VocabRecord> records, Language targetLanguage) {
    var result = records.where((r) => r.targetLanguage == targetLanguage).toList();
    if (_selectedTopicIds.isNotEmpty) {
      result = result
          .where((r) => r.topicIds.any(_selectedTopicIds.contains))
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((r) =>
              r.headword.toLowerCase().contains(q) ||
              r.meaning.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final vocabAsync = ref.watch(vocabBankNotifierProvider);
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final targetLanguage = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Ngân hàng từ · ${targetLanguage.label}',
        actions: [
          BloomIconButton(
            icon: Icons.add,
            tooltip: 'Thêm chủ đề',
            onPressed: () => _showAddTopicDialog(context),
          ),
        ],
      ),
      floatingActionButton: Material(
        color: c.accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/'),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.add, color: c.accentInk, size: 26),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: BloomTextField(
              controller: _searchCtrl,
              hintText: 'Tìm từ…',
              prefixIcon: Icons.search,
              suffix: _searchQuery.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.clear, size: 18, color: c.inkFaint),
                    ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),
          // Topic filter — opens a bottom sheet with multi-select checkboxes
          topicsAsync.when(
            data: (topics) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterTile(
                icon: Icons.sell_outlined,
                label: 'Chủ đề',
                value: _selectedTopicIds.isEmpty
                    ? 'Tất cả'
                    : '${_selectedTopicIds.length} đã chọn',
                onTap: () => _openTopicPicker(topics),
              ),
            ),
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: c.border),
          // Vocab list
          Expanded(
            child: vocabAsync.when(
              data: (records) {
                final filtered = _filter(records, targetLanguage);
                if (filtered.isEmpty && records.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 48, color: c.inkFaint),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa lưu từ nào.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tra một từ rồi bấm Lưu.',
                            style: TextStyle(color: c.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Không có từ nào khớp tìm kiếm hoặc bộ lọc.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.inkSoft),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final record = filtered[i];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i != 0) Divider(height: 1, color: c.border),
                        BloomListRow(
                          cefr: record.cefrLevel.label,
                          headword: record.headword,
                          meaning: record.meaning,
                          trailingText: record.inputType.name,
                          onTap: () => context.push('/vocab/${record.id}'),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📌');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chủ đề mới'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BloomSectionHeader('Tên chủ đề'),
            BloomTextField(
              controller: nameCtrl,
              autofocus: true,
              hintText: 'vd: Từ vựng của tôi',
            ),
            const SizedBox(height: 8),
            const BloomSectionHeader('Emoji'),
            BloomTextField(
              controller: emojiCtrl,
              hintText: 'Emoji',
            ),
          ],
        ),
        actions: [
          BloomPillButton(
            label: 'Huỷ',
            variant: BloomButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx),
          ),
          BloomPillButton(
            label: 'Thêm',
            onPressed: () async {
              try {
                await ref
                    .read(topicsNotifierProvider.notifier)
                    .addTopic(nameCtrl.text, emojiCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    emojiCtrl.dispose();
  }
}
