import 'package:flutter/material.dart';

import '../../../../core/theme/bloom/bloom.dart';
import '../../domain/entities/knowledge_note.dart';

/// Shown inside the "Nhờ AI soạn" sheet when the request overlaps notes the
/// user already has: one card per related note (Mở / Bổ sung), plus a single
/// shared "Vẫn tạo mới" action.
class RelatedNotesBanner extends StatelessWidget {
  const RelatedNotesBanner({
    super.key,
    required this.related,
    required this.onProceedNew,
    required this.onExtend,
    required this.onOpen,
    this.scrollController,
  });

  final List<KnowledgeNote> related;
  final void Function() onProceedNew;
  final void Function(KnowledgeNote) onExtend;
  final void Function(KnowledgeNote) onOpen;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Bạn đã có ${related.length} ghi chú liên quan',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        for (final note in related)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BloomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      BloomPillButton(
                        label: 'Mở',
                        variant: BloomButtonVariant.link,
                        onPressed: () => onOpen(note),
                      ),
                      const Spacer(),
                      Flexible(
                        child: BloomPillButton(
                          label: 'Bổ sung vào ghi chú này',
                          onPressed: () => onExtend(note),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        BloomPillButton(
          label: 'Vẫn tạo mới',
          variant: BloomButtonVariant.secondary,
          block: true,
          onPressed: onProceedNew,
        ),
      ],
    );
  }
}
