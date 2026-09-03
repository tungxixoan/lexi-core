import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A full-width toggle row with title, optional subtitle, and a Material Switch.
/// Tap anywhere on the row to toggle.
class BloomSwitch extends StatelessWidget {
  const BloomSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(BloomSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: c.ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: c.inkSoft,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: c.accent,
                  activeThumbColor: c.accentInk,
                  inactiveTrackColor: c.surface3,
                  inactiveThumbColor: c.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
