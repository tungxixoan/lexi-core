import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../../domain/entities/reading_passage.dart';
import '../providers/reading_practice_provider.dart';

/// The web has far more screen real estate than mobile, so text on this
/// screen (passage, translation, typing input) is scaled up for legibility.
TextStyle _webScaled(TextStyle style) {
  if (!kIsWeb) return style;
  return style.copyWith(fontSize: (style.fontSize ?? 16) * 1.5);
}

class ReadingSessionScreen extends ConsumerStatefulWidget {
  const ReadingSessionScreen({super.key});

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTyped(String text, ReadingSessionState session) {
    ref.read(readingPracticeNotifierProvider.notifier).updateTypedText(text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ReadingSessionState?>>(
      readingPracticeNotifierProvider,
      (prev, next) {
        final session = next.valueOrNull;
        if (session == null) return;

        final prevIndex = prev?.valueOrNull?.currentSentenceIndex;
        if (prevIndex != null &&
            session.currentSentenceIndex != prevIndex) {
          _ctrl.clear();
          _focusNode.requestFocus();
        }

        if (session.isComplete) {
          final result = ReadingSessionResult(
            passage: session.passage,
            sentenceResults: session.completedSentences,
            totalDuration:
                DateTime.now().difference(session.sessionStartedAt),
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/reading/session/result', extra: result);
            }
          });
        }
      },
    );

    final sessionAsync = ref.watch(readingPracticeNotifierProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/reading');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // Safety guard: never render _SessionScaffold when isComplete is true
        // because currentSentence throws RangeError (index == sentences.length).
        // Navigation is already scheduled via ref.listen above.
        if (session.isComplete) {
          return const Scaffold(body: SizedBox.shrink());
        }
        return _SessionScaffold(
          session: session,
          ctrl: _ctrl,
          focusNode: _focusNode,
          onTyped: _onTyped,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}

class _SessionScaffold extends ConsumerWidget {
  const _SessionScaffold({
    required this.session,
    required this.ctrl,
    required this.focusNode,
    required this.onTyped,
  });

  final ReadingSessionState session;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final void Function(String, ReadingSessionState) onTyped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabRecords = ref.watch(vocabBankProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Câu ${session.currentSentenceIndex + 1} / ${session.passage.sentences.length}',
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép đoạn văn',
            onPressed: () => _copyPassage(context, session),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: passage with opacity
            Expanded(
              child: _PassageDisplay(
                passage: session.passage,
                currentIndex: session.currentSentenceIndex,
                vocabRecords: vocabRecords,
              ),
            ),
            const Divider(height: 24),
            // Row 2: Vietnamese translation
            _VietnameseRow(
              sentence: session.currentSentence,
            ),
            const SizedBox(height: 16),
            // Row 3: typing area
            _TypingArea(
              target: session.currentSentence.target,
              typedText: session.typedText,
              ctrl: ctrl,
              focusNode: focusNode,
              onTyped: (text) => onTyped(text, session),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: session.currentSentenceIndex /
                  session.passage.sentences.length,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  void _copyPassage(BuildContext context, ReadingSessionState session) {
    Clipboard.setData(ClipboardData(text: session.passage.fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép đoạn văn.')),
    );
  }
}

class _PassageDisplay extends StatelessWidget {
  const _PassageDisplay({
    required this.passage,
    required this.currentIndex,
    required this.vocabRecords,
  });

  final ReadingPassage passage;
  final int currentIndex;
  final List<VocabRecord> vocabRecords;

  double _opacity(int sentenceIndex) {
    final delta = sentenceIndex - currentIndex;
    if (delta < 0) return 0.3; // already typed
    if (delta == 0) return 1.0; // current
    if (delta == 1) return 0.4; // next
    return 0.2; // locked
  }

  List<String> _getHighlightWords(BilingualSentence sentence) {
    return sentence.vocabIds
        .map((id) => vocabRecords
            .where((r) => r.id == id)
            .map((r) => r.headword)
            .firstOrNull)
        .whereType<String>()
        .where((w) => w.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: passage.sentences.asMap().entries.map((entry) {
          final i = entry.key;
          final sentence = entry.value;
          final highlights = _getHighlightWords(sentence);
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _opacity(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _HighlightedText(
                text: sentence.target,
                highlights: highlights,
                style: _webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.highlights,
    this.style,
  });

  final String text;
  final List<String> highlights;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty) {
      return Text(text, style: style);
    }
    final spans = <TextSpan>[];
    String remaining = text;
    while (remaining.isNotEmpty) {
      int? earliestStart;
      String? earliestWord;
      for (final word in highlights) {
        final idx = remaining.toLowerCase().indexOf(word.toLowerCase());
        if (idx >= 0 && (earliestStart == null || idx < earliestStart)) {
          earliestStart = idx;
          earliestWord = word;
        }
      }
      if (earliestStart == null || earliestWord == null) {
        spans.add(TextSpan(text: remaining, style: style));
        break;
      }
      if (earliestStart > 0) {
        spans.add(
            TextSpan(text: remaining.substring(0, earliestStart), style: style));
      }
      spans.add(TextSpan(
        text: remaining.substring(
            earliestStart, earliestStart + earliestWord.length),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ));
      remaining = remaining.substring(earliestStart + earliestWord.length);
    }
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

class _VietnameseRow extends StatelessWidget {
  const _VietnameseRow({required this.sentence});
  final BilingualSentence sentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(sentence.target),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          sentence.vietnamese,
          style: _webScaled(
            (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                .copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class _TypingArea extends StatelessWidget {
  const _TypingArea({
    required this.target,
    required this.typedText,
    required this.ctrl,
    required this.focusNode,
    required this.onTyped,
  });

  final String target;
  final String typedText;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final ValueChanged<String> onTyped;

  List<TextSpan> _buildSpans(BuildContext context, TextStyle baseStyle) {
    final theme = Theme.of(context);
    final spans = <TextSpan>[];
    for (int i = 0; i < target.length; i++) {
      if (i < typedText.length) {
        final correct = typedText[i] == target[i];
        spans.add(TextSpan(
          text: typedText[i],
          style: baseStyle.copyWith(
            color: correct
                ? Colors.green
                : theme.colorScheme.error,
            backgroundColor: correct
                ? null
                : theme.colorScheme.error.withValues(alpha: 0.1),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: target[i],
          style: baseStyle.copyWith(color: theme.colorScheme.outline),
        ));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The colored text (RichText) and the invisible input caret (TextField)
    // are stacked on top of each other, so they MUST share the exact same
    // font metrics — otherwise every typed character drifts a little further
    // out of alignment with the visible text underneath it.
    final baseStyle = _webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16));
    final strutStyle = StrutStyle.fromTextStyle(baseStyle);
    return Container(
      constraints: BoxConstraints(minHeight: kIsWeb ? 200 : 80),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          IgnorePointer(
            child: RichText(
              strutStyle: strutStyle,
              text: TextSpan(
                style: baseStyle,
                children: _buildSpans(context, baseStyle),
              ),
            ),
          ),
          TextField(
            controller: ctrl,
            focusNode: focusNode,
            maxLines: null,
            autofocus: true,
            style: baseStyle.copyWith(color: Colors.transparent),
            strutStyle: strutStyle,
            cursorColor: theme.colorScheme.primary,
            decoration: const InputDecoration.collapsed(hintText: ''),
            onChanged: onTyped,
          ),
        ],
      ),
    );
  }
}
