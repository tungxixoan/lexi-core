# LexiCore Plan 6 & 7 — Flutter Web + Luyện đọc & gõ Design Spec

**Date:** 2026-07-06
**Status:** Approved
**Covers:** Two sequential plans:
- **Plan 6:** Flutter Web enablement + adaptive navigation
- **Plan 7:** "Luyện đọc & gõ" bilingual reading & typing feature

**Depends on:** Plans 1–5 (full mobile app complete, Firebase configured)

---

## 1. Goal

Port LexiCore to Flutter Web using the existing repo, with full feature parity (minus local notifications), adaptive navigation for desktop/tablet/mobile, and a new web-first feature — "Luyện đọc & gõ" — where AI generates a bilingual passage from the user's Vocab Bank for simultaneous reading comprehension and typing practice.

---

## 2. Plan 6 — Flutter Web Enablement

### 2.1 Scope

Add `web` as a supported Flutter platform to the existing repo. Handle platform-incompatible packages. Implement adaptive navigation that fits both mobile and desktop.

### 2.2 Package Compatibility

| Package | Web support | Action |
| --- | --- | --- |
| `flutter_local_notifications` | ❌ None | Wrap all calls in `if (!kIsWeb)` guards in `NotificationService` and `NotificationNotifier` |
| `hive` / `hive_flutter` | ✅ IndexedDB | No changes needed |
| `flutter_tts` | ✅ Web Speech API | No changes needed; test on Chrome |
| `firebase_core/auth/firestore` | ✅ | No changes needed |
| `google_sign_in` | ✅ (popup flow) | No changes needed |
| `shared_preferences` | ✅ | No changes needed |
| `flutter_local_notifications` | ❌ | Guard with `kIsWeb` |

`NotificationService.initialize()`, `scheduleAll()`, `cancelAll()` all become no-ops when `kIsWeb == true`. `NotificationNotifier` checks `kIsWeb` before any scheduling.

### 2.3 Adaptive Navigation

`AppShell` uses `LayoutBuilder` to select the navigation component by screen width:

| Width | Component | Appearance |
| --- | --- | --- |
| < 600dp | `NavigationBar` | Bottom bar (current mobile layout) |
| 600–1199dp | `NavigationRail` | Left sidebar, icon + label |
| ≥ 1200dp | `NavigationRail` extended | Left sidebar, icon + full label |

All three share the same destination list. The "Luyện đọc & gõ" destination is conditionally included based on platform and settings (see §3.4).

**NavigationRail layout structure:**
```
Row(
  children: [
    NavigationRail(destinations: [...], selectedIndex: ...),
    VerticalDivider(width: 1),
    Expanded(child: widget.child),
  ],
)
```

### 2.4 Files Changed

```
lib/core/widgets/app_shell.dart            MODIFY — LayoutBuilder + adaptive nav
lib/core/services/notification_service.dart MODIFY — kIsWeb guards on all methods
lib/features/practice/presentation/
  providers/notification_notifier.dart     MODIFY — kIsWeb guard in build() + reschedule()
web/                                       CREATE — flutter create --platforms web output
```

---

## 3. Plan 7 — "Luyện đọc & gõ" Feature

### 3.1 Scope

A new tab available by default on web/desktop, optionally on mobile via Settings toggle. AI generates a 4–6 sentence bilingual passage using the user's Vocab Bank words. User reads the target-language text and types it in a textarea — a combined reading comprehension + typing practice session.

### 3.2 Passage Generation

**Input to Gemini:**
- 5–10 words from the user's VocabBank (prefer `nextReviewAt` ≤ now or most recently added)
- User's `targetCefrLevel` (or default B1 if unset)
- User's `activeContext` (General, Business, etc.)
- User's `targetLanguage` (English, 中文, 한국어, 日本語)

**Output:**
A `ReadingPassage` with 4–6 `BilingualSentence` objects, each having:
- `target: String` — sentence in target language, naturally using some of the vocab words
- `vietnamese: String` — Vietnamese translation of that sentence
- `vocabUsed: List<String>` — which vocab word IDs appear in this sentence

Vocab words used in the passage are highlighted in the target text (bold or underline).

**Prompt strategy:** Single Gemini call, JSON response. If the user has fewer than 5 words in their Vocab Bank, the feature shows a prompt to save more words first.

### 3.3 Session UI Layout

Three-row layout, web-first (min-width ~600dp recommended, works on mobile too):

```
┌──────────────────────────────────────────────────┐
│ ROW 1 — Target language passage                  │
│   Sentence 1: [full opacity — current]           │
│   Sentence 2: [40% opacity — next]               │
│   Sentence 3: [20% opacity — locked]             │
│   Vocab words bold/underlined throughout         │
├──────────────────────────────────────────────────┤
│ ROW 2 — Vietnamese translation                   │
│   Shows translation of current sentence only     │
│   Animates to next sentence when sentence done   │
├──────────────────────────────────────────────────┤
│ ROW 3 — Typing area (TextField)                  │
│   Character-by-character realtime comparison:    │
│     correct → green  |  wrong → red  |  pending → gray
│   Backspace allowed to correct                   │
│   Auto-advances to next sentence on completion   │
└──────────────────────────────────────────────────┘
```

