# Chuyển UI Flutter sang ngôn ngữ thiết kế Bloom — Design

## Context

App Flutter (`lib/`) hiện dùng Material 3 mặc định: `AppTheme` chỉ có `ColorScheme.fromSeed(seedColor: Color(0xFF5B7FFF))` cho light + dark, không tuỳ biến gì thêm (`lib/core/theme/app_theme.dart`, 23 dòng). Mọi màn hình dùng widget Material thô — `AppBar`, `Scaffold`, `Card`, `FilledButton`, `NavigationRail`/`NavigationBar` (`lib/core/widgets/app_shell.dart`), `RadioListTile`, `SwitchListTile`, `LinearProgressIndicator`.

Bản web React (`apps/web/`) đã có sẵn ngôn ngữ thiết kế **Bloom** hoàn chỉnh trong một file: `apps/web/src/styles/bloom.css` (~1970 dòng). Đặc trưng: nền gradient radial hồng/tím ấm, accent hồng `#C9587A` + xanh sage `#6F9A87`, surface trắng bo tròn lớn (14/16/20px, pill 999px), viền mảnh `#EFDDE3` thay cho shadow kiểu Material, nút pill, dark palette đầy đủ (`@media (prefers-color-scheme: dark)` + `[data-theme]`). Font web là `"Trebuchet MS"`.

**Mục tiêu:** app Flutter mang đúng ngôn ngữ thiết kế Bloom đó, **nhưng giữ layout/điều hướng đúng chất một app mobile** — không bê nguyên sidebar/hai-cột của web. Bottom nav, hub, bottom sheet, app bar giữ nguyên vai trò. Mọi tính năng hiện có (xem `README.md`) giữ đủ.

Đây là dự án cá nhân một người dùng; không có yêu cầu backward-compat về giao diện, không có rollout theo cohort.

## Decisions made during brainstorming

- **Hướng B — design system Bloom riêng**, không chỉ theme lại `ThemeData`. Lý do: look Bloom khá xa Material (pill mọi nơi, không elevation, shape/typography riêng); tuỳ biến `ThemeData` sâu vẫn để lộ "chất Material". Chấp nhận khối lượng việc lớn hơn (đụng ~40+ file màn hình/widget) để đạt độ giống cao.
- **IA giữ nguyên.** Bottom nav 4 mục (`Tra từ / Từ vựng / Luyện tập / Cài đặt`), wide screen dùng rail Bloom (không phải sidebar web đầy nhãn). Reading / Listening / Word Radar / Progress vẫn nằm trong hub "Luyện tập". Không sửa `app_router.dart` về mặt route.
- **Font: Be Vietnam Pro**, bundle offline vào `assets/fonts/` (không phụ thuộc mạng). Việt-first, dấu đẹp, nét thân thiện gần Trebuchet. Weight 400/500/600/700/800.
- **`ThemeData` không biến mất** — vẫn giữ bản rút gọn cho các widget Material còn dùng ở tầng thấp (`Slider`, `showTimePicker`, `TextField` bên trong `BloomTextField`, `AlertDialog`). Nhưng phần lớn UI chuyển sang widget Bloom.
- **Dark mode** theo đúng dark palette của `bloom.css`. Cơ chế: theo `MediaQuery.platformBrightness` + một setting "Chủ đề" (Sáng / Tối / Hệ thống) — **setting này là tính năng MỚI** (Flutter hiện không có), thêm để ngang bằng web (`theme: "light" | "dark" | "system"` trong `apps/web/src/lib/settings.ts`). Lưu local (SharedPreferences), không cần sync đợt này.
- **Đồng bộ 2 điểm với web (đổi hành vi, không chỉ visual):**
  - **C1 — bỏ selector "Ngữ cảnh" khỏi màn Tra từ + bỏ `activeContext` khỏi settings toàn cục.** Web đã bỏ (`apps/web/src/app/(app)/lookup/page.tsx` chỉ dùng `targetLanguage`; `settings.ts` không có field context). AppContext **vẫn giữ** như khái niệm per-session ở Nghe hiểu / Luyện đọc / vocab record.
  - **C2 — bỏ toggle "Bật AI".** Web không có toggle; web suy ra "AI bật" = active provider có `apiKeyCiphertext`. Flutter theo đúng vậy.
