import 'package:flutter/material.dart';

/// A Card in the theme's error colors, used across home screens to explain
/// why a generate action is unavailable (AI disabled, not enough saved
/// words, etc).
class AiDisabledCard extends StatelessWidget {
  const AiDisabledCard({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
      ),
    );
  }
}
