import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({super.key, required this.exercise, required this.onResult});
  final FlashcardExercise exercise;
  final void Function(ExerciseResult) onResult;

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _flipAnim =
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
  bool _revealed = false;

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _flip() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flipCtrl.forward();
  }

  void _submit(bool understood) {
    widget.onResult(ExerciseResult(
      vocabRecordId: widget.exercise.vocabRecord.id,
      quality: understood ? 5 : 1,
      isCorrect: understood,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.exercise.vocabRecord;

    return AnimatedBuilder(
      animation: _flipAnim,
      builder: (context, _) {
        final angle = _flipAnim.value * math.pi;
        final showingBack = angle > math.pi / 2;
        final displayAngle = showingBack ? angle - math.pi : angle;

        final face = _CardFace(
          child: showingBack
              ? _BackContent(record: record, onSubmit: _submit)
              : _FrontContent(record: record),
        );

        final transformed = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(displayAngle),
          child: face,
        );

        // Only the front face is tappable — once flipped, the back's own
        // buttons handle progression so they don't compete with an ancestor
        // tap recognizer.
        return showingBack
            ? transformed
            : GestureDetector(onTap: _flip, child: transformed);
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 240),
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }
}

class _FrontContent extends StatelessWidget {
  const _FrontContent({required this.record});
  final VocabRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(record.headword,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        if (record.ipa.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(record.ipa,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic, color: theme.colorScheme.secondary)),
        ],
        const SizedBox(height: 24),
        Icon(Icons.touch_app_outlined, color: theme.colorScheme.outline, size: 20),
        const SizedBox(height: 4),
        Text('Chạm vào thẻ để xem đáp án',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

class _BackContent extends StatelessWidget {
  const _BackContent({required this.record, required this.onSubmit});
  final VocabRecord record;
  final void Function(bool understood) onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(record.meaning, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
        if (record.examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('"${record.examples.first}"',
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic, color: theme.colorScheme.outline),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => onSubmit(false),
                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                child: const Text('Chưa hiểu'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => onSubmit(true),
                child: const Text('Đã hiểu'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
