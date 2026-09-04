// lib/features/vocabulary/presentation/screens/vocab_bank_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../../core/widgets/vocab_filter.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/cefr_level.dart';
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
  VocabFilterState _filters = const VocabFilterState();
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
      initialSelected: _filters.topicIds,
    );
    if (result != null) {
      setState(() => _filters = _filters.copyWith(topicIds: result));
    }
  }

  Future<void> _openLevelPicker() async {
    final result = await showMultiSelectSheet<CEFRLevel>(
      context: context,
      title: 'Cấp độ',
      options: CEFRLevel.values
          .map((l) => SelectOption(value: l, label: l.label))
          .toList(),
      initialSelected: _filters.cefrLevels,
    );
    if (result != null) {
      setState(() => _filters = _filters.copyWith(cefrLevels: result));
    }
  }

  List<VocabRecord> _filter(
      List<VocabRecord> records, Language targetLanguage) {
    return records
        .where((r) => r.targetLanguage == targetLanguage)
        .where((r) => matchesVocabFilters(r, _filters))
        .toList();
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
              suffix: _filters.query.isEmpty
                  ? null
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _searchCtrl.clear();
                        setState(
                          () => _filters = _filters.copyWith(query: ''),
                        );
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.clear, size: 18, color: c.inkFaint),
                      ),
                    ),
              onChanged: (v) =>
                  setState(() => _filters = _filters.copyWith(query: v)),
            ),
          ),
          const SizedBox(height: 8),
          // "Cần ôn hôm nay" toggle — filters to records that are due for review.
          Builder(
            builder: (context) {
              final all = vocabAsync.valueOrNull ?? const <VocabRecord>[];
              final dueCount = all.where((r) => vocabRecordIsDue(r)).length;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BloomChip(
                        label: 'Cần ôn hôm nay ($dueCount)',
                        style: _filters.dueOnly
                            ? BloomChipStyle.active
                            : BloomChipStyle.neutral,
                        onTap: () => setState(
                          () => _filters =
                              _filters.copyWith(dueOnly: !_filters.dueOnly),
                        ),
                      ),
                      if (_filters.isActive)
                        BloomChip(
                          label: 'Xoá lọc',
                          style: BloomChipStyle.clear,
                          onTap: () {
                            _searchCtrl.clear();
                            setState(
                              () => _filters = const VocabFilterState(),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Topic filter — opens a bottom sheet with multi-select checkboxes
          topicsAsync.when(
            data: (topics) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterTile(
                icon: Icons.sell_outlined,
                label: 'Chủ đề',
                value: _filters.topicIds.isEmpty
                    ? 'Tất cả'
                    : '${_filters.topicIds.length} đã chọn',
                onTap: () => _openTopicPicker(topics),
              ),
            ),
            loading: () => const SizedBox(height: 48),
            error: (_, __) => const SizedBox(height: 48),
          ),
          // CEFR-level filter — opens a multi-select sheet of a1..c2.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _filters.cefrLevels.isEmpty
                  ? 'Tất cả'
                  : '${_filters.cefrLevels.length} đã chọn',
              onTap: _openLevelPicker,
            ),
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
                            'Tra một từ rồi bấm Lưu từ.',
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
                          trailingText: record.inputType.label,
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
