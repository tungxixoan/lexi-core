import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/theme/bloom/bloom.dart';
import '../../../../core/widgets/save_exercise_button.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../../practice/domain/entities/saved_exercise.dart';
import '../../../word_radar/presentation/widgets/result_suggestions_section.dart';
import '../providers/reading_practice_provider.dart';

class ReadingResultScreen extends ConsumerStatefulWidget {
  const ReadingResultScreen({super.key, required this.result});
  final ReadingSessionResult result;

  @override
  ConsumerState<ReadingResultScreen> createState() => _ReadingResultScreenState();
}

class _ReadingResultScreenState extends ConsumerState<ReadingResultScreen> {
  ReadingSessionResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordPracticeSession();
    });
  }

  Future<void> _recordPracticeSession() async {
    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(result.passage.vocabIds.length);
    } catch (_) {
      // best-effort: don't crash the result screen on a stats update failure
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve against the SESSION's own language (result.passage.targetLanguage),
    // not the globally-scoped vocabBankProvider (which follows
    // userSettingsNotifierProvider's targetLanguage) — the reading home
    // screen has its own in-screen language picker, so the session can be
    // running in a language other than the current global setting.
    final vocabAsync = ref.watch(
      vocabListForLanguageProvider(result.passage.targetLanguage),
    );
    final vocabRecords = vocabAsync.valueOrNull ?? const <VocabRecord>[];

    final accuracyPct = (result.overallAccuracy * 100).toStringAsFixed(1);
    final wpm = result.wpm.toStringAsFixed(0);
    final elapsed = _formatDuration(result.totalDuration);
    final scorePct = (result.finalScore * 100).toStringAsFixed(1);

    final usedRecords = result.passage.vocabIds
        .map((id) => vocabRecords.where((r) => r.id == id).firstOrNull)
        .whereType<VocabRecord>()
        .toList();

    // A hardware/browser back from this nested route would surface a spurious
    // back arrow / pop to a transient screen — intercept it and go straight to
    // the Đọc & gõ home instead (same pattern as SessionResultScreen).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/reading/bilingual');
      },
      child: BloomScaffold(
        appBar: BloomAppBar(
          title: 'Kết quả',
          automaticallyImplyLeading: false,
          actions: [
            BloomIconButton(
              icon: Icons.copy,
              tooltip: 'Sao chép đoạn văn',
              onPressed: () => _copyPassage(context),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BloomCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('Độ chính xác', '$accuracyPct%'),
                    _stat('Tốc độ', '$wpm WPM'),
                    _stat('Thời gian', elapsed),
                    _stat('Điểm', '$scorePct%'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (usedRecords.isNotEmpty) ...[
                        Text(
                          'Từ vựng đã luyện',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.bloom.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final record in usedRecords)
                              BloomListRow(
                                cefr: record.cefrLevel.label,
                                headword: record.headword,
                                meaning: record.meaning,
                              ),
                          ],
                        ),
                      ],
                      ResultSuggestionsSection(
                        text: result.passage.fullText,
                        targetLanguage: result.passage.targetLanguage,
                        targetCefrLevel: result.passage.level,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SaveExerciseButton(
                type: SavedExerciseType.bilingual,
                reusedFromId: result.reusedFromId,
                buildPassageJson: () => result.passage.toJson(),
                generationFilters: result.generationFilters ??
                    <String, dynamic>{
                      'topicIds': <String>[],
                      'maxCefr': result.passage.level.name,
                      'wordCount': null,
                    },
                targetLanguage: result.passage.targetLanguage,
              ),
              BloomPillButton(
                label: 'Sinh bài mới',
                variant: BloomButtonVariant.primary,
                block: true,
                onPressed: () => _regenerate(context, ref),
              ),
              const SizedBox(height: 8),
              BloomPillButton(
                label: 'Về trang chính',
                variant: BloomButtonVariant.secondary,
                block: true,
                onPressed: () => _goHome(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.bloom.accent,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: context.bloom.inkSoft),
        ),
      ],
    );
  }

  void _copyPassage(BuildContext context) {
    Clipboard.setData(ClipboardData(text: result.passage.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép đoạn văn.')),
    );
  }

  void _regenerate(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/reading/bilingual');
  }

  void _goHome(BuildContext context, WidgetRef ref) {
    ref.read(readingPracticeNotifierProvider.notifier).reset();
    context.go('/');
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
