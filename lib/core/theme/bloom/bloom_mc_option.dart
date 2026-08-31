import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import '../../utils/web_text_scale.dart';

enum BloomMcState { neutral, selected, correct, wrong }

/// A multiple-choice answer tile. `neutral` before answering; `selected`
/// while chosen-but-unrevealed; `correct`/`wrong` after the answer is
/// revealed. Pass `onTap: null` to disable (post-answer).
class BloomMcOption extends StatelessWidget {
  const BloomMcOption({
    super.key,
    required this.label,
    required this.onTap,
    this.state = BloomMcState.neutral,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final BloomMcState state;
  final String? leading;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    late final Color bg;
    late final Color fg;
    late final Color border;
    switch (state) {
      case BloomMcState.neutral:
        bg = c.surface2;
        fg = c.ink;
        border = c.border;
      case BloomMcState.selected:
        bg = c.surface3;
        fg = c.accent;
        border = c.accent;
      case BloomMcState.correct:
        bg = c.successBg;
        fg = c.success;
        border = c.success;
      case BloomMcState.wrong:
        bg = c.dangerBg;
        fg = c.danger;
        border = c.danger;
    }

    final decoration = BoxDecoration(
      color: bg,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(BloomRadii.sm),
    );

    final Widget inner = Row(
      children: [
        if (leading != null) ...[
          Text(leading!,
              style: webScaled(TextStyle(
                  color: fg, fontWeight: FontWeight.w800, fontSize: 15))),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(label,
              style: webScaled(TextStyle(
                  color: fg,
                  fontWeight: state == BloomMcState.neutral
                      ? FontWeight.w400
                      : FontWeight.w700,
                  fontSize: 15))),
        ),
      ],
    );

    const padding = EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    if (onTap == null) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: decoration,
        child: inner,
      );
    }
    // Interactive path: decoration in the widget layer (always visible), then
    // a fresh transparent Material + InkWell above it for the ripple. On `Ink`
    // the fill/border would sink into the ancestor Material below the page
    // gradient (see BloomCard for the same fix).
    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(BloomRadii.sm),
          child: Padding(padding: padding, child: inner),
        ),
      ),
    );
  }
}
