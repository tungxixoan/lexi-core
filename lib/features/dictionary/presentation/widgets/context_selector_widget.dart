// lib/features/dictionary/presentation/widgets/context_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_context.dart';
import '../providers/user_settings_provider.dart';

class ContextSelectorWidget extends ConsumerWidget {
  const ContextSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      userSettingsNotifierProvider.select((s) => s.activeContext),
    );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: AppContext.values.map((ctx) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${ctx.emoji} ${ctx.label}'),
              selected: ctx == active,
              onSelected: (_) => ref
                  .read(userSettingsNotifierProvider.notifier)
                  .setActiveContext(ctx),
            ),
          );
        }).toList(),
      ),
    );
  }
}
