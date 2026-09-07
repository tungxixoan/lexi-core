import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/knowledge_group.dart';
import '../providers/knowledge_notes_provider.dart';
import '../widgets/knowledge_note_row.dart';

/// Lists every knowledge note in one group, sectioned by CEFR level
/// (A1 → C2, then a "Chưa gắn cấp độ" bucket for notes with no level).
class KnowledgeGroupScreen extends ConsumerWidget {
  const KnowledgeGroupScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes =
        ref.watch(knowledgeNotesNotifierProvider).valueOrNull ?? const [];
    final inGroup = notes.where((n) => n.groupId == groupId).toList();

    final children = <Widget>[];
    for (final level in <CEFRLevel?>[...CEFRLevel.values, null]) {
      final rows = inGroup.where((n) => n.cefrLevel == level).toList();
      if (rows.isEmpty) continue;
      children.add(BloomSectionHeader(level?.label ?? 'Chưa gắn cấp độ'));
      for (final n in rows) {
        children.add(
          KnowledgeNoteRow(
            note: n,
            onTap: () => context.go('/knowledge/note/${n.id}'),
          ),
        );
      }
    }

    return BloomScaffold(
      appBar: BloomAppBar(title: knowledgeGroupLabel(groupId)),
      body: children.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Chưa có ghi chú nào trong nhóm này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.bloom.inkSoft),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: children,
            ),
    );
  }
}
