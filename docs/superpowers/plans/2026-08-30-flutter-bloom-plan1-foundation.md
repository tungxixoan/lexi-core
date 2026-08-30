# Flutter Bloom — Plan 1: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Bloom design system in Flutter — color/layout tokens, the Be Vietnam Pro font, a reusable Bloom widget library, a reworked `AppTheme`, a Sáng/Tối/Hệ thống theme setting, and the app shell restyled — without touching any feature screen beyond the shell.

**Architecture:** Port `apps/web/src/styles/bloom.css` into `lib/core/theme/bloom_tokens.dart` as a `ThemeExtension` plus plain token classes. Build small, single-purpose widgets under `lib/core/theme/bloom/`, each with its own widget test. `AppTheme` keeps Material's `ThemeData` (for low-level Material widgets still in use) but maps its `ColorScheme` onto Bloom tokens and attaches the `BloomColors` extension. `main.dart` drives `themeMode` from a new local-only setting. The shell (`app_shell.dart`) is the only feature-adjacent file this plan rewrites.

**Tech Stack:** Flutter 3.x / Dart ≥3.4, `flutter_riverpod` + `riverpod_annotation` + `build_runner` codegen, `shared_preferences`, `go_router` (untouched here), `flutter_test`.

## Global Constraints

- Dart SDK `>=3.4.0 <4.0.0`; Flutter 3.x; `useMaterial3: true` stays on.
- After editing any `@riverpod` provider: run `dart run build_runner build --delete-conflicting-outputs` and commit the regenerated `*.g.dart`.
- Every Bloom color value is copied **verbatim** from `apps/web/src/styles/bloom.css` (`:root` = light, the dark block = dark). Do not invent or adjust colors.
- Font **Be Vietnam Pro** is bundled offline under `assets/fonts/` — never loaded from the network. Family name string: `BeVietnamPro`.
- `flutter analyze` must report **zero issues** at the end of every task.
- Do not modify anything under `apps/web/`.
- Do not change routes, `go_router` config, or the set/order of nav destinations. IA is unchanged.
- Radii: `sm = 10`, `md = 16`, `lg = 20`, `pill = 999`. Do not use other radii for Bloom widgets.
- Existing test count is ~474; keep them green. When a widget swap breaks a finder, fix the finder (prefer `find.text` / `find.byKey` / `find.byType(BloomX)`) — never weaken a behavior assertion.

---

## File Structure

**Created:**
- `lib/core/theme/bloom_tokens.dart` — `BloomColors` (ThemeExtension, light+dark), `BloomRadii`, `BloomSpacing`, `BloomShadows`, `BloomGradients`, `BloomContext` extension. One file: these are always used together.
- `lib/core/theme/bloom/bloom_scaffold.dart`
- `lib/core/theme/bloom/bloom_app_bar.dart` — `BloomAppBar` + `BloomIconButton`
- `lib/core/theme/bloom/bloom_card.dart`
- `lib/core/theme/bloom/bloom_pill_button.dart`
- `lib/core/theme/bloom/bloom_chip.dart` — `BloomChip` + `BloomCefrPill`
- `lib/core/theme/bloom/bloom_progress_bar.dart`
- `lib/core/theme/bloom/bloom_labels.dart` — `BloomSectionHeader` + `BloomLeafMark`
- `lib/core/theme/bloom/bloom_text_field.dart`
- `lib/core/theme/bloom/bloom_list_row.dart`
- `lib/core/theme/bloom/bloom_bottom_nav.dart` — `BloomBottomNav` + `BloomNavRail`
- `lib/core/theme/bloom/bloom.dart` — barrel export of everything above + tokens
- Test files mirroring each of the above under `test/core/theme/bloom/`

**Modified:**
- `lib/core/theme/app_theme.dart` — rework
- `lib/features/dictionary/domain/entities/user_settings_state.dart` — add `themePreference`, add `aiAvailable` getter
- `lib/features/dictionary/presentation/providers/user_settings_provider.dart` — `setThemePreference`, read `theme_preference`
- `lib/main.dart` — `themeMode` from provider
- `lib/core/widgets/filter_tile.dart` — Bloom restyle (public API unchanged)
- `lib/core/widgets/selection_sheets.dart` — Bloom restyle (public API unchanged)
- `lib/core/widgets/app_shell.dart` — use `BloomScaffold` + `BloomBottomNav` / `BloomNavRail`
- `CLAUDE.md` — add `## Theme` section
- affected existing tests: `test/core/widgets/app_shell_test.dart`, any `filter_tile` / `selection_sheets` test

**Not in this plan:** feature screens (dictionary, vocab, practice, reading, listening, word radar, progress, settings, sign-in), `activeContext` removal (Plan 2), `aiEnabled` field/toggle removal (Plan 6 — this plan only *adds* the `aiAvailable` getter alongside it), feature-specific Bloom widgets (`BloomPassageSheet`, `BloomExpansionTile`, `BloomBarChart`, `BloomStatCard`, `BloomAudioControls`, `BloomWordSeekBar`, `BloomSegmented`, `BloomSwitch`, `BloomMcOption`, `AiKeyMissingCard` — each built in the plan that first needs it).

---

## Task 1: Bloom color tokens

**Files:**
- Create: `lib/core/theme/bloom_tokens.dart`
- Test: `test/core/theme/bloom_tokens_test.dart`

**Interfaces:**
- Produces:
  - `class BloomColors extends ThemeExtension<BloomColors>` with `final Color` fields: `bgA, bgB, surface, surface2, surface3, ink, inkSoft, inkFaint, accent, accentInk, sage, sageBg, amber, amberBg, success, successBg, danger, dangerBg, border`
  - `static const BloomColors light`, `static const BloomColors dark`
  - `extension BloomContext on BuildContext { BloomColors get bloom; }`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom_tokens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

void main() {
  test('light and dark accents match bloom.css verbatim', () {
    expect(BloomColors.light.accent, const Color(0xFFC9587A));
    expect(BloomColors.dark.accent, const Color(0xFFE693AC));
    expect(BloomColors.light.border, const Color(0xFFEFDDE3));
    expect(BloomColors.dark.surface, const Color(0xFF2A2028));
  });

  test('lerp(0) is this, lerp(1) is other', () {
    final mid = BloomColors.light.lerp(BloomColors.dark, 1.0);
    expect(mid.accent, BloomColors.dark.accent);
    expect(BloomColors.light.lerp(BloomColors.dark, 0.0).accent,
        BloomColors.light.accent);
  });

  testWidgets('context.bloom resolves the extension', (tester) async {
    late BloomColors seen;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: const [BloomColors.light]),
      home: Builder(builder: (context) {
        seen = context.bloom;
        return const SizedBox();
      }),
    ));
    expect(seen.accent, BloomColors.light.accent);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom_tokens_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../bloom_tokens.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/theme/bloom_tokens.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom_tokens_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom_tokens.dart test/core/theme/bloom_tokens_test.dart
