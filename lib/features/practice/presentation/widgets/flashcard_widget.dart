import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
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
    // A touch slower than the original 350ms so the face content has room to
    // fade in only once the card is settling flat (see [_contentReveal]).
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _flipAnim =
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_flipCtrl.isAnimating) return;
    if (_flipCtrl.value == 0) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }

  void _submit(bool understood) {
    widget.onResult(ExerciseResult(
      vocabRecordId: widget.exercise.vocabRecord.id,
      quality: understood ? 5 : 1,
      isCorrect: understood,
    ));
  }

  /// Opacity for the currently-shown face's *content*, as a function of the
  /// raw flip progress [v] (0 = front at rest, 1 = back at rest).
  ///
  /// The card only reads cleanly when it is roughly flat, so we keep the
  /// content fully transparent through the middle of the rotation and ramp it
  /// in over the final stretch. Result: a blank card face while it spins, and
  /// the answer appears only as the flip completes — no "showing through".
  static double _contentReveal(double v) {
    const ramp = 0.18;
    if (v <= ramp) return 1 - v / ramp; // front fading out as the flip starts
    if (v >= 1 - ramp) return (v - (1 - ramp)) / ramp; // back fading in at the end
    return 0; // mid-rotation: blank face
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
          child: Opacity(
            opacity: _contentReveal(_flipAnim.value).clamp(0.0, 1.0),
            child: showingBack
                ? _BackContent(record: record, onSubmit: _submit, onTapToFlip: _toggleFlip)
                : _FrontContent(record: record),
          ),
        );

        final transformed = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(displayAngle),
          child: face,
        );

        // Front: whole card is tappable to flip. Back: only _BackContent's
        // own gesture detector (around the meaning/example area, excluding
        // the two grading buttons) triggers a flip back — an ancestor
        // GestureDetector here would compete with the buttons' tap
        // recognizers in the gesture arena.
        return showingBack
            ? transformed
            : GestureDetector(onTap: _toggleFlip, child: transformed);
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // No maxHeight: a long meaning must be able to grow the card rather than
      // overflow it. The card is always hosted inside a scroll view, so an
      // over-tall card simply scrolls with the page.
      constraints: const BoxConstraints(minHeight: 280),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.bloom.surface,
        border: Border.all(color: context.bloom.border),
        borderRadius: BorderRadius.circular(22),
        boxShadow: BloomShadows.warm(
            Theme.of(context).brightness == Brightness.dark),
      ),
      child: child,
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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(record.headword,
            style: webScaled(
              const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            textAlign: TextAlign.center),
        if (record.ipa.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(record.ipa,
              style: webScaled(
                (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                    fontStyle: FontStyle.italic, color: context.bloom.inkSoft),
              )),
        ],
        const SizedBox(height: 8),
        BloomCefrPill(record.cefrLevel.label),
        const SizedBox(height: 24),
        Icon(Icons.touch_app_outlined, color: context.bloom.inkFaint, size: 20),
        const SizedBox(height: 4),
        Text('Chạm vào thẻ để xem đáp án',
            style: theme.textTheme.bodySmall?.copyWith(color: context.bloom.inkFaint)),
      ],
    );
  }
}

class _BackContent extends StatelessWidget {
  const _BackContent({
    required this.record,
    required this.onSubmit,
    required this.onTapToFlip,
  });
  final VocabRecord record;
  final void Function(bool understood) onSubmit;
  final VoidCallback onTapToFlip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final meaningBlock = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapToFlip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(record.meaning,
              style: webScaled(theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
              textAlign: TextAlign.center),
          if (record.examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('"${record.examples.first}"',
                style: webScaled(
                  (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14)).copyWith(
                      fontStyle: FontStyle.italic, color: context.bloom.inkSoft),
                ),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 12),
          Icon(Icons.flip_camera_android_outlined, color: context.bloom.inkFaint, size: 18),
          const SizedBox(height: 4),
          Text('Chạm để xem lại từ vựng',
              style: theme.textTheme.bodySmall?.copyWith(color: context.bloom.inkFaint)),
        ],
      ),
    );

    final gradeButtons = Row(
      children: [
        Expanded(
          child: BloomPillButton(
            label: 'Chưa hiểu',
            variant: BloomButtonVariant.danger,
            block: true,
            onPressed: () => onSubmit(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: BloomPillButton(
            label: 'Đã hiểu',
            variant: BloomButtonVariant.primary,
            block: true,
            onPressed: () => onSubmit(true),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bounded height (card hosted without a surrounding scroll view): let
        // the meaning/example area scroll *inside* the card, grade buttons
        // pinned below. Unbounded height (the normal case — hosted in a
        // SingleChildScrollView): let the content grow the card naturally.
        if (constraints.maxHeight.isFinite) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: SingleChildScrollView(child: meaningBlock)),
              const SizedBox(height: 24),
              gradeButtons,
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            meaningBlock,
            const SizedBox(height: 24),
            gradeButtons,
          ],
        );
      },
    );
  }
}
