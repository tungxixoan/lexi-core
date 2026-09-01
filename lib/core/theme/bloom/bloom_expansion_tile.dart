import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A single collapsible row for a list of questions (Reading Part 6). Collapsed,
/// it shows a [title] and a one-line [summary] of the current answer; expanded,
/// it reveals [child]. Mark [answered] to tint the summary sage.
class BloomExpansionTile extends StatefulWidget {
  const BloomExpansionTile({
    super.key,
    required this.title,
    required this.summary,
    required this.child,
    this.answered = false,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final Widget child;
  final bool answered;
  final bool initiallyExpanded;

  @override
  State<BloomExpansionTile> createState() => _BloomExpansionTileState();
}

class _BloomExpansionTileState extends State<BloomExpansionTile> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final header = Row(
      children: [
        Expanded(
          child: Text(widget.title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: c.ink)),
        ),
        const SizedBox(width: BloomSpacing.sm),
        Text(widget.summary,
            style: TextStyle(
                fontSize: 12.5,
                color: widget.answered ? c.sage : c.inkFaint)),
        const SizedBox(width: BloomSpacing.xs),
        AnimatedRotation(
          turns: _expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: Icon(Icons.expand_more, size: 20, color: c.inkFaint),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: BloomSpacing.lg, vertical: BloomSpacing.md),
                child: header,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(BloomSpacing.lg, 0,
                        BloomSpacing.lg, BloomSpacing.lg),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
