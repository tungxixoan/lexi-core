import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A `TextField` wrapped in Bloom styling: `surface2` ground, pill border
/// for single-line, `sm` rounded for multi-line, accent focus ring.
class BloomTextField extends StatefulWidget {
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
  State<BloomTextField> createState() => _BloomTextFieldState();
}

class _BloomTextFieldState extends State<BloomTextField> {
  late TextEditingController _controller;
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _isEmpty = _controller.text.isEmpty;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _isEmpty = _controller.text.isEmpty;
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final radius = (widget.maxLines ?? 2) == 1 ? BloomRadii.pill : BloomRadii.sm;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color),
        );
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: widget.obscureText,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      style: TextStyle(color: c.ink, fontSize: 16),
      decoration: InputDecoration(
        hintText: _isEmpty ? widget.hintText : null,
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
