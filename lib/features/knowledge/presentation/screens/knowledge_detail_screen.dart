import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/bold_text.dart';
import '../../../../core/widgets/highlighted_text.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';
import '../providers/knowledge_notes_provider.dart';

/// Read-only view of a single knowledge note, with edit / delete actions.
class KnowledgeDetailScreen extends ConsumerWidget {
  const KnowledgeDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá ghi chú?'),
        content: const Text('Ghi chú này sẽ bị xoá. Không thể hoàn tác.'),
        actions: [
          BloomPillButton(
            label: 'Huỷ',
            variant: BloomButtonVariant.secondary,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          BloomPillButton(
            label: 'Xoá',
            variant: BloomButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(knowledgeNotesNotifierProvider.notifier).deleteNote(id);
      if (context.mounted) context.go('/knowledge');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(knowledgeNotesNotifierProvider);
    final notes = notesAsync.valueOrNull;

    if (notes == null && notesAsync.isLoading) {
      return const BloomScaffold(
        appBar: BloomAppBar(title: ''),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    KnowledgeNote? note;
    for (final n in notes ?? const <KnowledgeNote>[]) {
      if (n.id == id) {
        note = n;
        break;
      }
    }

    if (note == null) {
      return const BloomScaffold(
        appBar: BloomAppBar(title: ''),
        body: Center(child: Text('Không tìm thấy ghi chú')),
      );
    }

    final c = context.bloom;
    final language =
        ref.watch(userSettingsNotifierProvider.select((s) => s.targetLanguage));
    final knownHeadwords = (ref.watch(vocabBankNotifierProvider).valueOrNull ??
            const [])
        .where((r) => r.targetLanguage == language)
        .map((r) => r.headword)
        .toList();

    final chips = <Widget>[
      BloomChip(label: knowledgeGroupLabel(note.groupId)),
      if (note.cefrLevel != null) BloomChip(label: note.cefrLevel!.label),
      for (final t in note.tags) BloomChip(label: t),
      if (note.origin == KnowledgeNoteOrigin.starter)
        const BloomChip(label: 'Mẫu'),
    ];

    return BloomScaffold(
      appBar: BloomAppBar(
        title: '',
        actions: [
          BloomIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Sửa',
            onPressed: () => context.go('/knowledge/note/$id/edit'),
          ),
          BloomIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Xoá',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            note.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (note.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note.summary, style: const TextStyle(fontSize: 16)),
          ],
          if (note.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            BoldText(source: note.explanation),
          ],
          if (note.patterns.isNotEmpty) ...[
            const BloomSectionHeader('Mẫu câu'),
            for (final p in note.patterns)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  p,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: c.ink,
                  ),
                ),
              ),
          ],
          if (note.examples.isNotEmpty) ...[
            const BloomSectionHeader('Ví dụ'),
            for (final ex in note.examples)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      text: ex.text,
                      highlights: knownHeadwords,
                      style: const TextStyle(fontSize: 15),
                    ),
                    if (ex.translation.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ex.translation,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          if (note.pitfalls.isNotEmpty) ...[
            const BloomSectionHeader('Lỗi thường gặp'),
            for (final p in note.pitfalls)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: BoldText(source: p),
              ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ],
      ),
    );
  }
}
