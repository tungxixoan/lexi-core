import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// The web has far more screen real estate than mobile, so primary reading
/// content (passages, questions, options, explanations) is scaled up for
/// legibility on web. No-op on mobile.
TextStyle webScaled(TextStyle style) {
  if (!kIsWeb) return style;
  return style.copyWith(fontSize: (style.fontSize ?? 16) * 1.5);
}
