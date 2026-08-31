import 'package:flutter/material.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
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
        const BloomSectionHeader('Dịch sang tiếng Việt'),
        const SizedBox(height: 12),
        BloomCard(
          child: Text(
            widget.exercise.prompt
                .replaceAll("Translate to Vietnamese: ", "")
                .replaceAll("'", ""),
            style: webScaled(theme.textTheme.titleMedium ?? const TextStyle(fontSize: 16)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        BloomTextField(
          controller: _ctrl,
          enabled: !_revealed,
          maxLines: 2,
          minLines: 2,
          hintText: 'Nhập bản dịch của bạn…',
        ),
        const SizedBox(height: 12),
        if (!_revealed)
          BloomPillButton(
            label: 'Xem đáp án',
            variant: BloomButtonVariant.primary,
            block: true,
            onPressed: _ctrl.text.trim().isEmpty ? null : _reveal,
          ),
        if (_revealed) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bloom.successBg,
              border: Border.all(color: context.bloom.success),
              borderRadius: BorderRadius.circular(BloomRadii.sm),
            ),
            child: Text(
              'Đáp án: ${widget.exercise.answer}',
              style: webScaled(
                  (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                      .copyWith(color: context.bloom.success)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BloomPillButton(
                  label: 'Sai rồi',
                  variant: BloomButtonVariant.danger,
                  block: true,
                  onPressed: () => _submit(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BloomPillButton(
                  label: 'Đúng rồi',
                  variant: BloomButtonVariant.primary,
                  block: true,
                  onPressed: () => _submit(true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
