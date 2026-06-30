import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lookup_provider.dart';
import '../providers/user_settings_provider.dart';

class SearchBarWidget extends ConsumerStatefulWidget {
  const SearchBarWidget({super.key});

  @override
  ConsumerState<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends ConsumerState<SearchBarWidget> {
  final _controller = TextEditingController();

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    ref.read(lookupNotifierProvider.notifier).lookup(query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(
      userSettingsNotifierProvider.select((s) => s.aiEnabled),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Word, phrase, or sentence...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.search),
            onPressed: _submit,
            tooltip: 'Lookup',
          ),
          if (aiEnabled) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.auto_awesome),
              onPressed: () =>
                  ref.read(lookupNotifierProvider.notifier).discover(),
              tooltip: 'Discover a new word',
            ),
          ],
        ],
      ),
    );
  }
}
