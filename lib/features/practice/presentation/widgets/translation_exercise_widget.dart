import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class TranslationExerciseWidget extends StatefulWidget {
  const TranslationExerciseWidget({super.key, required this.exercise, required this.onResult});
  final TranslationExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<TranslationExerciseWidget> createState() => _TranslationExerciseWidgetState();
}

class _TranslationExerciseWidgetState extends State<TranslationExerciseWidget> {
  final _ctrl = TextEditingController();
  bool _revealed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reveal() => setState(() => _revealed = true);

  void _submit(bool correct) {
    widget.onResult(ExerciseResult(
      vocabRecordId: widget.exercise.vocabRecord.id,
      quality: correct ? 5 : 1,
      isCorrect: correct,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Dịch sang tiếng Việt:', style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.exercise.prompt
                  .replaceAll("Translate to Vietnamese: ", "")
                  .replaceAll("'", ""),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          enabled: !_revealed,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Nhập bản dịch của bạn...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (!_revealed)
          FilledButton(
            onPressed: _ctrl.text.trim().isEmpty ? null : _reveal,
            child: const Text('Xem đáp án'),
          ),
        if (_revealed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Text(
              'Đáp án: ${widget.exercise.answer}',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade800),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _submit(false),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text('Sai rồi'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _submit(true),
                  child: const Text('Đúng rồi'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
