import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';
import '../../../../core/utils/web_text_scale.dart';
import '../../../dictionary/presentation/widgets/pronounce_button.dart';
import '../../../vocabulary/domain/entities/vocab_record.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_result.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({
    super.key,
    required this.exercise,
    required this.onResult,
    this.onPronounce,
  });
  final FlashcardExercise exercise;
  final void Function(ExerciseResult) onResult;

  /// Speak the headword. Null → no listen button (unsupported target language).
  final VoidCallback? onPronounce;

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
    // Guard against a tap landing on an invisible grade button mid-flip: the
    // buttons sit in an opacity-0 subtree during the ~450ms flip but stay
    // hit-testable, so a stray double-tap could grade a word never seen.
    if (_flipCtrl.isAnimating) return;
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
    // Front fades out as the flip starts; back fades in at the end; blank
    // through the middle of the rotation.
    if (v <= ramp) return 1 - v / ramp;
    if (v >= 1 - ramp) return (v - (1 - ramp)) / ramp;
    return 0;
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
                ? _BackContent(
                    record: record, onSubmit: _submit, onTapToFlip: _toggleFlip)
                : _FrontContent(
                    record: record, onPronounce: widget.onPronounce),
          ),
        );

        // Diagonal tumble: a left-to-right page turn (rotateY) tilted downward
        // (rotateX) so the card flips corner-over-corner rather than top-down.
        final transformed = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(displayAngle)
            ..rotateX(displayAngle * 0.4),
          child: face,
        );

        // Front: whole card is tappable to flip. Back: the whole area above
        // the grade buttons (including the blank space) flips back — the grade
        // buttons are siblings, not descendants, so there is no gesture-arena
        // fight with their tap recognizers.
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
    // A fixed height so the front and back faces are identical in size — the
    // card must not resize as it flips. Kept modest so a short meaning doesn't
    // leave a large empty gap; long content scrolls inside (see _BackContent).
    final h = (MediaQuery.sizeOf(context).height * 0.50).clamp(340.0, 460.0);

    return Container(
      key: const Key('flashcard-face'),
      width: double.infinity,
      height: h,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.bloom.surface,
        border: Border.all(color: context.bloom.border),
        borderRadius: BorderRadius.circular(22),
        boxShadow:
            BloomShadows.warm(Theme.of(context).brightness == Brightness.dark),
      ),
      child: child,
    );
  }
}

class _FrontContent extends StatelessWidget {
  const _FrontContent({required this.record, this.onPronounce});
  final VocabRecord record;
  final VoidCallback? onPronounce;

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
                (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                    .copyWith(
                        fontStyle: FontStyle.italic,
                        color: context.bloom.inkSoft),
              )),
        ],
        if (onPronounce != null) ...[
          const SizedBox(height: 12),
          PronounceButton(onPressed: onPronounce!, size: 34),
        ],
        const SizedBox(height: 10),
        BloomCefrPill(record.cefrLevel.label),
        const SizedBox(height: 20),
        Icon(Icons.touch_app_outlined, color: context.bloom.inkSoft, size: 20),
        const SizedBox(height: 4),
        Text('Chạm vào thẻ để xem đáp án',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.bloom.inkSoft)),
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

    final meaningBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(record.meaning,
            style: webScaled(
                theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)),
            textAlign: TextAlign.center),
        if (record.examples.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('"${record.examples.first}"',
              style: webScaled(
                (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
                    .copyWith(
                        fontStyle: FontStyle.italic,
                        color: context.bloom.inkSoft),
              ),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: 12),
        Icon(Icons.flip_camera_android_outlined,
            color: context.bloom.inkSoft, size: 18),
        const SizedBox(height: 4),
        Text('Chạm để xem lại từ vựng',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: context.bloom.inkSoft)),
      ],
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

    // The whole area above the grade buttons — content AND blank space — flips
    // the card back. Short content is vertically centred; long content scrolls
    // inside (the ConstrainedBox makes the scroll child fill the viewport so
    // Center has a bounded box to work with).
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapToFlip,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: meaningBlock),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        gradeButtons,
      ],
    );
  }
}
