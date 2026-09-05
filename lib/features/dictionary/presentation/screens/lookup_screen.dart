import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/lookup_provider.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sentence_result_widget.dart';
import '../widgets/word_result_widget.dart';

class LookupScreen extends ConsumerWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(lookupNotifierProvider);
    final c = context.bloom;

    return BloomScaffold(
      appBar: BloomAppBar(
        title: 'LexiCore',
        leading: const BloomLeafMark(size: 22),
      ),
      body: Column(
        children: [
          const SearchBarWidget(),
          Divider(height: 1, color: c.border),
          Expanded(
            child: lookupState.when(
              data: (result) {
                if (result == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nhập một từ, cụm từ, hoặc câu để bắt đầu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.inkSoft),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  child: switch (result) {
                    WordPhraseResult r => WordResultWidget(result: r),
                    SentenceResult r => SentenceResultWidget(result: r),
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.danger),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
