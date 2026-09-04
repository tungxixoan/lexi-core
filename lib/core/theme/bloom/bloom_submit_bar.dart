import 'package:flutter/material.dart';
import '../bloom_tokens.dart';
import 'bloom_pill_button.dart';

/// The "Đã trả lời N/M câu" progress line plus the primary submit button, shared
/// by the TOEIC Part 5/6/7 and Nghe hiểu session screens (matches the web).
class BloomSubmitBar extends StatelessWidget {
  const BloomSubmitBar({
    super.key,
    required this.answered,
    required this.total,
    required this.onSubmit,
    this.label = 'Nộp bài',
  });

  final int answered;
  final int total;
  final VoidCallback? onSubmit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Đã trả lời $answered/$total câu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.bloom.inkSoft),
        ),
        const SizedBox(height: 6),
        BloomPillButton(
          label: label,
          variant: BloomButtonVariant.primary,
          block: true,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}
