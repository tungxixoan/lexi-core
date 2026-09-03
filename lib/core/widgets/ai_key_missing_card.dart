import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/bloom/bloom.dart';

/// Shown on a home screen when the active AI provider has no stored API key —
/// links to Settings where the user adds one.
class AiKeyMissingCard extends StatelessWidget {
  const AiKeyMissingCard({super.key});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm.',
            style: TextStyle(color: c.danger),
          ),
          const SizedBox(height: BloomSpacing.md),
          BloomPillButton(
            label: 'Mở Cài đặt',
            variant: BloomButtonVariant.secondary,
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}
