// lib/features/dictionary/presentation/widgets/context_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../domain/entities/app_context.dart';
import '../providers/user_settings_provider.dart';

class ContextSelectorWidget extends ConsumerWidget {
  const ContextSelectorWidget({super.key});

  Future<void> _pickContext(BuildContext context, WidgetRef ref, AppContext active) async {
    final result = await showSingleSelectSheet<AppContext>(
      context: context,
      title: 'Ngữ cảnh',
      options: AppContext.values
          .map((c) => SelectOption(value: c, label: c.label, emoji: c.emoji))
          .toList(),
      selected: active,
    );
    if (result != null) {
      ref.read(userSettingsNotifierProvider.notifier).setActiveContext(result.value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      userSettingsNotifierProvider.select((s) => s.activeContext),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: FilterTile(
        icon: Icons.tune,
        label: 'Ngữ cảnh',
        value: '${active.emoji} ${active.label}',
        onTap: () => _pickContext(context, ref, active),
      ),
    );
  }
}
