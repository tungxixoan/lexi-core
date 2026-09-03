import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/bloom/bloom.dart';
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
    final aiAvailable = ref.watch(
      userSettingsNotifierProvider.select((s) => s.aiAvailable),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: BloomTextField(
                  controller: _controller,
                  hintText: 'Từ, cụm từ, hoặc câu…',
                  prefixIcon: Icons.search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              BloomIconButton(
                icon: Icons.arrow_forward,
                tooltip: 'Tra từ',
                onPressed: _submit,
              ),
            ],
          ),
          if (aiAvailable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: BloomPillButton(
                label: 'Khám phá',
                icon: Icons.auto_awesome,
                variant: BloomButtonVariant.sage,
                onPressed: () =>
                    ref.read(lookupNotifierProvider.notifier).discover(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