**Sentence progression:**
- Completing a sentence (all characters correct) auto-advances
- The next sentence unblurs with a short animation (300ms fade)
- Translation row crossfades to the new sentence's Vietnamese

**Typing rules:**
- Comparison is character-exact (case-sensitive for Latin scripts; unicode exact match for 中文/한국어/日本語)
- Punctuation is required
- Sentence completed when typed string == target sentence string

### 3.4 Navigation & Visibility

- Route: `/reading`
- Tab label: **"Luyện đọc & gõ"**
- Tab icon: `Icons.menu_book_outlined` / `Icons.menu_book` (selected)
- **Default visibility:** shown on web/desktop (`!kIsWeb == false`), hidden on mobile
- **Mobile override:** `UserSettingsState.showReadingPracticeOnMobile: bool = false`
  - Toggle in SettingsScreen: *"Hiện tab Luyện đọc & gõ trên điện thoại"*

### 3.5 Session Result

After the last sentence is completed:
- Show: accuracy % (correct chars / total chars), WPM, time elapsed
- Show: list of vocab words that appeared in the passage (with their meanings)
- Buttons: "Sinh bài mới" (regenerate with same settings) | "Về trang chính"
- **No SM-2 impact** — reading/typing practice is independent from spaced repetition

### 3.6 Reading Home Screen

Before starting a session:
- Brief description of the feature
- Language pair + context selector (read-only if synced with global settings, or overridable)
- "Tạo bài luyện" (Generate) button
- Shows loading state while Gemini generates
- Error state if Vocab Bank has < 5 words: *"Hãy lưu ít nhất 5 từ vào Vocab Bank để dùng tính năng này."*
- Error state if AI is disabled: *"Tính năng này yêu cầu AI. Bật AI trong Cài đặt."*

### 3.7 Data Model

```dart
// lib/features/reading/domain/entities/reading_passage.dart

class ReadingPassage {
  final String id;                        // uuid
  final List<BilingualSentence> sentences;
  final List<String> vocabIds;            // vocab words used in passage
  final CEFRLevel level;
  final AppContext context;
  final Language targetLanguage;
  final DateTime generatedAt;
}

class BilingualSentence {
  final String target;                    // target language sentence
  final String vietnamese;               // Vietnamese translation
  final List<String> vocabIds;           // vocab words in this sentence
}
```

### 3.8 File Map

```text
lib/
├── features/
│   ├── reading/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── reading_passage.dart          CREATE
│   │   │   └── use_cases/
│   │   │       └── generate_reading_passage_use_case.dart  CREATE
│   │   ├── data/
│   │   │   └── sources/
│   │   │       └── reading_passage_source.dart   CREATE — Gemini prompt + JSON parse
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── reading_practice_provider.dart CREATE — AsyncNotifier
│   │       └── screens/
│   │           ├── reading_home_screen.dart       CREATE — generate button + error states
│   │           └── reading_session_screen.dart    CREATE — 3-row typing UI
│   ├── dictionary/domain/entities/
│   │   └── user_settings_state.dart              MODIFY — add showReadingPracticeOnMobile
│   └── settings/presentation/screens/
│       └── settings_screen.dart                  MODIFY — add toggle for mobile visibility
├── core/
│   ├── di/app_providers.dart                     MODIFY — add reading providers
│   └── router/app_router.dart                    MODIFY — add /reading route
```

---

## 4. Key Design Decisions

| Decision | Choice | Reason |
| --- | --- | --- |
| Same repo for web | Yes | 100% code reuse, Firebase already configured |
| Notifications on web | No-op (kIsWeb guard) | `flutter_local_notifications` has no web support |
| Nav component | Adaptive (Bar/Rail/Drawer) | Material 3 standard, no custom code needed |
| Passage source | AI from Vocab Bank + CEFR + context | Personalised, reinforces existing vocabulary |
| Typing: block on error? | No — highlight only | Less frustrating, better for flow state |
| SM-2 on reading session | No impact | Keep reading and spaced repetition separate |
| Min vocab for feature | 5 words | Below 5 the passage would be unnatural |
| Reading tab on mobile | Hidden by default, opt-in | Typing long passages on mobile is poor UX; power users can enable |
| Tab name | "Luyện đọc & gõ" | Accurately describes both reading and typing |

---

## 5. Out of Scope

- PWA / offline web support
- Saving passage history
- User-provided text input (AI generation only)
- Multiplayer / competitive typing
- Audio playback of passage (TTS for full passage)
- Web-specific SEO or landing page
