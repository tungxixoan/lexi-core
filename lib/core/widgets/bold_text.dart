import 'package:flutter/material.dart';
import '../utils/bold_markup.dart';

/// Renders the app's tiny `\n\n` + `**bold**` markup (see [parseBoldMarkup]).
class BoldText extends StatelessWidget {
  const BoldText({super.key, required this.source, this.style});

  final String source;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final paragraphs = parseBoldMarkup(source);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: base,
              children: [
                for (final run in paragraphs[i])
                  TextSpan(
                    text: run.text,
                    style: run.bold
                        ? base.copyWith(fontWeight: FontWeight.bold)
                        : base,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
