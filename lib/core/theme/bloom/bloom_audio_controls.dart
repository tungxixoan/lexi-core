import 'package:flutter/material.dart';

import '../bloom_tokens.dart';
import 'bloom_app_bar.dart'; // BloomIconButton

/// The audio transport for the listening session screens. [BloomAudioControls.playOnly]
/// is the single Play/Nghe-lại pill (Nghe chép); [BloomAudioControls.transport] adds
/// ⏮ ⏭ ↺ around it (Nghe hiểu). Ports web's `.dictation-controls`.
class BloomAudioControls extends StatelessWidget {
  const BloomAudioControls.playOnly({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.playLabel,
  })  : onPrevious = null,
        onNext = null,
        onReplay = null,
        _transport = false;

  const BloomAudioControls.transport({
    super.key,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onReplay,
    this.playLabel = 'Phát',
  }) : _transport = true;

  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReplay;
  final String playLabel;
  final bool _transport;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_transport) ...[
          BloomIconButton(
              icon: Icons.skip_previous,
              onPressed: onPrevious,
              tooltip: 'Lượt trước'),
          const SizedBox(width: BloomSpacing.md),
        ],
        _PlayPill(
            isPlaying: isPlaying, label: playLabel, onTap: onPlayPause),
        if (_transport) ...[
          const SizedBox(width: BloomSpacing.md),
          BloomIconButton(
              icon: Icons.skip_next,
              onPressed: onNext,
              tooltip: 'Lượt sau'),
          const SizedBox(width: BloomSpacing.md),
          BloomIconButton(
              icon: Icons.replay,
              onPressed: onReplay,
              tooltip: 'Nghe lại từ đầu'),
        ],
      ],
    );
  }
}

class _PlayPill extends StatelessWidget {
  const _PlayPill({required this.isPlaying, required this.label, required this.onTap});
  final bool isPlaying;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(BloomRadii.pill),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: BloomSpacing.xl, vertical: BloomSpacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isPlaying ? Icons.stop : Icons.play_arrow,
                      size: 20, color: c.accentInk),
                  const SizedBox(width: 8),
                  Text(isPlaying ? 'Dừng' : label,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.accentInk)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