- **Reading sessions — cải tiến layout** (không chỉ đổi màu):
  - **Part 6 & Part 7:** đoạn văn đặt trong bottom sheet kéo được; câu hỏi là nội dung chính; chip điều hướng đoạn; Part 7 đoạn đôi → sheet 2 tab văn bản.
  - **Part 5:** không có passage → chỉ là list câu hỏi Bloom, không sheet.
  - **Đọc & gõ:** xác nhận luồng hiện tại đúng — KHÔNG hiện WPM/độ chính xác giữa phiên (chỉ ở màn kết quả), tự chuyển câu khi gõ xong (không có nút "Câu tiếp theo").
- **Demo artifact** (`bloom-flutter-demo.html`, đã duyệt) là nguồn tham chiếu hình ảnh cho 10 màn: Tra từ, Từ vựng, Practice hub, Flashcard, Tiến độ, Cài đặt, Part 6, Đọc & gõ, Nghe hiểu, Part 7.

## Non-goals

- Không đổi route, deep-link, hay cấu trúc `go_router`.
- Không đổi logic domain (SM-2, thuật toán sinh bài AI, sync, dedup, TTS). C1/C2 có sửa **chữ ký** vài use-case/source (bỏ tham số `AppContext`, bỏ cờ `aiEnabled`) nhưng không đổi hành vi bên trong.
- Không đụng bản web.
- Không thêm animation/transition mới ngoài những gì widget Bloom cần (flip flashcard đã có sẵn).
- Không sync `theme` lên Firestore đợt này.
- Không xoá `AppContext` khỏi toàn app (chỉ khỏi màn Tra từ + settings toàn cục).

## Architecture

### Phần A — Nền design system Bloom (thêm mới, chưa đụng màn nào)

#### A1. `lib/core/theme/bloom_tokens.dart` — token + `ThemeExtension`

Port trực tiếp từ `apps/web/src/styles/bloom.css` phần `:root` (light) và dark block:

```dart
@immutable
class BloomColors extends ThemeExtension<BloomColors> {
  final Color bgA, bgB, surface, surface2, surface3;
  final Color ink, inkSoft, inkFaint;
  final Color accent, accentInk, sage, sageBg, amber, amberBg;
  final Color success, successBg, danger, dangerBg, border;
  // + copyWith / lerp bắt buộc của ThemeExtension
  static const light = BloomColors(accent: Color(0xFFC9587A), /* ... */);
  static const dark  = BloomColors(accent: Color(0xFFE693AC), /* ... */);
}
```

Giá trị lấy **nguyên xi** từ `bloom.css` (light dòng 1–21, dark dòng 24–44). Kèm:

- `BloomSpacing` — thang 4/8/12/14/16/22/26/32 (theo các con số padding trong `bloom.css`).
- `BloomRadii` — `sm=10, md=16, lg=20, pill=999`.
- `BloomShadows` — 1 shadow ấm mềm (`0 24px 56px -30px rgba(120,70,90,.35)` light / đậm hơn cho dark) + 1 shadow nhẹ cho sticky bar. Dùng **hạn chế** — Bloom chủ yếu là viền, không phải shadow.
- `BloomGradients.pageBackground` — `RadialGradient` mô phỏng 2 lớp `radial-gradient` + nền `surface-2` trong `body` của `bloom.css` (dòng 77–80).
- `BloomGradients.progressFill` — `LinearGradient([sage, accent])`.
- `BloomGradients.leafMark` — `LinearGradient(135deg, [accent, sage])`.

Extension helper: `extension BloomContext on BuildContext { BloomColors get bloom => Theme.of(this).extension<BloomColors>()!; }`

#### A2. Font Be Vietnam Pro

