import 'package:flutter/material.dart';
import '../../../../core/utils/web_text_scale.dart';
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    final correct = _ctrl.text.toLowerCase().trim() == widget.exercise.answer.toLowerCase().trim();
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });
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
            style: webScaled(theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16)),
            children: [
              TextSpan(text: parts.first),
              WidgetSpan(
                child: Container(
                  width: 80,
                  height: 2,
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
                ? Icon(
                    _isCorrect! ? Icons.check_circle : Icons.cancel,
                    color: _isCorrect! ? Colors.green : Colors.red,
                  )
                : null,
          ),
          onSubmitted: (_) => _submit(),
        ),
        if (_submitted && !_isCorrect!) ...[
          const SizedBox(height: 8),
          Text(
            'Đáp án: ${widget.exercise.answer}',
            style: webScaled(
              (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                  .copyWith(color: Colors.green.shade700),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        if (!_submitted) FilledButton(onPressed: _submit, child: const Text('Kiểm tra')),
      ],
    );
  }
}
