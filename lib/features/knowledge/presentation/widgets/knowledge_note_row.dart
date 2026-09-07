import 'package:flutter/material.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../domain/entities/knowledge_group.dart';
import '../../domain/entities/knowledge_note.dart';

/// A single knowledge-note summary card: title, a 2-line summary, and a chip
/// row (group label, CEFR level, and a "Mẫu" badge for starter notes).
class KnowledgeNoteRow extends StatelessWidget {
  const KnowledgeNoteRow({super.key, required this.note, this.onTap});

  final KnowledgeNote note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final chips = <Widget>[
      BloomChip(label: knowledgeGroupLabel(note.groupId)),
      if (note.cefrLevel != null) BloomChip(label: note.cefrLevel!.label),
      if (note.origin == KnowledgeNoteOrigin.starter)
        const BloomChip(label: 'Mẫu'),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: BloomCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (note.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.inkSoft, fontSize: 13),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
        ),
      ),
    );
  }
}