- Tải 5 file `.ttf` (400/500/600/700/800) vào `assets/fonts/BeVietnamPro-*.ttf`.
- `pubspec.yaml` thêm block `fonts:` với family `BeVietnamPro` + `assets/fonts/` vào `assets:`.
- `AppTheme` đặt `fontFamily: 'BeVietnamPro'` + `textTheme` với các weight tương ứng bậc typography Bloom (tiêu đề 800, nội dung 600, nhãn 700 uppercase letter-spacing).
- Mono (IPA, số): dùng `fontFamilyFallback` hệ thống (`ui-monospace`) — không bundle font mono, khớp `bloom.css` (`ui-monospace, "SF Mono", Menlo`).

#### A3. `lib/core/theme/bloom/` — thư viện widget

Mỗi widget là 1 file, có `///` doc ngắn (mục đích, cách dùng, phụ thuộc token), có widget test riêng. Danh sách:

| Widget | Thay cho | Ghi chú |
| --- | --- | --- |
| `BloomScaffold` | `Scaffold` | Nền `BloomGradients.pageBackground`; slot `appBar` (nhận `BloomAppBar`), `body`, `bottomNav`, `floatingAction`, `sheet` |
| `BloomAppBar` | `AppBar` | Tiêu đề weight 800, không elevation, nền trong suốt trên gradient; slot `leading`/`actions` là `BloomIconButton` |
| `BloomIconButton` | `IconButton` | Tròn 26–34px, nền `surface-2`, viền `border` |
| `BloomCard` | `Card` | `surface`, viền `border` 1px, radius `md`, không shadow mặc định (opt-in `elevated`) |
| `BloomPillButton` | `FilledButton`/`OutlinedButton`/`TextButton` | Biến thể `primary` (nền accent) / `secondary` (viền) / `sage` / `danger` (viền dangerBg) / `link`; `block` = full-width; trạng thái disabled `opacity .5` |
| `BloomChip` | `Chip`/`FilterChip` | `active` = nền accent; `topic` = nền sageBg; `clear` = danger |
| `BloomFilterTile` | `lib/core/widgets/filter_tile.dart` | Hàng pill full-width: icon + nhãn + giá trị + chevron; mở `BloomBottomSheet` |
| `BloomCefrPill` | (text thô) | Nền sage, chữ 800, radius pill — port `.cefr-pill` |
| `BloomProgressBar` | `LinearProgressIndicator` | Track `surface-3`, fill `BloomGradients.progressFill`, radius pill |
| `BloomSectionHeader` | `_SectionHeader` (settings) | Chữ nhỏ uppercase letter-spacing, màu `inkFaint` |
| `BloomLeafMark` | (mới) | Ô 16–22px radius `50% 50% 50% 4px`, gradient leaf — logo góc trên |
| `BloomBottomNav` | `NavigationBar` | 4 mục, item active: chữ accent + "viên thuốc" nền `surface-3` sau icon |
| `BloomNavRail` | `NavigationRail` | Bản Bloom cho wide (≥600) — restyle, KHÔNG thêm nhãn nhóm kiểu web |
| `BloomListRow` | `ListTile` (list từ vựng) | Chấm CEFR tròn sageBg + headword + nghĩa + "due" — port `.vrow` |
| `BloomTextField` | `TextField` (bọc lại) | Nền `surface-2`, radius pill (hoặc `sm` cho multiline), focus viền accent |
| `BloomBottomSheet` | `showModalBottomSheet` | Radius trên `lg`, handle, nền `surface`; helper `showBloomSelectSheet<T>` thay `showSingleSelectSheet` (`lib/core/widgets/selection_sheets.dart`) |
| `BloomExpansionTile` | `ExpansionTile` | Dòng thu gọn hiện tóm tắt (vd "Đã chọn: X" / "chưa trả lời"); mở ra nội dung — dùng cho câu hỏi Part 6 |
| `BloomStatCard` | (mới) | Nhãn nhỏ + số lớn tabular + dòng phụ — port `.dash-stat-card` |
| `BloomBarChart` | (mới) | 7 cột, cột "hôm nay" tô accent — port `.dash-chart` |
| `BloomAudioControls` | (cụm `IconButton` rời trong listening) | Nút tròn ⏮ 🔁 ⏭ + nút Phát lớn accent |
| `BloomWordSeekBar` | `Slider` (seek theo từ) | Track Bloom, thumb accent — bọc `Slider` với `SliderTheme` |
| `BloomSegmented` | `SegmentedButton` | Pill container `surface-2`, segment chọn nền accent — dùng cho picker Chủ đề (Sáng/Tối/Hệ thống) |
| `BloomSwitch` | `Switch` | Track accent khi bật |
| `BloomPassageSheet` | (mới) | `DraggableScrollableSheet` bọc: handle + hint, tab văn bản (0..2), vùng cuộn passage viền trái accent; `initialChildSize` cấu hình theo Part (0.44 Part 6 / 0.6 Part 7) |
| `BloomGroupChips` | (mới) | Hàng `BloomChip` "Đoạn 1/2/3…", 1 active — điều hướng nhóm passage |
| `BloomMcOption` | `RadioListTile` | Ô đáp án bo `sm`, chọn = viền + nền accent; trạng thái `correct`/`wrong` cho màn kết quả |
| `AiKeyMissingCard` | thay `lib/core/widgets/ai_disabled_card.dart` | "Chưa có API key cho nhà cung cấp AI đang chọn — vào Cài đặt để thêm." + nút đi tới Settings (khớp thông điệp web) |

