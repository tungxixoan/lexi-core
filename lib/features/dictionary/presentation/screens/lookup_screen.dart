import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lookup_result.dart';
import '../providers/lookup_provider.dart';
import '../widgets/context_selector_widget.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/sentence_result_widget.dart';
import '../widgets/word_result_widget.dart';

class LookupScreen extends ConsumerWidget {
  const LookupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lookupState = ref.watch(lookupNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LexiCore'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          const ContextSelectorWidget(),
          const SearchBarWidget(),
          const Divider(height: 1),
          Expanded(
            child: lookupState.when(
              data: (result) {
                if (result == null) {
                  return const Center(
                    child: Text(
                      'Enter a word, phrase, or sentence to get started.',
                      textAlign: TextAlign.center,
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
