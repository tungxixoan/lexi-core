import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// One row in a vocab-style list: a round sage CEFR dot, headword + meaning,
/// and an optional muted trailing string (e.g. a due date).
class BloomListRow extends StatelessWidget {
  const BloomListRow({
    super.key,
    required this.cefr,
    required this.headword,
    required this.meaning,
    this.trailingText,
    this.onTap,
  });

  final String cefr;
  final String headword;
  final String meaning;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.sageBg, shape: BoxShape.circle),
              child: Text(cefr.toUpperCase(),
                  style: TextStyle(
                      color: c.sage, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(headword,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style:
                            TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(meaning,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.inkSoft)),
                  ),
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(trailingText!,
                  style: TextStyle(color: c.inkFaint, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
