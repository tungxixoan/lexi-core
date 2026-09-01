import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import 'bloom_chip.dart';

/// A horizontal, scrollable row of pills that navigates a set of groups
/// (Reading Part 6 passages / Part 7 passage groups) — exactly one active.
class BloomGroupChips extends StatelessWidget {
  const BloomGroupChips({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: BloomSpacing.sm),
            BloomChip(
              label: labels[i],
              style: i == activeIndex
                  ? BloomChipStyle.active
                  : BloomChipStyle.neutral,
              onTap: () => onChanged(i),
            ),
          ],
        ],
      ),
    );
  }
}
