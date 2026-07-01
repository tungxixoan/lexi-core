import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({super.key, required this.exercise, required this.onResult});
  final FlashcardExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  bool _revealed = false;

  void _reveal() => setState(() => _revealed = true);

  void _submit(bool knew) {
    widget.onResult(ExerciseResult(
      vocabRecordId: widget.exercise.vocabRecord.id,
      quality: knew ? 5 : 1,
      isCorrect: knew,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.exercise.vocabRecord;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(record.headword,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                if (record.ipa.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(record.ipa,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.secondary)),
                ],
                const SizedBox(height: 24),
                if (!_revealed)
                  OutlinedButton(onPressed: _reveal, child: const Text('Xem đáp án'))
                else ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(record.meaning, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                  if (record.examples.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('"${record.examples.first}"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
                        textAlign: TextAlign.center),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_revealed) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _submit(false),
                  style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                  child: const Text('Không biết'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: () => _submit(true), child: const Text('Biết rồi')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
