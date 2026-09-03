import 'package:flutter/material.dart';
import '../theme/bloom/bloom.dart';

/// A danger-tinted notice for home screens — not-enough-words,
/// unsupported-language, and similar reasons a generate action is unavailable.
class HomeNoticeCard extends StatelessWidget {
  const HomeNoticeCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BloomSpacing.lg),
      decoration: BoxDecoration(
        color: c.dangerBg,
        border: Border.all(color: c.danger),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      child: Text(message, style: TextStyle(color: c.danger)),
    );
  }
}
