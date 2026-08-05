import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../word_radar/domain/entities/word_radar_ai_result.dart';
import '../../../word_radar/presentation/widgets/vocab_suggestions_section.dart';
import '../../domain/entities/part6_passage.dart';
import '../providers/part6_practice_provider.dart';

class Part6ResultScreen extends ConsumerStatefulWidget {
  const Part6ResultScreen({super.key, required this.result});
  final Part6SessionResult result;

  @override
  ConsumerState<Part6ResultScreen> createState() => _Part6ResultScreenState();
}

class _Part6ResultScreenState extends ConsumerState<Part6ResultScreen> {
  Part6SessionResult get result => widget.result;

  AsyncValue<WordRadarAiResult>? _suggestions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
      _loadSuggestions();
    });
  }

  int get _totalQuestions =>
      result.set.passages.fold(0, (sum, p) => sum + p.questions.length);

  Future<void> _recordPracticeSession() async {
    try {
      await ref.read(statsServiceProvider).recordPracticeSession(_totalQuestions);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  String get _passagesText => result.set.passages.map((p) => p.passageText).join(' ');

  Future<void> _loadSuggestions() async {
    if (!ref.read(userSettingsNotifierProvider).aiEnabled) return;
    setState(() => _suggestions = const AsyncLoading());
    final aiResult = await AsyncValue.guard(
      () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
            text: _passagesText,
            targetLanguage: result.set.targetLanguage,
            targetCefrLevel: null,
          ),
    );
    if (mounted) setState(() => _suggestions = aiResult);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalQuestions;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả'), automaticallyImplyLeading: false),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                '${result.correctCount}/$total',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.correctCount == total
                      ? Colors.green.shade700
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var p = 0; p < result.set.passages.length; p++) ...[
                      if (p > 0) const SizedBox(height: 16),
                      _PassageBreakdown(
                        passageIndex: p,
                        passage: result.set.passages[p],
                        selectedAnswers: result.selectedAnswers,
                      ),
                    ],
                    _buildSuggestionsSection(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => _regenerate(context, ref), child: const Text('Bài khác')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => _goHome(context, ref), child: const Text('Về trang chính')),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection() {
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
            TextButton(onPressed: _loadSuggestions, child: const Text('Thử lại')),
          ],
        ),
        data: (r) => VocabSuggestionsSection(suggestions: r.suggestions),
      ),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/reading/part6');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(part6PracticeNotifierProvider.notifier).reset();
    context.go('/');
  }
}

class _PassageBreakdown extends StatelessWidget {
  const _PassageBreakdown({
    required this.passageIndex,
    required this.passage,
    required this.selectedAnswers,
  });

  final int passageIndex;
  final Part6Passage passage;
  final List<int?> selectedAnswers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đoạn ${passageIndex + 1}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(passage.passageText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (var q = 0; q < passage.questions.length; q++)
              _QuestionBreakdown(
                blankNumber: q + 1,
                question: passage.questions[q],
                selected: selectedAnswers[Part6SessionState.flatIndex(passageIndex, q)],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({required this.blankNumber, required this.question, required this.selected});

  final int blankNumber;
  final Part6Question question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = selected == question.correctIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text('Chỗ trống ($blankNumber)', style: theme.textTheme.titleSmall),
            ],
          ),
          ...question.options.asMap().entries.map((entry) {
            final i = entry.key;
            final isCorrectOption = i == question.correctIndex;
            final isSelectedOption = i == selected;
            Color? color;
            if (isCorrectOption) {
              color = Colors.green;
            } else if (isSelectedOption) {
              color = theme.colorScheme.error;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                entry.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: (isCorrectOption || isSelectedOption) ? FontWeight.bold : null,
                ),
              ),
            );
          }),
          Text(
            'Giải thích: ${question.explanation}',
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
