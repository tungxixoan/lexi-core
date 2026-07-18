# LexiCore — Mobile Tab Visibility `kIsWeb` Bug Fix

**Date:** 2026-07-19
**Status:** Implemented
**Covers:** A visibility bug affecting both the Reading tab (`AppShell`) and its Settings toggle (`SettingsScreen`), found while designing [Luyện nghe (Listening Practice)](2026-07-19-listening-practice-design.md) §5.1–5.2, which reuses the same tab-visibility mechanism from the start.

---

## 1. Symptom

User reported, while testing the Reading tab in Chrome DevTools' mobile-device emulation (iPhone XR viewport):
- The "Đọc" (Reading) tab kept showing in the bottom nav regardless of the "Hiện tab Luyện đọc & gõ trên điện thoại" Settings toggle.
- Once the `AppShell` half of this was fixed, a follow-up look showed the toggle itself was missing from the Settings screen entirely at that viewport width.

## 2. Root cause

Both `AppShell._AppShellState.build()` and `SettingsScreen.build()` used `kIsWeb` as a stand-in for "is this a phone." `kIsWeb` is `true` for *any* browser context — a 1920px desktop Chrome window, a 375px Chrome DevTools device-emulation window, and a real phone's mobile browser are all `kIsWeb == true`. Concretely:

- `AppShell`: `final showReading = kIsWeb || settings.showReadingPracticeOnMobile;` → always `true` on any web build, at any width, making the toggle inert.
- `SettingsScreen`: `if (!kIsWeb) SwitchListTile(...)` → the toggle itself never renders on any web build, at any width.

This was the original Plan 6 design, not a regression — [2026-07-06-plan6-web-platform-bilingual-reading-design.md](2026-07-06-plan6-web-platform-bilingual-reading-design.md) §2.2 explicitly specified `kIsWeb` as the mechanism. The gap is a latent assumption baked into that design: "web" and "desktop-sized" were treated as the same thing, which holds for a Flutter Web app opened on a desktop but not for one opened in a phone's browser or a narrow window.

## 3. Fix

Replaced `kIsWeb` with the screen-width breakpoint (`>= 600dp`) already used elsewhere in `AppShell` to choose `NavigationRail` vs. `NavigationBar`:

- `AppShell` (`lib/core/widgets/app_shell.dart`): moved the `showReading` computation inside the existing `LayoutBuilder`, keyed to `constraints.maxWidth >= 600` instead of `kIsWeb`.
- `SettingsScreen` (`lib/features/settings/presentation/screens/settings_screen.dart`): the toggle's guard changed from `if (!kIsWeb)` to `if (MediaQuery.sizeOf(context).width < 600)`.

Both now treat "mobile" as "narrow viewport" — platform-agnostic, and correct for phone browsers and narrow desktop/DevTools windows alike, not just native (non-web) builds.

## 4. Regression tests

Added to `test/core/widgets/app_shell_test.dart`:
- narrow width (400dp) + toggle off → Reading tab absent
- narrow width (400dp) + toggle on → Reading tab present
- wide width (800dp) + toggle off → Reading tab present (previously untestable in-VM at all, since `kIsWeb` is always `false` under `flutter test` — the old code's "should show on web" branch was never exercised by any test)

`SettingsScreen` has no existing test scaffolding in this codebase (it would need Firebase Auth/sync provider mocks that aren't set up anywhere in the suite yet) — verified via `flutter analyze` (clean, no errors) and manual code reading only. No automated regression test was added for that file.

## 5. Related specs

- [Plan 6 & 7 — Web Platform + Bilingual Reading](2026-07-06-plan6-web-platform-bilingual-reading-design.md) — original source of the `kIsWeb` mechanism this fixes.
- [Listening Practice design](2026-07-19-listening-practice-design.md) §5.1–5.2 — the new "Luyện nghe" tab adopts the corrected width-based logic from the start rather than repeating the bug.

## 6. Explicitly not done

- No change to the 600dp breakpoint value itself.
- No automated regression test for `SettingsScreen` (no test infra exists for that screen yet).
