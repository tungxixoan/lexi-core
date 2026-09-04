import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import '../../utils/web_text_scale.dart';
import 'bloom_chip.dart';

/// A draggable bottom sheet holding the reading passage(s) for Part 6 / Part 7,
/// so the questions get the main content area. One [tabs] entry per document
/// (Part 7 double-passage groups pass two).
class BloomPassageSheet extends StatefulWidget {
  const BloomPassageSheet({
    super.key,
    required this.tabs,
    required this.passages,
    this.initialChildSize = 0.44,
    this.minChildSize = 0.12,
    this.maxChildSize = 0.9,
    this.hint = 'Kéo lên để đọc đoạn văn',
  }) : assert(tabs.length == passages.length);

  final List<String> tabs;
  final List<String> passages;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final String hint;

  @override
  State<BloomPassageSheet> createState() => _BloomPassageSheetState();
}

class _BloomPassageSheetState extends State<BloomPassageSheet> {
  int _tab = 0;

  @override
  void didUpdateWidget(BloomPassageSheet old) {
    super.didUpdateWidget(old);
    if (_tab >= widget.tabs.length) _tab = 0;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: widget.initialChildSize,
      minChildSize: widget.minChildSize,
      maxChildSize: widget.maxChildSize,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(BloomRadii.lg)),
            border: Border.all(color: c.border),
            boxShadow: BloomShadows.warm(isDark),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(BloomSpacing.lg, BloomSpacing.sm,
                BloomSpacing.lg, BloomSpacing.xl),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.inkFaint,
                    borderRadius: BorderRadius.circular(BloomRadii.pill),
                  ),
                ),
              ),
              const SizedBox(height: BloomSpacing.xs),
              Center(
                child: Text(widget.hint,
                    style: TextStyle(fontSize: 12.5, color: c.inkSoft)),
              ),
              if (widget.tabs.length > 1) ...[
                const SizedBox(height: BloomSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.tabs.length; i++) ...[
                      if (i > 0) const SizedBox(width: BloomSpacing.sm),
                      BloomChip(
                        label: widget.tabs[i],
                        style: i == _tab
                            ? BloomChipStyle.active
                            : BloomChipStyle.neutral,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: BloomSpacing.sm),
              Container(
                padding: const EdgeInsets.only(left: BloomSpacing.md),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: c.accent, width: 3)),
                ),
                child: Text(
                  widget.passages[_tab],
                  style: webScaled(TextStyle(fontSize: 15, color: c.ink)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