#### A4. `AppTheme` rút gọn

`app_theme.dart` giữ `light`/`dark` nhưng:

- `colorScheme` map sang token Bloom (`primary: accent`, `surface`, `error: danger`, `outline: border`, …) để widget Material tầng thấp vẫn ăn màu đúng.
- `extensions: [BloomColors.light]` / `[BloomColors.dark]`.
- `fontFamily: 'BeVietnamPro'`, `textTheme` theo bậc Bloom.
- Component theme tối thiểu: `sliderTheme`, `dialogTheme`, `bottomSheetTheme`, `snackBarTheme`, `textSelectionTheme` — chỉ để các chỗ chưa bọc widget Bloom không lạc tông.
- `MaterialApp.router` (`lib/main.dart`) thêm `themeMode` đọc từ setting "Chủ đề" mới.

### Phần B — Refactor theo feature

Mỗi feature = 1 đơn vị công việc độc lập: đổi màn hình + widget con sang widget Bloom, **cập nhật widget test cùng lúc** (finder theo `NavigationBar`/`FilledButton`/`RadioListTile`… sẽ vỡ → đổi sang finder widget Bloom hoặc theo text/key). Thứ tự đề xuất (theo mức phụ thuộc, shell trước):

1. **Shell** — `app_shell.dart`: `BloomScaffold` + `BloomBottomNav` (mobile) / `BloomNavRail` (wide). `BloomLeafMark` + "LexiCore" ở app bar màn gốc.
2. **Dictionary / Tra từ** — `lookup_screen.dart`, `search_bar_widget.dart`, `context_selector_widget.dart` (xoá — xem C1), `word_result_widget.dart`, `sentence_result_widget.dart`, `save_vocab_sheet.dart`. Card kết quả: `BloomCard` + `BloomCefrPill` + nút phát âm tròn + `BloomPillButton` "Lưu từ" + nút sage "✨ Khám phá". Ô tra: `BloomTextField` pill.
3. **Vocab Bank** — `vocab_bank_screen.dart`, `vocab_detail_screen.dart`, `filter_tile.dart`→`BloomFilterTile`, các sheet lọc. List: `BloomListRow`. FAB: bo góc mềm 18px màu accent (không phải `FloatingActionButton` tròn).
4. **Practice hub + SM-2** — `practice_hub_screen.dart` (grid `BloomCard`, card "Ôn tập cách khoảng" nổi bằng viền accent + `surface-3`), `practice_home_screen.dart`, `progress` (xem #10).
5. **Practice session ×4 + result** — `practice_session_screen.dart`, `flashcard_widget.dart` (thẻ `BloomCard` bo 22px + shadow ấm, `max-height` để nút chấm luôn gọn dưới; giữ flip 3D hiện có), `multiple_choice_widget.dart`, `fill_in_blank_widget.dart`, `translation_exercise_widget.dart` → `BloomMcOption`/`BloomTextField`; `session_result_screen.dart` (vòng tròn % dạng `conic-gradient` → `CustomPainter`, list kết quả `BloomCard`).
6. **Reading hub + Đọc & gõ** — `reading_hub_screen.dart`, `reading_home_screen.dart` (`BloomFilterTile` cho Ngôn ngữ/Chủ đề/Cấp độ, `AiKeyMissingCard` thay `AiDisabledCard`), `reading_session_screen.dart` (passage mờ dần quanh câu hiện tại giữ nguyên hành vi; `BloomCard` + highlight nền sage cho từ đã học + dòng dịch `surface-3` + ô gõ mono tô xanh/đỏ + `BloomProgressBar`), `reading_result_screen.dart`.
7. **Part 5** — `part5_home_screen.dart`, `part5_session_screen.dart` (list `BloomMcOption` theo câu, sticky submit bar Bloom, KHÔNG sheet), `part5_result_screen.dart`.
8. **Part 6** — `part6_session_screen.dart`: `BloomPassageSheet` (`initialChildSize: 0.44`, 1 tab), `BloomGroupChips` điều hướng đoạn, câu hỏi = `BloomExpansionTile` (thu gọn hiện đáp án đã chọn / "chưa trả lời"), ô trống đánh số inline `(1)(2)(3)`. `part6_home_screen.dart`, `part6_result_screen.dart`.
9. **Part 7** — `part7_session_screen.dart`: `BloomPassageSheet` (`initialChildSize: 0.6`, tab "Văn bản 1/2" khi đoạn đôi), `BloomGroupChips` (chỉ hiện câu hỏi 1 nhóm mỗi lần), câu hỏi `BloomMcOption`. `part7_home_screen.dart`, `part7_result_screen.dart`.
10. **Progress / Tiến độ** — màn dashboard: `dash-streak-banner` → `BloomCard` + emoji, `BloomStatCard` ×2, thanh CEFR (`BloomProgressBar` biến thể mảnh hoặc track riêng), `BloomBarChart` 7 ngày.
11. **Listening hub + Nghe chép** — `listening_home_screen.dart`, `dictation_home_screen.dart` (`AiKeyMissingCard`), `dictation_session_screen.dart` (`BloomAudioControls` + `BloomWordSeekBar` + ô điền khuyết/ô gõ mono), `dictation` result.
12. **Nghe hiểu** — `comprehension_home_screen.dart` (`_context` khởi tạo `AppContext.general` thay `settings.activeContext` — xem C1), `comprehension_session_screen.dart` (`BloomAudioControls` + `BloomWordSeekBar` xuyên bài + nhãn lượt "A"/"B" + 3 `BloomMcOption`), `comprehension_result_screen.dart`.
13. **Word Radar** — `word_radar_screen.dart` (`BloomTextField` multiline + đếm ký tự + nút "Quét", `word-radar-ai-hint` nền amber), `vocab_suggestions_section.dart` / `result_suggestions_section.dart` (`BloomCard` gợi ý + highlight nền sage cho từ đã học).
14. **Settings** — `settings_screen.dart`: `BloomSectionHeader` + `BloomCard` mỗi nhóm; xoá toggle AI (C2); thêm nhóm "Giao diện" với `BloomSegmented` Sáng/Tối/Hệ thống; `_ApiKeyDialog`/`_CustomModelDialog` giữ `AlertDialog` nhưng field dùng `BloomTextField`; `_SignedInSection` → avatar gradient + `BloomPillButton` danger "Đăng xuất".
15. **Sign-in** — `sign_in_screen.dart`: nền gradient Bloom, `BloomLeafMark` lớn, nút đăng nhập Google dạng `BloomPillButton`.

### Phần C — Đồng bộ hành vi với web

#### C1. Bỏ "Ngữ cảnh" khỏi Tra từ + `activeContext` toàn cục

- `context_selector_widget.dart` — **xoá file**; bỏ khỏi `lookup_screen.dart`.
- `UserSettingsState` (`user_settings_state.dart`) — bỏ field `activeContext`, tham số ctor, nhánh `copyWith`, `defaults`. `UserSettingsNotifier` (`user_settings_provider.dart`) — bỏ `setActiveContext` + đọc/ghi khoá SharedPreferences `active_context`.
- `lookup_use_case.dart` / `lookup_provider.dart` / `dictionary_repository*.dart` / `gemini_dictionary_source.dart` — bỏ tham số `AppContext` khỏi chuỗi lookup; prompt tra từ chỉ còn `targetLanguage` (khớp `buildWordPhrasePrompt(trimmed, targetLanguage)` của web).
- Lưu từ từ màn Tra từ (`save_vocab_sheet.dart` / `save_vocab_use_case.dart`) — `vocab_record.activeContext` gán cứng `AppContext.general` khi tạo mới (khớp `activeContext: "general"` trong `apps/web/src/lib/vocabDraft.ts`).
- `comprehension_home_screen.dart` & `reading_home_screen.dart` — `_context` khởi tạo `AppContext.general` (thay `settings.activeContext`); picker per-session giữ nguyên. **`AppContext` (entity, label, emoji) + `vocab_record.activeContext` giữ nguyên** — chỉ nguồn giá trị toàn cục biến mất.
- `AiSettingsSyncService` — không đụng (spec `2026-08-29-flutter-ai-settings-sync` đã ghi rõ `activeContext` là local-only, không sync; giờ nó chỉ biến mất khỏi local).

#### C2. Bỏ toggle "Bật AI"

- `UserSettingsState` — bỏ field `aiEnabled`, tham số ctor, `copyWith`, `defaults`. `UserSettingsNotifier` — bỏ `setAiEnabled` + khoá SharedPreferences `ai_enabled`.
- Thêm getter suy diễn (đặt ở `UserSettingsState` hoặc provider dẫn xuất): `bool get aiAvailable => activeConfig.apiKeyCiphertext?.isNotEmpty ?? false` — khớp cách web suy "AI bật" từ sự hiện diện ciphertext.
- `settings_screen.dart` — bỏ `SwitchListTile('Bật AI')`; các dòng Provider/Model/API Key **luôn hiện** (không còn `if (settings.aiEnabled)`).
- `generate_exercise_use_case.dart` — bỏ tham số `aiEnabled`; luôn `_source.generate(record)`, `catch` → `FlashcardExercise` (fallback chỉ khi lỗi/không có key → source tự ném). `practice_session_provider.dart` cập nhật lời gọi.
- `ai_disabled_card.dart` → thay bằng `AiKeyMissingCard`; các màn Reading/Listening/Word Radar/Part7 home đổi điều kiện từ `!settings.aiEnabled` sang `!settings.aiAvailable`, và nội dung card sang "thiếu API key" thay vì "AI đang tắt".
- `search_bar_widget.dart`, `word_radar_provider.dart`, `result_suggestions_section.dart`, `lookup_use_case.dart`, `dictionary_repository*.dart` — mọi tham chiếu `aiEnabled` đổi sang `aiAvailable` (tiếng Anh vẫn tra được Free Dictionary API khi thiếu key — logic đó không đổi, chỉ tên cờ đổi).
- `README.md` mục "Cấu hình AI" — bỏ bước "Bật AI toggle".

### Phần D — Chủ đề Sáng/Tối (tính năng mới nhỏ)

- `UserSettingsState` thêm `ThemeMode themePreference` (`system` mặc định); `UserSettingsNotifier.setThemePreference` + khoá SharedPreferences `theme_preference`. Local-only, **không sync** đợt này.
- `lib/main.dart` — `MaterialApp.router(themeMode: ref.watch(userSettingsNotifierProvider.select((s) => s.themePreference)))`.
- `settings_screen.dart` — nhóm "Giao diện" + `BloomSegmented`.
- `web_text_scale.dart` (`webScaled`) giữ nguyên — không gộp `fontSize` của web vào đợt này.

### Phần E — Tài liệu

- `CLAUDE.md` — thêm mục ngắn "## Theme" trỏ tới `bloom_tokens.dart` + `lib/core/theme/bloom/` là nguồn chuẩn cho UI Flutter; ghi chú Bloom được port từ `apps/web/src/styles/bloom.css` và hai file phải giữ đồng bộ khi đổi token.
- `README.md` — cập nhật: bỏ mô tả toggle AI + context selector ở Tra từ; thêm "Chủ đề Sáng/Tối" vào danh sách tính năng; đổi dòng ngăn xếp "UI: Material 3 mặc định" → "Bloom design system (port từ bản web)".

## Data / schema impact

| Nơi | Thay đổi | Rủi ro |
| --- | --- | --- |
| SharedPreferences `active_context` | Ngừng đọc/ghi; key rác còn lại vô hại | Không |
| SharedPreferences `ai_enabled` | Ngừng đọc/ghi; key rác vô hại. Người dùng từng **tắt** AI: sau update AI "bật" nếu có key — hành vi mong muốn, khớp web | Thấp — user này là chính chủ, đã có key |
| SharedPreferences `theme_preference` | Key mới | Không |
| Firestore `users/{uid}/settings/config` | Không đổi (spec sync trước đã không đưa `activeContext`/`aiEnabled` lên) | Không |
| `vocab_records/*.activeContext` | Vẫn ghi (`general` cho từ lưu ở Tra từ); đọc ở reading/listening không đổi | Không |

## Testing

- **Bloom widget library:** mỗi widget 1 file test — render light + dark (`MaterialApp` với `BloomColors.light`/`.dark` extension), trạng thái chính (active/disabled/selected), semantics/focus. `BloomPassageSheet`, `BloomExpansionTile`, `BloomGroupChips`, `BloomBarChart` cần test tương tác (kéo/mở/đổi tab/đổi nhóm).
- **Refactor màn hình:** ~474 test hiện có; widget test sẽ vỡ do đổi widget. Nguyên tắc: sửa finder (ưu tiên `find.text` / `find.byKey` / `find.byType(BloomX)`), **không đổi assertion hành vi**. Test provider/use-case/entity không bị ảnh hưởng trừ:
  - Test `UserSettingsState`/`UserSettingsNotifier` — sửa cho bỏ `activeContext`/`aiEnabled`, thêm `themePreference`.
  - Test `GenerateExerciseUseCase` — bỏ case `aiEnabled: false` → thay bằng case "source ném lỗi → FlashcardExercise".
  - Test `lookup_use_case` / `gemini_dictionary_source` — bỏ tham số context khỏi kỳ vọng prompt.
  - Test bất kỳ chỗ nào assert `AiDisabledCard` → đổi `AiKeyMissingCard` + điều kiện `aiAvailable`.
- **`flutter analyze` sạch** sau mỗi feature.
- Chạy thử thủ công (`flutter run -d chrome` + 1 thiết bị/emulator) sau shell và sau mỗi feature nặng (reading sessions, listening).
- Không có golden test hiện tại — không thêm mới đợt này (chi phí bảo trì cao cho dự án 1 người).

## Rollout

Deploy như thường lệ (`flutter build web --release` + `firebase deploy --only hosting` cho web-legacy; build mobile khi cần). Không có bước cutover riêng. Vì đổi diện rộng: khuyến nghị `firebase hosting:channel:deploy preview` xem thử trước khi deploy hosting chính.

## Thứ tự triển khai (tóm tắt cho bước plan)

```text
A1 tokens → A2 font → A3 thư viện widget (chia nhóm nhỏ) → A4 AppTheme + D theme setting
  → B1 shell
  → B2 dictionary (+C1)  → B3 vocab bank
  → B4 practice hub  → B5 practice session+result
  → B6 reading hub + đọc&gõ  → B7 part5  → B8 part6  → B9 part7
  → B10 progress
  → B11 listening + nghe chép  → B12 nghe hiểu
  → B13 word radar
  → B14 settings (+C2 hoàn tất)  → B15 sign-in
  → E tài liệu  → rà soát toàn nhánh
```

C2 đụng nhiều file rải rác — gom phần state (`UserSettingsState`/notifier) làm sớm cùng A4, phần UI hoàn tất ở B14; giữa chừng dùng `aiAvailable` ngay từ đầu.
