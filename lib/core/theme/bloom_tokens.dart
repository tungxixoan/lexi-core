import 'package:flutter/material.dart';

/// Bloom color palette, ported verbatim from
/// `apps/web/src/styles/bloom.css` (`:root` = light, the dark block = dark).
/// Attached to `ThemeData.extensions`; read via `context.bloom`.
@immutable
class BloomColors extends ThemeExtension<BloomColors> {
  const BloomColors({
    required this.bgA,
    required this.bgB,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.accent,
    required this.accentInk,
    required this.sage,
    required this.sageBg,
    required this.amber,
    required this.amberBg,
    required this.success,
    required this.successBg,
    required this.danger,
    required this.dangerBg,
    required this.border,
  });

  final Color bgA, bgB, surface, surface2, surface3;
  final Color ink, inkSoft, inkFaint;
  final Color accent, accentInk, sage, sageBg, amber, amberBg;
  final Color success, successBg, danger, dangerBg, border;

  static const light = BloomColors(
    bgA: Color(0xFFFFF3EE),
    bgB: Color(0xFFF1EEFF),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFBF3F7),
    surface3: Color(0xFFF5E9EF),
    ink: Color(0xFF362A33),
    inkSoft: Color(0xFF7A6B76),
    inkFaint: Color(0xFFA493A0),
    accent: Color(0xFFC9587A),
    accentInk: Color(0xFFFFFFFF),
    sage: Color(0xFF6F9A87),
    sageBg: Color(0xFFE7F1EB),
    amber: Color(0xFFD9A441),
    amberBg: Color(0xFFFBF0DC),
    success: Color(0xFF4C8F6E),
    successBg: Color(0xFFE7F1EB),
    danger: Color(0xFFC15B4E),
    dangerBg: Color(0xFFFBEAE6),
    border: Color(0xFFEFDDE3),
  );

  static const dark = BloomColors(
    bgA: Color(0xFF241923),
    bgB: Color(0xFF1C1B2B),
    surface: Color(0xFF2A2028),
    surface2: Color(0xFF322730),
    surface3: Color(0xFF3A2C36),
    ink: Color(0xFFF3E9EE),
    inkSoft: Color(0xFFC2AEB9),
    inkFaint: Color(0xFF8B7783),
    accent: Color(0xFFE693AC),
    accentInk: Color(0xFF2A121B),
    sage: Color(0xFF8FC1AA),
    sageBg: Color(0xFF203228),
    amber: Color(0xFFE8C173),
    amberBg: Color(0xFF3A2E17),
    success: Color(0xFF7DCBA6),
    successBg: Color(0xFF1E3128),
    danger: Color(0xFFE38A79),
    dangerBg: Color(0xFF3A241F),
    border: Color(0xFF43323C),
  );

  @override
  BloomColors copyWith({
    Color? bgA,
    Color? bgB,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? ink,
    Color? inkSoft,
    Color? inkFaint,
    Color? accent,
    Color? accentInk,
    Color? sage,
    Color? sageBg,
    Color? amber,
    Color? amberBg,
    Color? success,
    Color? successBg,
    Color? danger,
    Color? dangerBg,
    Color? border,
  }) {
    return BloomColors(
      bgA: bgA ?? this.bgA,
      bgB: bgB ?? this.bgB,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      inkFaint: inkFaint ?? this.inkFaint,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      sage: sage ?? this.sage,
      sageBg: sageBg ?? this.sageBg,
      amber: amber ?? this.amber,
      amberBg: amberBg ?? this.amberBg,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      border: border ?? this.border,
    );
  }

  @override
  BloomColors lerp(ThemeExtension<BloomColors>? other, double t) {
    if (other is! BloomColors) return this;
    return BloomColors(
      bgA: Color.lerp(bgA, other.bgA, t)!,
      bgB: Color.lerp(bgB, other.bgB, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageBg: Color.lerp(sageBg, other.sageBg, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberBg: Color.lerp(amberBg, other.amberBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

/// Read Bloom colors from a `BuildContext`. Requires a `BloomColors`
/// extension on the ambient `ThemeData` (wired by `AppTheme`).
extension BloomContext on BuildContext {
  BloomColors get bloom => Theme.of(this).extension<BloomColors>()!;
}
