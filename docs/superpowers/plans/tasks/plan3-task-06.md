# Plan 3 — Task 06: Exercise Widgets

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 01 (Exercise entities, ExerciseResult)

## Global Constraints
(see `plan3-global-constraints.md`)
- No tests required for UI-only widgets
- No business logic in widgets — all grading logic stays in the widget's State

## What This Task Delivers

4 stateful widgets, one per exercise type. Each receives the typed exercise + an `onResult(ExerciseResult)` callback. The widget handles user interaction and calls `onResult` with `quality: 5` (correct) or `quality: 1` (incorrect).

| Widget | Exercise type | Grading |
|--------|--------------|---------|
| `FlashcardWidget` | `FlashcardExercise` | User taps "Biết rồi" (5) or "Không biết" (1) |
| `MultipleChoiceWidget` | `MultipleChoiceExercise` | Auto: tap correct → 5, wrong → 1 |
| `FillInBlankWidget` | `FillInBlankExercise` | Auto: lowercase trim compare → 5 or 1 |
| `TranslationExerciseWidget` | `TranslationExercise` | User self-rates after seeing answer key |

## Files

- Create: `lib/features/practice/presentation/widgets/flashcard_widget.dart`
- Create: `lib/features/practice/presentation/widgets/multiple_choice_widget.dart`
- Create: `lib/features/practice/presentation/widgets/fill_in_blank_widget.dart`
- Create: `lib/features/practice/presentation/widgets/translation_exercise_widget.dart`

## flashcard_widget.dart

```dart
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
```

## multiple_choice_widget.dart

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class MultipleChoiceWidget extends StatefulWidget {
  const MultipleChoiceWidget({super.key, required this.exercise, required this.onResult});
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
        Text(widget.exercise.question, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ...widget.exercise.options.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          Color? bgColor;
          if (_selected != null) {
            if (i == widget.exercise.correctIndex) bgColor = Colors.green.shade100;
            else if (i == _selected) bgColor = Colors.red.shade100;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: bgColor != null
                      ? (bgColor == Colors.green.shade100 ? Colors.green : Colors.red)
                      : theme.colorScheme.outline,
                ),
              ),
              child: ListTile(
                title: Text(option),
                onTap: _selected == null ? () => _select(i) : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}
```

## fill_in_blank_widget.dart

```dart
import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class FillInBlankWidget extends StatefulWidget {
  const FillInBlankWidget({super.key, required this.exercise, required this.onResult});
  final FillInBlankExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<FillInBlankWidget> createState() => _FillInBlankWidgetState();
}

class _FillInBlankWidgetState extends State<FillInBlankWidget> {
  final _ctrl = TextEditingController();
  bool _submitted = false;
  bool? _isCorrect;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    if (_submitted) return;
    final correct = _ctrl.text.toLowerCase().trim() == widget.exercise.answer.toLowerCase().trim();
    setState(() { _submitted = true; _isCorrect = correct; });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        widget.onResult(ExerciseResult(
          vocabRecordId: widget.exercise.vocabRecord.id,
          quality: correct ? 5 : 1,
          isCorrect: correct,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = widget.exercise.sentence.split('___');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Điền vào chỗ trống:', style: theme.textTheme.labelLarge),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: theme.textTheme.titleMedium,
            children: [
              TextSpan(text: parts.first),
              WidgetSpan(
                child: Container(
                  width: 80, height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: theme.colorScheme.primary,
                ),
              ),
              if (parts.length > 1) TextSpan(text: parts.last),
            ],
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _ctrl,
          enabled: !_submitted,
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'Nhập từ cần điền...',
            border: const OutlineInputBorder(),
            suffixIcon: _submitted
                ? Icon(_isCorrect! ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect! ? Colors.green : Colors.red)
                : null,
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_submitted && !_isCorrect!) ...[
          const SizedBox(height: 8),
          Text('Đáp án: ${widget.exercise.answer}',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        if (!_submitted) FilledButton(onPressed: _submit, child: const Text('Kiểm tra')),
      ],
    );
  }
}
```

## translation_exercise_widget.dart

```dart
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
            child: Text('Đáp án: ${widget.exercise.answer}',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade800)),
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
                child: FilledButton(onPressed: () => _submit(true), child: const Text('Đúng rồi')),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
```

## Steps

- [ ] Create all 4 widget files
- [ ] `flutter analyze lib/features/practice/presentation/widgets/`
- [ ] Commit: `feat(plan3): add FlashcardWidget, MultipleChoiceWidget, FillInBlankWidget, TranslationExerciseWidget`
