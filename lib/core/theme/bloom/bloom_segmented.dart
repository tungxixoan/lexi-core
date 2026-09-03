import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A generic value in a segmented control.
class BloomSegment<T> {
  const BloomSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// A pill segmented control for choosing between mutually exclusive options.
///
/// Generic over the value type ([T]). Renders a `Row` of equal-flex segments
/// in a pill container, with the selected segment highlighted in accent color.
class BloomSegmented<T> extends StatelessWidget {
  const BloomSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<BloomSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.pill),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      selected == segment.value ? c.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(BloomRadii.pill),
                ),
                clipBehavior: Clip.antiAlias,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(segment.value),
                    borderRadius: BorderRadius.circular(BloomRadii.pill),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: BloomSpacing.sm,
                        horizontal: BloomSpacing.md,
                      ),
                      child: Center(
                        child: Text(
                          segment.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected == segment.value
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: selected == segment.value
                                ? c.accentInk
                                : c.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
