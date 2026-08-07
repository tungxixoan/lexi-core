import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../domain/entities/word_radar_ai_result.dart';
import 'vocab_suggestions_section.dart';

/// Loads and renders AI-suggested new vocabulary for [text]. Shared by every
/// practice result screen (Đọc & gõ, Nghe hiểu, Part 5, Part 6) instead of
/// each duplicating its own loading/error/retry state machine around
/// [VocabSuggestionsSection].
class ResultSuggestionsSection extends ConsumerStatefulWidget {
  const ResultSuggestionsSection({
    super.key,
    required this.text,
    required this.targetLanguage,
    required this.targetCefrLevel,
  });

  final String text;
  final Language targetLanguage;
  final CEFRLevel? targetCefrLevel;

  @override
  ConsumerState<ResultSuggestionsSection> createState() => _ResultSuggestionsSectionState();
}

class _ResultSuggestionsSectionState extends ConsumerState<ResultSuggestionsSection> {
  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final result = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: widget.text,
            targetLanguage: widget.targetLanguage,
            targetCefrLevel: widget.targetCefrLevel,
          ),
    );
    if (mounted) setState(() => _suggestions = result);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    if (suggestions == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: suggestions.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Không tải được gợi ý từ mới: $e'),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }
}
