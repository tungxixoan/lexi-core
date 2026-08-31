import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A `TextField` wrapped in Bloom styling: `surface2` ground, pill border
/// for single-line, `sm` rounded for multi-line, accent focus ring.
class BloomTextField extends StatelessWidget {
  const BloomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final int? maxLines;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final radius = (maxLines ?? 2) == 1 ? BloomRadii.pill : BloomRadii.sm;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      enabled: enabled,
      autofocus: autofocus,
      style: TextStyle(color: c.ink, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: c.inkFaint),
        filled: true,
        fillColor: c.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: border(c.border),
        focusedBorder: border(c.accent),
        disabledBorder: border(c.border),
      ),
    );
  }
}
