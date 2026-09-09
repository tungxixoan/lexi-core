import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';
import '../../domain/knowledge_filters.dart';
import '../providers/knowledge_notes_provider.dart';
import '../widgets/knowledge_note_row.dart';

/// Languages that ship a starter knowledge library — only these show the
/// "Khôi phục ghi chú mẫu" overflow action.
bool _knowledgeHasStarter(Language l) => l == Language.english;

const _examplePrompts = <String>[
  'Thì hiện tại hoàn thành',
  'Câu điều kiện loại 2',
  'Phân biệt "make" và "do"',
];

/// The "Kiến thức" home: a search box + tag chips over a grid of grammar
/// groups, switching to a flat filtered list once a query or tag is active.
class KnowledgeHomeScreen extends ConsumerStatefulWidget {
  const KnowledgeHomeScreen({super.key});

  @override
  ConsumerState<KnowledgeHomeScreen> createState() =>
      _KnowledgeHomeScreenState();
}

class _KnowledgeHomeScreenState extends ConsumerState<KnowledgeHomeScreen> {
  final _searchCtrl = TextEditingController();
  KnowledgeFilter _filter = const KnowledgeFilter();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _listMode =>
      _filter.query.trim().isNotEmpty || _filter.tags.isNotEmpty;

  void _toggleTag(String tag) {
    final next = {..._filter.tags};
    if (!next.remove(tag)) next.add(tag);
    setState(() => _filter = _filter.copyWith(tags: next));
  }

  Future<void> _restoreStarters() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(knowledgeNotesNotifierProvider.notifier).restoreStarters();
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã khôi phục ghi chú mẫu.')),
    );
  }

  // TODO(Task 14): replace with showKnowledgeAiRequestSheet(context)
  void _composeWithAi() => context.go('/knowledge/new');

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(
      userSettingsNotifierProvider.select((s) => s.targetLanguage),
    );
    final notesAsync = ref.watch(knowledgeNotesNotifierProvider);

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'Kiến thức',
        actions: [
          if (_knowledgeHasStarter(language))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (_) => _restoreStarters(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'restore',
                  child: Text('Khôi phục ghi chú mẫu'),
                ),
              ],
            ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Không tải được ghi chú: $e'),
          ),
        ),
        data: (notes) => _body(context, notes, language),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<KnowledgeNote> allNotes,
    Language language,
  ) {
    if (allNotes.isEmpty) {
      return Column(
        children: [
          Expanded(child: _emptyState(context)),
          _bottomActions(context),
        ],
      );
    }

    final tags = knowledgeAllTags(allNotes);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: BloomTextField(
            controller: _searchCtrl,
            hintText: 'Tìm kiến thức…',
            prefixIcon: Icons.search,
            onChanged: (v) =>
                setState(() => _filter = _filter.copyWith(query: v)),
          ),
        ),
        if (tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in tags)
                    BloomChip(
                      label: t,
                      style: _filter.tags.contains(t)
                          ? BloomChipStyle.active
                          : BloomChipStyle.neutral,
                      onTap: () => _toggleTag(t),
                    ),
                ],
              ),
            ),
          ),
        Expanded(
          child: _listMode
              ? _resultList(context, allNotes)
              : _groupGrid(context, allNotes, language),
        ),
        _bottomActions(context),
      ],
    );
  }

  Widget _groupGrid(
    BuildContext context,
    List<KnowledgeNote> allNotes,
    Language language,
  ) {
    final counts = knowledgeGroupCounts(allNotes);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final g in knowledgeGroupsFor(language))
            SizedBox(
              width: 168,
              child: _GroupCard(group: g, count: counts[g.id] ?? 0),
            ),
        ],
      ),
    );
  }

  Widget _resultList(BuildContext context, List<KnowledgeNote> allNotes) {
    final results = applyKnowledgeFilter(allNotes, _filter);
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Không có ghi chú nào khớp.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.bloom.inkSoft),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      children: [
        for (final n in results)
          KnowledgeNoteRow(
            note: n,
            onTap: () => context.go('/knowledge/note/${n.id}'),
          ),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    final c = context.bloom;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa có ghi chú nào.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thử nhờ AI soạn một ghi chú, ví dụ:',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.inkSoft),
            ),
            const SizedBox(height: 12),
            for (final p in _examplePrompts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $p',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.inkSoft),
                ),
              ),
            const SizedBox(height: 16),
            BloomPillButton(
              label: 'Nhờ AI soạn',
              icon: Icons.auto_awesome,
              onPressed: _composeWithAi,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomActions(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: BloomPillButton(
                label: '+ Nhờ AI soạn',
                block: true,
                onPressed: _composeWithAi,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BloomPillButton(
                label: '+ Tự viết',
                variant: BloomButtonVariant.secondary,
                block: true,
                onPressed: () => context.go('/knowledge/new'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.count});

  final KnowledgeGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Opacity(
      opacity: count == 0 ? 0.45 : 1,
      child: BloomCard(
        onTap: () => context.go('/knowledge/group/${group.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: c.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
