import 'package:flutter/material.dart';
import 'bloom_tokens.dart';

class AppTheme {
  AppTheme._();

  static final light = _build(BloomColors.light, Brightness.light);
  static final dark = _build(BloomColors.dark, Brightness.dark);

  static ThemeData _build(BloomColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.sage,
      onSecondary: c.accentInk,
      error: c.danger,
      onError: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
      surfaceContainerHighest: c.surface3,
      surfaceContainerHigh: c.surface2,
      outline: c.border,
      outlineVariant: c.border,
    );

    final baseText = (brightness == Brightness.light
            ? Typography.blackMountainView
            : Typography.whiteMountainView)
        .apply(
            fontFamily: 'BeVietnamPro', bodyColor: c.ink, displayColor: c.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface2,
      fontFamily: 'BeVietnamPro',
      extensions: [c],
      textTheme: baseText.copyWith(
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium:
            baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: baseText.labelLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4),
        bodyLarge: baseText.bodyLarge?.copyWith(color: c.ink),
        bodyMedium: baseText.bodyMedium?.copyWith(color: c.inkSoft),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surface3,
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BloomRadii.lg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(BloomRadii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: baseText.bodyMedium?.copyWith(color: c.surface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withValues(alpha: 0.24),
        selectionHandleColor: c.accent,
      ),
    );
  }
}
