import 'package:flutter/material.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class MultipleChoiceWidget extends StatefulWidget {
  const MultipleChoiceWidget(
      {super.key, required this.exercise, required this.onResult});
  final MultipleChoiceExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<MultipleChoiceWidget> createState() => _MultipleChoiceWidgetState();
}

class _MultipleChoiceWidgetState extends State<MultipleChoiceWidget> {
  int? _selected;

  void _select(int index) {
    if (_selected != null) return;
    setState(() => _selected = index);
    final isCorrect = index == widget.exercise.correctIndex;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        widget.onResult(ExerciseResult(
          vocabRecordId: widget.exercise.vocabRecord.id,
          quality: isCorrect ? 5 : 1,
          isCorrect: isCorrect,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.exercise.question,
          style: webScaled(
              theme.textTheme.titleLarge ?? const TextStyle(fontSize: 22)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ...widget.exercise.options.asMap().entries.map((entry) {
          final i = entry.key;
          BloomMcState state = BloomMcState.neutral;
          if (_selected != null) {
            if (i == widget.exercise.correctIndex) {
              state = BloomMcState.correct;
            } else if (i == _selected) {
              state = BloomMcState.wrong;
            }
          } else if (i == _selected) {
            state = BloomMcState.selected;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: BloomMcOption(
              label: entry.value,
              state: state,
              onTap: _selected == null ? () => _select(i) : null,
            ),
          );
        }),
      ],
    );
  }
}