git commit -m "feat(theme): Bloom color tokens ported from bloom.css"
```

---

## Task 2: Bloom layout tokens (radii, spacing, shadows, gradients)

**Files:**
- Modify: `lib/core/theme/bloom_tokens.dart`
- Test: `test/core/theme/bloom_tokens_test.dart`

**Interfaces:**
- Consumes: `BloomColors` (Task 1)
- Produces:
  - `abstract final class BloomRadii { static const double sm = 10, md = 16, lg = 20, pill = 999; }`
  - `abstract final class BloomSpacing { static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 22, xxl = 32; }`
  - `abstract final class BloomShadows { static List<BoxShadow> warm(bool isDark); static List<BoxShadow> soft(bool isDark); }`
  - `abstract final class BloomGradients { static Gradient pageBackground(BloomColors c); static Gradient progressFill(BloomColors c); static Gradient leafMark(BloomColors c); }`

- [ ] **Step 1: Write the failing test (append to the existing test file)**

```dart
  group('layout tokens', () {
    test('radii match the constrained set', () {
      expect(BloomRadii.sm, 10);
      expect(BloomRadii.md, 16);
      expect(BloomRadii.lg, 20);
      expect(BloomRadii.pill, 999);
    });

    test('pageBackground is a sweep of two radial layers over surface', () {
      final g = BloomGradients.pageBackground(BloomColors.light);
      expect(g, isA<Gradient>());
    });

    test('progressFill runs sage -> accent', () {
      final g = BloomGradients.progressFill(BloomColors.light) as LinearGradient;
      expect(g.colors.first, BloomColors.light.sage);
      expect(g.colors.last, BloomColors.light.accent);
    });

    test('warm shadow is darker in dark mode', () {
      expect(BloomShadows.warm(true).first.color.opacity,
          greaterThan(BloomShadows.warm(false).first.color.opacity));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom_tokens_test.dart`
Expected: FAIL — `BloomRadii` / `BloomGradients` / `BloomShadows` undefined.

- [ ] **Step 3: Write minimal implementation (append to `bloom_tokens.dart`)**

```dart
/// Corner radii used across Bloom. Only these four values are allowed.
abstract final class BloomRadii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}

/// Spacing scale derived from bloom.css padding values.
abstract final class BloomSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double xxl = 32;
}

/// Warm, soft shadows — used sparingly (Bloom leans on borders, not elevation).
abstract final class BloomShadows {
  static List<BoxShadow> warm(bool isDark) => [
        BoxShadow(
          color: isDark
              ? const Color(0x8C000000)
              : const Color(0x59784660), // rgba(120,70,90,.35)
          blurRadius: 56,
          spreadRadius: -30,
          offset: const Offset(0, 24),
        ),
      ];

  static List<BoxShadow> soft(bool isDark) => [
        BoxShadow(
          color: isDark ? const Color(0x73000000) : const Color(0x2E784660),
          blurRadius: 14,
          spreadRadius: -6,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Bloom gradients. Background mirrors `body { background: ... }` in bloom.css.
abstract final class BloomGradients {
  /// Two soft radial washes over the base surface. Flutter can't stack
  /// multiple radial gradients in one `Gradient`, so this approximates the
  /// dominant wash (top-left bgA -> transparent) over `surface2`; screens
  /// paint `surface2` as the scaffold base and layer this on top.
  static Gradient pageBackground(BloomColors c) => RadialGradient(
        center: const Alignment(-0.9, -1.1),
        radius: 1.4,
        colors: [c.bgA, c.bgB.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      );

  static Gradient progressFill(BloomColors c) =>
      LinearGradient(colors: [c.sage, c.accent]);

  static Gradient leafMark(BloomColors c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c.accent, c.sage],
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom_tokens_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom_tokens.dart test/core/theme/bloom_tokens_test.dart
git commit -m "feat(theme): Bloom radii/spacing/shadow/gradient tokens"
```

---

## Task 3: Bundle the Be Vietnam Pro font

**Files:**
- Create: `assets/fonts/BeVietnamPro-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`, `-Bold.ttf`, `-ExtraBold.ttf`
- Modify: `pubspec.yaml`
- Test: `test/core/theme/font_bundled_test.dart`

**Interfaces:**
- Produces: font family string `BeVietnamPro` with weights 400/500/600/700/800 available offline.

- [ ] **Step 1: Download the font files**

Be Vietnam Pro is OFL-licensed, hosted in the `google/fonts` repo. Download these five files into `assets/fonts/` (create the folder):

```bash
mkdir -p assets/fonts
base="https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro"
curl -L -o assets/fonts/BeVietnamPro-Regular.ttf   "$base/BeVietnamPro-Regular.ttf"
curl -L -o assets/fonts/BeVietnamPro-Medium.ttf    "$base/BeVietnamPro-Medium.ttf"
curl -L -o assets/fonts/BeVietnamPro-SemiBold.ttf  "$base/BeVietnamPro-SemiBold.ttf"
curl -L -o assets/fonts/BeVietnamPro-Bold.ttf      "$base/BeVietnamPro-Bold.ttf"
curl -L -o assets/fonts/BeVietnamPro-ExtraBold.ttf "$base/BeVietnamPro-ExtraBold.ttf"
```

Verify each file is a real TTF (not an HTML error page):

Run: `file assets/fonts/*.ttf`
Expected: each line reports `TrueType Font data` (or `OpenType font`). If any says `HTML`, the download failed — get it from https://fonts.google.com/specimen/Be+Vietnam+Pro (Download family) and copy the matching weights in.

- [ ] **Step 2: Register the font in `pubspec.yaml`**

Replace the `flutter:` block at the bottom of `pubspec.yaml` with:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
  fonts:
    - family: BeVietnamPro
      fonts:
        - asset: assets/fonts/BeVietnamPro-Regular.ttf
          weight: 400
        - asset: assets/fonts/BeVietnamPro-Medium.ttf
          weight: 500
        - asset: assets/fonts/BeVietnamPro-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/BeVietnamPro-Bold.ttf
          weight: 700
        - asset: assets/fonts/BeVietnamPro-ExtraBold.ttf
          weight: 800
```

- [ ] **Step 3: Fetch packages**

Run: `flutter pub get`
Expected: `Got dependencies!` with no asset errors.

- [ ] **Step 4: Write the test**

```dart
// test/core/theme/font_bundled_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all five Be Vietnam Pro weights are present and non-trivial', () {
    const files = [
      'BeVietnamPro-Regular.ttf',
      'BeVietnamPro-Medium.ttf',
      'BeVietnamPro-SemiBold.ttf',
      'BeVietnamPro-Bold.ttf',
      'BeVietnamPro-ExtraBold.ttf',
    ];
    for (final f in files) {
      final file = File('assets/fonts/$f');
      expect(file.existsSync(), isTrue, reason: '$f missing');
      expect(file.lengthSync(), greaterThan(20000), reason: '$f too small to be a real font');
    }
  });

  test('pubspec declares the BeVietnamPro family', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: BeVietnamPro'));
    expect(pubspec, contains('weight: 800'));
  });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/theme/font_bundled_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/fonts test/core/theme/font_bundled_test.dart
git commit -m "chore(theme): bundle Be Vietnam Pro font (400-800)"
```

---

## Task 4: Rework AppTheme onto Bloom

**Files:**
- Modify: `lib/core/theme/app_theme.dart`
- Test: `test/core/theme/app_theme_test.dart`

**Interfaces:**
- Consumes: `BloomColors`, `BloomRadii` (Tasks 1-2), `BeVietnamPro` font (Task 3)
- Produces: `AppTheme.light` / `AppTheme.dark` — each a `ThemeData` with `extension<BloomColors>()` non-null, `colorScheme.primary == BloomColors.<mode>.accent`, `textTheme` on the `BeVietnamPro` family.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';

void main() {
  test('light theme carries the Bloom extension and accent as primary', () {
    final t = AppTheme.light;
    final bloom = t.extension<BloomColors>();
    expect(bloom, isNotNull);
    expect(bloom!.accent, BloomColors.light.accent);
    expect(t.colorScheme.primary, BloomColors.light.accent);
    expect(t.colorScheme.error, BloomColors.light.danger);
  });

  test('dark theme carries the dark Bloom extension', () {
    expect(AppTheme.dark.extension<BloomColors>()!.accent, BloomColors.dark.accent);
    expect(AppTheme.dark.brightness, Brightness.dark);
  });

  test('text theme uses Be Vietnam Pro', () {
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'BeVietnamPro');
    expect(AppTheme.light.textTheme.titleLarge?.fontWeight, FontWeight.w800);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: FAIL — extension is null / primary is the old seed color.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/app_theme.dart
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
        .apply(fontFamily: 'BeVietnamPro', bodyColor: c.ink, displayColor: c.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface2,
      fontFamily: 'BeVietnamPro',
      extensions: [c],
      textTheme: baseText.copyWith(
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        overlayColor: c.accent.withOpacity(0.12),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(BloomRadii.lg)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.ink,
        contentTextStyle: TextStyle(color: c.surface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accent.withOpacity(0.24),
        selectionHandleColor: c.accent,
      ),
    );
  }
}
```

- [ ] **Step 4: Run the theme test + the full suite**

Run: `flutter test test/core/theme/app_theme_test.dart`
Expected: PASS (3 tests).

Run: `flutter test`
Expected: all green. If a screen test asserted the old `Color(0xFF5B7FFF)` seed or a specific Material color, update it to the Bloom equivalent — do not change behavior assertions.

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/theme/app_theme.dart test/core/theme/app_theme_test.dart
git commit -m "feat(theme): rework AppTheme onto Bloom tokens + Be Vietnam Pro"
```

---

## Task 5: UserSettingsState — add `themePreference` and `aiAvailable`

**Files:**
- Modify: `lib/features/dictionary/domain/entities/user_settings_state.dart`
- Modify: `lib/features/dictionary/presentation/providers/user_settings_provider.dart`
- Test: `test/features/dictionary/domain/entities/user_settings_state_test.dart` (create if absent), `test/features/dictionary/presentation/providers/user_settings_notifier_test.dart`

**Interfaces:**
- Consumes: nothing new
- Produces:
  - `UserSettingsState.themePreference` → `ThemeMode` (default `ThemeMode.system`), threaded through the constructor, `copyWith`, and `defaults`
  - `bool get aiAvailable` on `UserSettingsState` → `activeConfig.apiKeyCiphertext?.isNotEmpty ?? false`
  - `UserSettingsNotifier.setThemePreference(ThemeMode mode)` — writes SharedPreferences key `theme_preference` (stores `mode.name`) and updates state
  - `aiEnabled` field and `setAiEnabled` are **kept unchanged** in this plan.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dictionary/domain/entities/user_settings_state_test.dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/domain/entities/provider_config.dart';
import 'package:lexi_core/features/dictionary/domain/entities/ai_provider.dart';

void main() {
  test('defaults to system theme preference', () {
    expect(UserSettingsState.defaults.themePreference, ThemeMode.system);
  });

  test('copyWith updates themePreference', () {
    final next = UserSettingsState.defaults.copyWith(themePreference: ThemeMode.dark);
    expect(next.themePreference, ThemeMode.dark);
  });

  test('aiAvailable is false with no key, true once a ciphertext is set', () {
    expect(UserSettingsState.defaults.aiAvailable, isFalse);
    final withKey = UserSettingsState.defaults.copyWith(providerConfigs: {
      AiProvider.gemini:
          const ProviderConfig(apiKeyCiphertext: 'abc', model: 'gemini-2.5-flash'),
    });
    expect(withKey.aiAvailable, isTrue);
  });
}
```

Add to `user_settings_notifier_test.dart` (follow the file's existing `ProviderContainer` + fake `SharedPreferences` setup):

```dart
  test('setThemePreference persists and updates state', () {
    final container = makeContainer(); // existing helper in this test file
    container.read(userSettingsNotifierProvider.notifier)
        .setThemePreference(ThemeMode.dark);
    expect(container.read(userSettingsNotifierProvider).themePreference, ThemeMode.dark);
    expect(fakePrefs.getString('theme_preference'), 'dark');
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dictionary/domain/entities/user_settings_state_test.dart`
Expected: FAIL — `themePreference` / `aiAvailable` not defined.

- [ ] **Step 3: Implement — entity**

In `user_settings_state.dart`: add `import 'package:flutter/material.dart' show ThemeMode;` at the top. Add the field + wire it through:

```dart
  const UserSettingsState({
    required this.targetLanguage,
    required this.activeContext,
    required this.aiEnabled,
    required this.activeProvider,
    required this.providerConfigs,
    this.targetCefrLevel,
    this.themePreference = ThemeMode.system,
    this.reminderEnabled = false,
    this.reminderHour = 20,
    this.reminderMinute = 0,
  });

  // ... existing fields ...
  final ThemeMode themePreference;

  /// AI is usable iff the active provider has a stored key ciphertext —
  /// mirrors how the web app infers "AI enabled". (The explicit `aiEnabled`
  /// toggle is being retired; new call sites should read this instead.)
  bool get aiAvailable => activeConfig.apiKeyCiphertext?.isNotEmpty ?? false;
```

In `copyWith`: add `ThemeMode? themePreference,` param and `themePreference: themePreference ?? this.themePreference,`.

In `defaults`: add `themePreference: ThemeMode.system,`.

- [ ] **Step 4: Implement — notifier**

In `user_settings_provider.dart`, add `import 'package:flutter/material.dart' show ThemeMode;`. In `build()`'s returned `UserSettingsState(...)` add:

```dart
      themePreference: ThemeMode.values.byName(
          prefs.getString('theme_preference') ?? ThemeMode.system.name),
```

Add the setter (next to `setReminderMinute`):

```dart
  void setThemePreference(ThemeMode mode) {
    _prefs.setString('theme_preference', mode.name);
    state = state.copyWith(themePreference: mode);
  }
```

- [ ] **Step 5: Regenerate + test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/features/dictionary/`
Expected: all green.

- [ ] **Step 6: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/dictionary/domain/entities/user_settings_state.dart lib/features/dictionary/presentation/providers/user_settings_provider.dart lib/features/dictionary/presentation/providers/user_settings_provider.g.dart test/features/dictionary/
git commit -m "feat(settings): add themePreference + aiAvailable to UserSettingsState"
```

---

## Task 6: Drive MaterialApp.themeMode from the setting

**Files:**
- Modify: `lib/main.dart`
- Test: `test/main_theme_mode_test.dart`

**Interfaces:**
- Consumes: `UserSettingsNotifier` / `userSettingsNotifierProvider` (Task 5), `AppTheme` (Task 4)
- Produces: `LexiCoreApp` renders `MaterialApp.router` with `themeMode` = the provider's `themePreference`.

- [ ] **Step 1: Write the failing test**

```dart
// test/main_theme_mode_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/main.dart';

void main() {
  testWidgets('MaterialApp.themeMode follows themePreference', (tester) async {
    SharedPreferences.setMockInitialValues({'theme_preference': 'dark'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LexiCoreApp(),
    ));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/main_theme_mode_test.dart`
Expected: FAIL — `themeMode` is null/`system` regardless of the pref.

- [ ] **Step 3: Implement**

In `lib/main.dart`, change `LexiCoreApp` from `StatelessWidget` to a `ConsumerWidget`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ...

class LexiCoreApp extends ConsumerWidget {
  const LexiCoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      userSettingsNotifierProvider.select((s) => s.themePreference),
    );
    return MaterialApp.router(
      title: 'LexiCore',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(builder: (context) => SelectionArea(child: child!)),
        ],
      ),
    );
  }
}
```

Add `import 'features/dictionary/presentation/providers/user_settings_provider.dart';` if not already present (it imports `user_settings_provider` for `sharedPreferencesProvider` already — reuse that import).

- [ ] **Step 4: Run test + suite**

Run: `flutter test test/main_theme_mode_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/main_theme_mode_test.dart
git commit -m "feat(theme): drive MaterialApp.themeMode from themePreference"
```

---

## Task 7: BloomScaffold

**Files:**
- Create: `lib/core/theme/bloom/bloom_scaffold.dart`
- Test: `test/core/theme/bloom/bloom_scaffold_test.dart`

**Interfaces:**
- Consumes: `BloomColors`, `BloomGradients` (`context.bloom`)
- Produces:
  ```dart
  class BloomScaffold extends StatelessWidget {
    const BloomScaffold({
      super.key,
      this.appBar,          // PreferredSizeWidget?
      required this.body,   // Widget
      this.bottomNavigationBar, // Widget?
      this.floatingActionButton, // Widget?
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_scaffold_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_scaffold.dart';

void main() {
  testWidgets('renders body over a gradient ground', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const BloomScaffold(body: Text('hello')),
    ));
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('passes through appBar and bottom nav slots', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: BloomScaffold(
        appBar: AppBar(title: const Text('T')),
        body: const SizedBox(),
        bottomNavigationBar: const Text('nav'),
      ),
    ));
    expect(find.text('T'), findsOneWidget);
    expect(find.text('nav'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_scaffold_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_scaffold.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// The Bloom page frame: a soft radial wash over `surface2`, with the usual
/// scaffold slots. Use instead of `Scaffold` on every screen.
class BloomScaffold extends StatelessWidget {
  const BloomScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Scaffold(
      backgroundColor: c.surface2,
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: BloomGradients.pageBackground(c)),
        child: body,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_scaffold_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_scaffold.dart test/core/theme/bloom/bloom_scaffold_test.dart
git commit -m "feat(bloom): BloomScaffold with gradient ground"
```

---

## Task 8: BloomAppBar + BloomIconButton

**Files:**
- Create: `lib/core/theme/bloom/bloom_app_bar.dart`
- Test: `test/core/theme/bloom/bloom_app_bar_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomAppBar extends StatelessWidget implements PreferredSizeWidget {
    const BloomAppBar({super.key, required this.title, this.leading, this.actions});
    final String title;
    final Widget? leading;         // typically BloomLeafMark or BloomIconButton
    final List<Widget>? actions;   // typically BloomIconButton
    @override Size get preferredSize; // Size.fromHeight(kToolbarHeight)
  }
  class BloomIconButton extends StatelessWidget {
    const BloomIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});
    final IconData icon;
    final VoidCallback? onPressed;
    final String? tooltip;
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_app_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_app_bar.dart';

void main() {
  testWidgets('shows the title and an 800-weight style', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(appBar: BloomAppBar(title: 'Tra từ'), body: SizedBox()),
    ));
    expect(find.text('Tra từ'), findsOneWidget);
    final txt = tester.widget<Text>(find.text('Tra từ'));
    expect(txt.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('BloomIconButton fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomIconButton(icon: Icons.settings, onPressed: () => taps++),
      ),
    ));
    await tester.tap(find.byIcon(Icons.settings));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_app_bar_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_app_bar.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Bloom top bar: transparent over the scaffold gradient, no elevation,
/// 800-weight title.
class BloomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BloomAppBar({super.key, required this.title, this.leading, this.actions});

  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: leading == null ? 20 : 8,
      leading: leading == null
          ? null
          : Padding(padding: const EdgeInsets.only(left: 16), child: leading),
      leadingWidth: leading == null ? null : 44,
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.w800, color: c.ink),
      ),
      actions: actions == null
          ? null
          : [
              ...actions!,
              const SizedBox(width: 12),
            ],
    );
  }
}

/// Round icon button on a `surface2` chip with a `border` outline.
class BloomIconButton extends StatelessWidget {
  const BloomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      color: c.inkSoft,
      style: IconButton.styleFrom(
        backgroundColor: c.surface2,
        side: BorderSide(color: c.border),
        shape: const CircleBorder(),
        minimumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_app_bar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_app_bar.dart test/core/theme/bloom/bloom_app_bar_test.dart
git commit -m "feat(bloom): BloomAppBar + BloomIconButton"
```

---

## Task 9: BloomCard

**Files:**
- Create: `lib/core/theme/bloom/bloom_card.dart`
- Test: `test/core/theme/bloom/bloom_card_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomCard extends StatelessWidget {
    const BloomCard({
      super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.elevated = false,   // opt-in warm shadow
      this.selected = false,   // accent border + surface3 ground
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_card.dart';

void main() {
  testWidgets('default card: surface ground, border outline, md radius',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(child: Text('x'))),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCard), matching: find.byType(Container)).first,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface);
    expect((deco.border as Border).top.color, BloomColors.light.border);
    expect(deco.borderRadius, BorderRadius.circular(BloomRadii.md));
  });

  testWidgets('selected card uses accent border + surface3', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomCard(selected: true, child: Text('x'))),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCard), matching: find.byType(Container)).first,
    );
    final deco = box.decoration as BoxDecoration;
    expect((deco.border as Border).top.color, BloomColors.light.accent);
    expect(deco.color, BloomColors.light.surface3);
  });

  testWidgets('onTap makes it tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: BloomCard(onTap: () => taps++, child: const Text('x'))),
    ));
    await tester.tap(find.text('x'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_card_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_card.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Bloom surface card: a `surface` ground, a 1px `border` outline, `md`
/// radius, and no shadow by default. Opt into a warm shadow with [elevated];
/// mark the focal card in a group with [selected].
class BloomCard extends StatelessWidget {
  const BloomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.elevated = false,
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool elevated;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected ? c.surface3 : c.surface,
        border: Border.all(color: selected ? c.accent : c.border),
        borderRadius: BorderRadius.circular(BloomRadii.md),
        boxShadow: elevated ? BloomShadows.warm(isDark) : null,
      ),
      child: child,
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.md),
      child: container,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_card.dart test/core/theme/bloom/bloom_card_test.dart
git commit -m "feat(bloom): BloomCard"
```

---

## Task 10: BloomPillButton

**Files:**
- Create: `lib/core/theme/bloom/bloom_pill_button.dart`
- Test: `test/core/theme/bloom/bloom_pill_button_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum BloomButtonVariant { primary, secondary, sage, danger, link }
  class BloomPillButton extends StatelessWidget {
    const BloomPillButton({
      super.key,
      required this.label,
      required this.onPressed,   // null = disabled
      this.variant = BloomButtonVariant.primary,
      this.block = false,
      this.icon,                 // IconData?
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_pill_button_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_pill_button.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('primary: accent fill, pill shape, fires onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      BloomPillButton(label: 'Lưu từ', onPressed: () => taps++),
    ));
    await tester.tap(find.text('Lưu từ'));
    expect(taps, 1);
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(BloomPillButton), matching: find.byType(Material)).last,
    );
    expect(material.color, BloomColors.light.accent);
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('null onPressed disables it', (tester) async {
    await tester.pumpWidget(_host(
      const BloomPillButton(label: 'X', onPressed: null),
    ));
    expect(tester.widget<TextButton>(find.byType(TextButton)).enabled, isFalse);
  });

  testWidgets('danger variant tints text/border with danger', (tester) async {
    await tester.pumpWidget(_host(
      BloomPillButton(
        label: 'Xoá', onPressed: () {}, variant: BloomButtonVariant.danger),
    ));
    final txt = tester.widget<Text>(find.text('Xoá'));
    expect(txt.style?.color, BloomColors.light.danger);
  });
}
```

> Note: if `AbstractButton` isn't importable in your Flutter version, assert on `tester.widget<TextButton>(...).enabled` for whichever `ButtonStyleButton` subtype the implementation uses.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_pill_button_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_pill_button.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

enum BloomButtonVariant { primary, secondary, sage, danger, link }

/// Bloom's one button. Pill-shaped, 700 weight. Pass `onPressed: null` to
/// disable (renders at 50% opacity).
class BloomPillButton extends StatelessWidget {
  const BloomPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BloomButtonVariant.primary,
    this.block = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final BloomButtonVariant variant;
  final bool block;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;

    late final Color bg;
    late final Color fg;
    late final BorderSide side;
    switch (variant) {
      case BloomButtonVariant.primary:
        bg = c.accent;
        fg = c.accentInk;
        side = BorderSide.none;
      case BloomButtonVariant.secondary:
        bg = c.surface;
        fg = c.ink;
        side = BorderSide(color: c.border);
      case BloomButtonVariant.sage:
        bg = c.sageBg;
        fg = c.sage;
        side = BorderSide(color: c.sage);
      case BloomButtonVariant.danger:
        bg = c.dangerBg;
        fg = c.danger;
        side = BorderSide(color: c.danger);
      case BloomButtonVariant.link:
        bg = Colors.transparent;
        fg = c.accent;
        side = BorderSide.none;
    }

    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
          );

    final button = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withOpacity(0.5),
        disabledForegroundColor: fg.withOpacity(0.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        padding: EdgeInsets.symmetric(
            horizontal: variant == BloomButtonVariant.link ? 4 : 20,
            vertical: block ? 14 : 10),
        shape: StadiumBorder(side: side),
      ),
      child: child,
    );

    return block ? SizedBox(width: double.infinity, child: button) : button;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_pill_button_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_pill_button.dart test/core/theme/bloom/bloom_pill_button_test.dart
git commit -m "feat(bloom): BloomPillButton with 5 variants"
```

---

## Task 11: BloomChip + BloomCefrPill

**Files:**
- Create: `lib/core/theme/bloom/bloom_chip.dart`
- Test: `test/core/theme/bloom/bloom_chip_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum BloomChipStyle { neutral, active, topic, clear }
  class BloomChip extends StatelessWidget {
    const BloomChip({super.key, required this.label, this.onTap, this.style = BloomChipStyle.neutral, this.trailing});
    final String label; final VoidCallback? onTap; final BloomChipStyle style; final Widget? trailing;
  }
  class BloomCefrPill extends StatelessWidget {
    const BloomCefrPill(this.level, {super.key});  // e.g. "B2"
    final String level;
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_chip.dart';

Widget _host(Widget c) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: c));

void main() {
  testWidgets('active chip fills with accent', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'General', style: BloomChipStyle.active),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomChip), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.accent);
  });

  testWidgets('topic chip uses sageBg', (tester) async {
    await tester.pumpWidget(_host(
      const BloomChip(label: 'Business', style: BloomChipStyle.topic),
    ));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomChip), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sageBg);
  });

  testWidgets('BloomCefrPill shows the level on a sage ground', (tester) async {
    await tester.pumpWidget(_host(const BloomCefrPill('B2')));
    expect(find.text('B2'), findsOneWidget);
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(BloomCefrPill), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, BloomColors.light.sage);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_chip_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_chip.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

enum BloomChipStyle { neutral, active, topic, clear }

/// Pill chip. `neutral` = `surface2` + border; `active` = accent fill;
/// `topic` = sage-tinted; `clear` = danger-tinted (for a "remove filters"
/// action).
class BloomChip extends StatelessWidget {
  const BloomChip({
    super.key,
    required this.label,
    this.onTap,
    this.style = BloomChipStyle.neutral,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final BloomChipStyle style;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    late final Color bg;
    late final Color fg;
    late final Color border;
    switch (style) {
      case BloomChipStyle.neutral:
        bg = c.surface2;
        fg = c.inkSoft;
        border = c.border;
      case BloomChipStyle.active:
        bg = c.accent;
        fg = c.accentInk;
        border = c.accent;
      case BloomChipStyle.topic:
        bg = c.sageBg;
        fg = c.sage;
        border = c.sageBg;
      case BloomChipStyle.clear:
        bg = c.dangerBg;
        fg = c.danger;
        border = c.danger;
    }

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(BloomRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.pill),
      child: content,
    );
  }
}

/// A tiny 800-weight CEFR badge on a sage ground.
class BloomCefrPill extends StatelessWidget {
  const BloomCefrPill(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.sage,
        borderRadius: BorderRadius.circular(BloomRadii.pill),
      ),
      child: Text(
        level.toUpperCase(),
        style: TextStyle(
            color: c.accentInk, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_chip_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_chip.dart test/core/theme/bloom/bloom_chip_test.dart
git commit -m "feat(bloom): BloomChip + BloomCefrPill"
```

---

## Task 12: BloomProgressBar

**Files:**
- Create: `lib/core/theme/bloom/bloom_progress_bar.dart`
- Test: `test/core/theme/bloom/bloom_progress_bar_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomProgressBar extends StatelessWidget {
    const BloomProgressBar({super.key, required this.value, this.height = 6}); // value 0.0-1.0
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_progress_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_progress_bar.dart';

void main() {
  testWidgets('clamps value and fills a fraction of the track', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SizedBox(width: 200, child: BloomProgressBar(value: 0.5)),
      ),
    ));
    final fill = tester.getSize(find.byKey(const ValueKey('bloom-progress-fill')));
    final track = tester.getSize(find.byKey(const ValueKey('bloom-progress-track')));
    expect(fill.width, closeTo(track.width * 0.5, 1.0));
  });

  testWidgets('value above 1 is clamped', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: SizedBox(width: 200, child: BloomProgressBar(value: 5)),
      ),
    ));
    final fill = tester.getSize(find.byKey(const ValueKey('bloom-progress-fill')));
    final track = tester.getSize(find.byKey(const ValueKey('bloom-progress-track')));
    expect(fill.width, closeTo(track.width, 1.0));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_progress_bar_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_progress_bar.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// A thin rounded track with a sage->accent gradient fill.
class BloomProgressBar extends StatelessWidget {
  const BloomProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(BloomRadii.pill),
      child: Container(
        key: const ValueKey('bloom-progress-track'),
        height: height,
        color: c.surface3,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: DecoratedBox(
              key: const ValueKey('bloom-progress-fill'),
              decoration: BoxDecoration(gradient: BloomGradients.progressFill(c)),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_progress_bar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_progress_bar.dart test/core/theme/bloom/bloom_progress_bar_test.dart
git commit -m "feat(bloom): BloomProgressBar"
```

---

## Task 13: BloomSectionHeader + BloomLeafMark

**Files:**
- Create: `lib/core/theme/bloom/bloom_labels.dart`
- Test: `test/core/theme/bloom/bloom_labels_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomSectionHeader extends StatelessWidget {
    const BloomSectionHeader(this.text, {super.key});
    final String text;
  }
  class BloomLeafMark extends StatelessWidget {
    const BloomLeafMark({super.key, this.size = 22});
    final double size;
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_labels_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_labels.dart';

void main() {
  testWidgets('section header is uppercased, spaced, faint', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomSectionHeader('Tài khoản')),
    ));
    final txt = tester.widget<Text>(find.byType(Text));
    expect(txt.data, 'TÀI KHOẢN');
    expect(txt.style?.letterSpacing, greaterThan(0));
    expect(txt.style?.color, BloomColors.light.inkFaint);
  });

  testWidgets('leaf mark paints a gradient teardrop', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomLeafMark()),
    ));
    final box = tester.widget<Container>(find.byType(Container).first);
    final deco = box.decoration as BoxDecoration;
    expect(deco.gradient, isNotNull);
    expect(deco.borderRadius, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_labels_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_labels.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// Small uppercase group label, letter-spaced, `inkFaint`.
class BloomSectionHeader extends StatelessWidget {
  const BloomSectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: c.inkFaint,
        ),
      ),
    );
  }
}

/// The LexiCore "leaf" — a teardrop with an accent->sage gradient.
class BloomLeafMark extends StatelessWidget {
  const BloomLeafMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: BloomGradients.leafMark(context.bloom),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(999),
          topRight: Radius.circular(999),
          bottomLeft: Radius.circular(999),
          bottomRight: Radius.circular(4),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_labels_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_labels.dart test/core/theme/bloom/bloom_labels_test.dart
git commit -m "feat(bloom): BloomSectionHeader + BloomLeafMark"
```

---

## Task 14: BloomTextField

**Files:**
- Create: `lib/core/theme/bloom/bloom_text_field.dart`
- Test: `test/core/theme/bloom/bloom_text_field_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomTextField extends StatelessWidget {
    const BloomTextField({
      super.key,
      this.controller,
      this.hintText,
      this.onChanged,
      this.onSubmitted,
      this.obscureText = false,
      this.maxLines = 1,          // >1 or null => rounded (sm) instead of pill
      this.enabled = true,
      this.autofocus = false,
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_text_field_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_text_field.dart';

void main() {
  testWidgets('accepts input and reports changes', (tester) async {
    String? last;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomTextField(hintText: 'Tra từ', onChanged: (v) => last = v),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'resilient');
    expect(last, 'resilient');
    expect(find.text('Tra từ'), findsNothing); // hint hidden once typed
  });

  testWidgets('single-line uses a pill border', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: BloomTextField(hintText: 'x')),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    final border = field.decoration!.enabledBorder as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(999));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_text_field_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_text_field.dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_text_field_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_text_field.dart test/core/theme/bloom/bloom_text_field_test.dart
git commit -m "feat(bloom): BloomTextField"
```

---

## Task 15: BloomListRow

**Files:**
- Create: `lib/core/theme/bloom/bloom_list_row.dart`
- Test: `test/core/theme/bloom/bloom_list_row_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomListRow extends StatelessWidget {
    const BloomListRow({
      super.key,
      required this.cefr,     // String, e.g. "B2" — shown in the round dot
      required this.headword, // String
      required this.meaning,  // String
      this.trailingText,      // String? — e.g. "2 ngày"
      this.onTap,
    });
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_list_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom/bloom_list_row.dart';

void main() {
  testWidgets('shows dot, headword, meaning, trailing; taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: BloomListRow(
          cefr: 'B2',
          headword: 'resilient',
          meaning: 'kiên cường',
          trailingText: '2 ngày',
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('resilient'), findsOneWidget);
    expect(find.text('kiên cường'), findsOneWidget);
    expect(find.text('2 ngày'), findsOneWidget);
    await tester.tap(find.text('resilient'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_list_row_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_list_row.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

/// One row in a vocab-style list: a round sage CEFR dot, headword + meaning,
/// and an optional muted trailing string (e.g. a due date).
class BloomListRow extends StatelessWidget {
  const BloomListRow({
    super.key,
    required this.cefr,
    required this.headword,
    required this.meaning,
    this.trailingText,
    this.onTap,
  });

  final String cefr;
  final String headword;
  final String meaning;
  final String? trailingText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.sageBg, shape: BoxShape.circle),
              child: Text(cefr.toUpperCase(),
                  style: TextStyle(
                      color: c.sage, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                        text: headword,
                        style: TextStyle(
                            color: c.ink, fontWeight: FontWeight.w700)),
                    const TextSpan(text: '  '),
                    TextSpan(text: meaning, style: TextStyle(color: c.inkSoft)),
                  ],
                ),
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(trailingText!,
                  style: TextStyle(color: c.inkFaint, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_list_row_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_list_row.dart test/core/theme/bloom/bloom_list_row_test.dart
git commit -m "feat(bloom): BloomListRow"
```

---

## Task 16: Restyle FilterTile onto Bloom

**Files:**
- Modify: `lib/core/widgets/filter_tile.dart`
- Test: `test/core/widgets/filter_tile_test.dart` (create if absent)

**Interfaces:**
- Consumes: `context.bloom`
- Produces: `FilterTile` — **same constructor** (`icon`, `label`, `value`, `onTap`), Bloom look (pill, `surface2`, value in accent, chevron).

- [ ] **Step 1: Write / update the test**

```dart
// test/core/widgets/filter_tile_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/widgets/filter_tile.dart';

void main() {
  testWidgets('shows label + value, taps, pill-shaped surface2 ground',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: FilterTile(
          icon: Icons.tune,
          label: 'Ngữ cảnh',
          value: '🌐 General',
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('Ngữ cảnh'), findsOneWidget);
    expect(find.text('🌐 General'), findsOneWidget);
    await tester.tap(find.text('Ngữ cảnh'));
    expect(taps, 1);
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(FilterTile), matching: find.byType(Container)).first,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.color, BloomColors.light.surface2);
    expect(deco.borderRadius, BorderRadius.circular(999));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/filter_tile_test.dart`
Expected: FAIL — old `Material`/`surfaceContainerHigh`, radius 12.

- [ ] **Step 3: Rewrite `filter_tile.dart`**

```dart
// lib/core/widgets/filter_tile.dart
import 'package:flutter/material.dart';
import '../theme/bloom_tokens.dart';

/// A compact pill row: label + current value, opens a picker on tap.
class FilterTile extends StatelessWidget {
  const FilterTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(BloomRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.surface2,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(BloomRadii.pill),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: c.inkFaint),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: c.inkSoft, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.ink)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: c.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test + suite**

Run: `flutter test test/core/widgets/filter_tile_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: all green (this widget is used across many screens — any test that asserted its old Material/radius must be updated, behavior assertions untouched).

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/filter_tile.dart test/core/widgets/filter_tile_test.dart
git commit -m "feat(bloom): restyle FilterTile as a Bloom pill row"
```

---

## Task 17: Restyle selection sheets onto Bloom

**Files:**
- Modify: `lib/core/widgets/selection_sheets.dart`
- Test: `test/core/widgets/selection_sheets_test.dart` (create if absent)

**Interfaces:**
- Consumes: `context.bloom`, `BloomPillButton` (Task 10), `BloomChip` (Task 11)
- Produces: `showSingleSelectSheet` / `showMultiSelectSheet` / `SelectOption` — **signatures unchanged**; Bloom look (accent radio/check, `BloomPillButton` confirm, `surface` ground, `lg` top radius).

- [ ] **Step 1: Write the test**

```dart
// test/core/widgets/selection_sheets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/widgets/selection_sheets.dart';

void main() {
  testWidgets('single-select returns the picked option', (tester) async {
    SelectOption<String>? picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              picked = await showSingleSelectSheet<String>(
                context: context,
                title: 'Ngữ cảnh',
                options: const [
                  SelectOption(value: 'a', label: 'General'),
                  SelectOption(value: 'b', label: 'Business'),
                ],
                selected: 'a',
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business'));
    await tester.pumpAndSettle();
    expect(picked?.value, 'b');
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `flutter test test/core/widgets/selection_sheets_test.dart`
Expected: This behavior test likely PASSES already (behavior unchanged). Its job is to guard behavior while you restyle. If it passes, proceed to step 3 anyway.

- [ ] **Step 3: Restyle the internals**

In `selection_sheets.dart`:
- `showSingleSelectSheet`'s inline builder: wrap the title row with `Padding` unchanged; replace each `RadioListTile` with one whose `activeColor: context.bloom.accent` (add `import '../theme/bloom_tokens.dart';`). Keep the `Navigator.pop(ctx, o)` behavior.
- `_MultiSelectSheetState.build`: replace the trailing `FilledButton` with `BloomPillButton(label: <same text>, block: true, onPressed: () => Navigator.pop(context, _selected))` (add `import '../theme/bloom/bloom_pill_button.dart';`). Replace `CheckboxListTile`'s implicit color with `activeColor: context.bloom.accent`. Replace the "Bỏ chọn hết" `TextButton` with `BloomPillButton(variant: BloomButtonVariant.link, ...)`.
- No structural/return-type changes.

- [ ] **Step 4: Run test + suite**

Run: `flutter test test/core/widgets/selection_sheets_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: all green.

- [ ] **Step 5: Commit**

```bash
git add lib/core/widgets/selection_sheets.dart test/core/widgets/selection_sheets_test.dart
git commit -m "feat(bloom): restyle selection sheets (accent controls, pill confirm)"
```

---

## Task 18: BloomBottomNav + BloomNavRail

**Files:**
- Create: `lib/core/theme/bloom/bloom_bottom_nav.dart`
- Test: `test/core/theme/bloom/bloom_bottom_nav_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class BloomNavItem {
    const BloomNavItem({required this.icon, required this.label});
    final IconData icon; final String label;
  }
  class BloomBottomNav extends StatelessWidget {
    const BloomBottomNav({super.key, required this.items, required this.selectedIndex, required this.onSelected});
  }
  class BloomNavRail extends StatelessWidget {
    const BloomNavRail({super.key, required this.items, required this.selectedIndex, required this.onSelected, this.extended = false});
  }
  ```

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/bloom/bloom_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/app_theme.dart';
import 'package:lexi_core/core/theme/bloom_tokens.dart';
import 'package:lexi_core/core/theme/bloom/bloom_bottom_nav.dart';

const _items = [
  BloomNavItem(icon: Icons.search, label: 'Tra từ'),
  BloomNavItem(icon: Icons.book, label: 'Từ vựng'),
  BloomNavItem(icon: Icons.school, label: 'Luyện tập'),
  BloomNavItem(icon: Icons.settings, label: 'Cài đặt'),
];

void main() {
  testWidgets('bottom nav renders all labels, taps report index', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: BloomBottomNav(
          items: _items, selectedIndex: 0, onSelected: (i) => tapped = i),
      ),
    ));
    for (final it in _items) {
      expect(find.text(it.label), findsOneWidget);
    }
    await tester.tap(find.text('Luyện tập'));
    expect(tapped, 2);
  });

  testWidgets('selected item colors its label with accent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        bottomNavigationBar: BloomBottomNav(
          items: _items, selectedIndex: 1, onSelected: (_) {}),
      ),
    ));
    final label = tester.widget<Text>(find.text('Từ vựng'));
    expect(label.style?.color, BloomColors.light.accent);
  });

  testWidgets('rail renders and taps', (tester) async {
    int? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Row(children: [
          BloomNavRail(items: _items, selectedIndex: 0, onSelected: (i) => tapped = i),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
    await tester.tap(find.byIcon(Icons.settings));
    expect(tapped, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_bottom_nav_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Write the implementation**

```dart
// lib/core/theme/bloom/bloom_bottom_nav.dart
import 'package:flutter/material.dart';
import '../bloom_tokens.dart';

class BloomNavItem {
  const BloomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Bottom navigation, Bloom-styled: `surface2` bar with a top border; the
/// selected item's icon sits on a `surface3` "pill" and its label is accent.
class BloomBottomNav extends StatelessWidget {
  const BloomBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<BloomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavCell(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({required this.item, required this.selected, required this.onTap});
  final BloomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    final color = selected ? c.accent : c.inkFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BloomRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? c.surface3 : Colors.transparent,
                borderRadius: BorderRadius.circular(BloomRadii.pill),
              ),
              child: Icon(item.icon, size: 20, color: color),
            ),
            const SizedBox(height: 3),
            Text(item.label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Wide-screen rail. A restyled `NavigationRail` — NOT a web-style labelled
/// sidebar. Same item set as [BloomBottomNav].
class BloomNavRail extends StatelessWidget {
  const BloomNavRail({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.extended = false,
  });

  final List<BloomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final c = context.bloom;
    return NavigationRail(
      extended: extended,
      backgroundColor: c.surface2,
      selectedIndex: selectedIndex,
      indicatorColor: c.surface3,
      onDestinationSelected: onSelected,
      selectedIconTheme: IconThemeData(color: c.accent),
      unselectedIconTheme: IconThemeData(color: c.inkFaint),
      selectedLabelTextStyle:
          TextStyle(color: c.accent, fontWeight: FontWeight.w700),
      unselectedLabelTextStyle: TextStyle(color: c.inkFaint),
      destinations: [
        for (final it in items)
          NavigationRailDestination(
            icon: Icon(it.icon),
            label: Text(it.label),
          ),
      ],
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_bottom_nav_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom_bottom_nav.dart test/core/theme/bloom/bloom_bottom_nav_test.dart
git commit -m "feat(bloom): BloomBottomNav + BloomNavRail"
```

---

## Task 19: Barrel export

**Files:**
- Create: `lib/core/theme/bloom/bloom.dart`
- Test: none (pure re-export; covered by the widget tests already importing individual files — add one import-smoke test)

- [ ] **Step 1: Write the smoke test**

```dart
// test/core/theme/bloom/bloom_barrel_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/core/theme/bloom/bloom.dart';

void main() {
  test('barrel exposes the core Bloom symbols', () {
    expect(BloomButtonVariant.values.length, 5);
    expect(BloomChipStyle.values.length, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/bloom/bloom_barrel_test.dart`
Expected: FAIL — `bloom.dart` not found.

- [ ] **Step 3: Write the barrel**

```dart
// lib/core/theme/bloom/bloom.dart
export '../bloom_tokens.dart';
export 'bloom_app_bar.dart';
export 'bloom_bottom_nav.dart';
export 'bloom_card.dart';
export 'bloom_chip.dart';
export 'bloom_labels.dart';
export 'bloom_list_row.dart';
export 'bloom_pill_button.dart';
export 'bloom_progress_bar.dart';
export 'bloom_scaffold.dart';
export 'bloom_text_field.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/bloom/bloom_barrel_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/bloom/bloom.dart test/core/theme/bloom/bloom_barrel_test.dart
git commit -m "chore(bloom): barrel export for lib/core/theme/bloom"
```

---

## Task 20: Restyle the app shell

**Files:**
- Modify: `lib/core/widgets/app_shell.dart`
- Test: `test/core/widgets/app_shell_test.dart`

**Interfaces:**
- Consumes: `BloomScaffold`, `BloomBottomNav`, `BloomNavRail`, `BloomNavItem` (Tasks 7, 18)
- Produces: `AppShell` — same constructor (`{required Widget child}`), same 4 destinations/paths/order, same `go_router` navigation behavior. Only the chrome changes.

- [ ] **Step 1: Update the shell test**

Open `test/core/widgets/app_shell_test.dart`. Keep every navigation assertion. Replace finders that target `NavigationBar` / `NavigationDestination` / `NavigationRail` with the Bloom equivalents:
- `find.byType(NavigationBar)` → `find.byType(BloomBottomNav)`
- tapping a destination: `await tester.tap(find.text('Luyện tập'))` (labels unchanged)
- wide-layout test: `find.byType(NavigationRail)` → `find.byType(BloomNavRail)` (note: `BloomNavRail` itself renders a `NavigationRail` internally, so `find.byType(NavigationRail)` still also works if the test prefers it).

Add one assertion:

```dart
  testWidgets('shell uses the Bloom scaffold', (tester) async {
    // ... existing pump for the narrow layout ...
    expect(find.byType(BloomScaffold), findsOneWidget);
    expect(find.byType(BloomBottomNav), findsOneWidget);
  });
```

Add the import: `import 'package:lexi_core/core/theme/bloom/bloom.dart';`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/app_shell_test.dart`
Expected: FAIL — `BloomScaffold`/`BloomBottomNav` not found in tree.

- [ ] **Step 3: Rewrite `app_shell.dart`'s `build`**

Keep `_Dest`, `_destinations`, `_selectedIndex`, `_navigateTo`, the lifecycle observer, and the `notificationNotifierProvider` reschedule logic **exactly as they are**. Replace only the `LayoutBuilder` return:

```dart
  static const _navItems = [
    BloomNavItem(icon: Icons.search, label: 'Tra từ'),
    BloomNavItem(icon: Icons.library_books, label: 'Từ vựng'),
    BloomNavItem(icon: Icons.school, label: 'Luyện tập'),
    BloomNavItem(icon: Icons.settings, label: 'Cài đặt'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dests = _destinations;
        final selectedIndex = _selectedIndex(context, dests);

        if (constraints.maxWidth >= 600) {
          return BloomScaffold(
            body: Row(
              children: [
                BloomNavRail(
                  items: _navItems,
                  selectedIndex: selectedIndex,
                  onSelected: (i) => _navigateTo(context, i, dests),
                  extended: constraints.maxWidth >= 1200,
                ),
                VerticalDivider(width: 1, thickness: 1, color: context.bloom.border),
                Expanded(child: widget.child),
              ],
            ),
          );
        }
        return BloomScaffold(
          body: widget.child,
          bottomNavigationBar: BloomBottomNav(
            items: _navItems,
            selectedIndex: selectedIndex,
            onSelected: (i) => _navigateTo(context, i, dests),
          ),
        );
      },
    );
  }
```

Update imports: add `import '../theme/bloom/bloom.dart';`. The `_Dest` list keeps its `icon`/`selectedIcon`/`label`/`path` fields (still used by `_selectedIndex`); `_navItems` is the parallel display list. Keep both in the same order.

> Note: `BloomScaffold` currently has no `drawer`/`endDrawer` slot — the shell doesn't use one, so no change needed. If a later plan needs it, add the slot then.

- [ ] **Step 4: Run test + full suite**

Run: `flutter test test/core/widgets/app_shell_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: all green.

- [ ] **Step 5: `flutter analyze`**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Manual smoke check**

Run: `flutter run -d chrome`
Verify: gradient background, Bloom bottom nav with the accent pill on the active tab, Be Vietnam Pro type, all 4 tabs navigate. Then toggle OS dark mode (or set it via devtools) and confirm the dark palette applies.

- [ ] **Step 7: Commit**

```bash
git add lib/core/widgets/app_shell.dart test/core/widgets/app_shell_test.dart
git commit -m "feat(bloom): restyle app shell (BloomScaffold + BloomBottomNav/Rail)"
```

---

## Task 21: Document the theme system

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a `## Theme` section**

Insert after the `## Monorepo structure` section (before `## Backend/data decisions`):

```markdown
## Theme (Flutter)

Flutter UI uses the **Bloom** design system, ported from `apps/web/src/styles/bloom.css`:

- **Tokens:** `lib/core/theme/bloom_tokens.dart` — `BloomColors` (a `ThemeExtension`, light + dark), `BloomRadii` (sm/md/lg/pill only), `BloomSpacing`, `BloomShadows`, `BloomGradients`. Read colors via `context.bloom`.
- **Widgets:** `lib/core/theme/bloom/` — `BloomScaffold`, `BloomAppBar`, `BloomCard`, `BloomPillButton`, `BloomChip`, `BloomBottomNav`, etc. Import the barrel `lib/core/theme/bloom/bloom.dart`. Prefer these over raw Material widgets on feature screens.
- **`AppTheme`** (`lib/core/theme/app_theme.dart`) keeps a Material `ThemeData` for low-level widgets (`Slider`, dialogs, `TextField` internals) but maps its `ColorScheme` onto Bloom tokens and attaches the `BloomColors` extension.
- Color values in `bloom_tokens.dart` are copied verbatim from `bloom.css`. If you change a Bloom color, change it in **both** files.
- Font: **Be Vietnam Pro**, bundled under `assets/fonts/` (family `BeVietnamPro`).
- Light/dark follows `UserSettingsState.themePreference` (Sáng/Tối/Hệ thống), stored locally in SharedPreferences (`theme_preference`), not synced.
```

- [ ] **Step 2: Verify the surrounding doc still reads correctly**

Run: `git diff CLAUDE.md`
Confirm the new section is well-placed and doesn't duplicate the existing `core/theme/` line in the architecture tree.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document the Bloom theme system for Flutter"
```

---

## Self-Review

**1. Spec coverage (against `2026-08-30-flutter-bloom-redesign-design.md`):**
- Phần A1 (tokens) → Tasks 1-2 ✓
- Phần A2 (font) → Task 3 ✓
- Phần A3 (widget library) → Tasks 7-19 build the **core** subset (Scaffold, AppBar, IconButton, Card, PillButton, Chip, CefrPill, ProgressBar, SectionHeader, LeafMark, TextField, ListRow, BottomNav, NavRail) + FilterTile/selection-sheet restyle. Feature-specific widgets (PassageSheet, ExpansionTile, BarChart, StatCard, AudioControls, WordSeekBar, Segmented, Switch, McOption, AiKeyMissingCard, BloomBottomSheet helper) are explicitly deferred to their feature plans — noted in "Not in this plan". ✓ (partial by design)
- Phần A4 (`AppTheme` slim) → Task 4 ✓
- Phần D (theme setting) → Tasks 5-6 ✓
- Phần B1 (shell) → Task 20 ✓
- Phần C2 state groundwork (`aiAvailable` getter, keep `aiEnabled`) → Task 5 ✓
- Phần E: only `CLAUDE.md` here (Task 21); `README.md` updates land in the plan that completes the user-facing behavior changes (Plan 6). ✓
- C1 (`activeContext` removal): correctly **not** in this plan → Plan 2.

**2. Placeholder scan:** No "TBD"/"handle edge cases"/"similar to Task N". Each code step shows full code. ✓

**3. Type consistency:**
- `context.bloom` returns `BloomColors` — used consistently Tasks 7-20.
- `BloomButtonVariant` (Task 10) referenced in Task 17 — matches.
- `BloomChipStyle` (Task 11) — used in Task 19 barrel test.
- `BloomNavItem` (Task 18) — consumed in Task 20 as `_navItems`.
- `UserSettingsState.themePreference : ThemeMode` (Task 5) — consumed in Task 6 `main.dart` and Task 6 test.
- `BloomProgressBar({required double value, double height})` (Task 12) — no other task consumes it yet.

No mismatches found.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-30-flutter-bloom-plan1-foundation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
