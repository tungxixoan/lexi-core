import 'package:flutter/material.dart';
import '../theme/bloom/bloom.dart';

/// A danger-tinted notice used across home screens to explain why a generate
/// action is unavailable (AI not configured, not enough saved words, ...).
class AiDisabledCard extends StatelessWidget {
  const AiDisabledCard({super.key, required this.message});
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
