# LexiCore

Ứng dụng học ngôn ngữ cá nhân xây dựng bằng Flutter — tập trung vào từ vựng chủ động, luyện tập cách khoảng (spaced repetition), và đọc hiểu song ngữ có trợ giúp của AI.

> Dự án cá nhân — dành cho người Việt học tiếng Anh, Trung, Nhật, Hàn.

---

## Tính năng

### Tra từ thông minh (Dictionary / Lookup)
- Nhận dạng tự động loại đầu vào: từ đơn, cụm từ (phrase), hoặc câu
- Tra cứu qua **Free Dictionary API** (tiếng Anh offline-first) hoặc **AI** (các ngôn ngữ khác)
- Phiên âm IPA, nghĩa tiếng Việt, ví dụ ngữ cảnh, gợi ý chủ đề
- Dịch câu sang tiếng Việt tức thì
- Gợi ý từ ngẫu nhiên theo ngữ cảnh hiện tại ("Discover Word")
- 8 ngữ cảnh học tập: General, Business, Technology, Travel, Food & Drink, Health, Academic, Social/Casual
- Text-to-Speech cho 5 ngôn ngữ (EN, ZH, KO, JA, VI)

### Ngân hàng từ vựng (Vocabulary Bank)
- Lưu từ trực tiếp từ màn hình tra từ với một thao tác
- Ghi chú cá nhân (personal notes) cho từng từ
- Gán nhiều chủ đề (topics) cho mỗi từ
- Quản lý chủ đề: tạo mới, đổi tên, xóa
- Lọc danh sách theo cấp độ CEFR (A1–C2) và chủ đề
- Xem chi tiết, sửa, xóa từ

### Luyện tập cách khoảng (Spaced Repetition Practice)
- Thuật toán **SM-2** tính lịch ôn tập tối ưu
- Tự động tạo bài tập bằng AI theo cấp độ CEFR của từng từ:
  - **Multiple Choice** (A1/A2)
  - **Fill in the Blank** (B1/B2)
  - **Translation** (C1/C2)
  - **Flashcard** (fallback khi AI tắt hoặc lỗi)
- Phiên luyện tập có điểm số và tổng kết kết quả
- Bộ lọc luyện tập theo cấp độ CEFR mục tiêu

### Luyện đọc & gõ (Bilingual Reading Practice)
- AI tạo đoạn văn 4–6 câu sử dụng từ vựng trong ngân hàng của bạn
- Giao diện song ngữ: câu tiếng mục tiêu + dịch tiếng Việt
- Luyện gõ từng câu — tính WPM (từ/phút) và độ chính xác
- Tô màu từ vựng đã học xuất hiện trong đoạn văn
- Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt)

### Tiến độ học tập (Progress Dashboard)
- Tổng số từ đã học
- Chuỗi ngày học (streak)
- Từ đến hạn ôn tập hôm nay
- Thống kê phân bố cấp độ CEFR

### Đồng bộ đám mây (Firebase Sync)
- **Offline-first:** Hive (IndexedDB trên web) là nguồn dữ liệu chính
- Đăng nhập Google để đồng bộ tự động lên Firestore
- Đồng bộ hai chiều thời gian thực (Hive ↔ Firestore)
- Ngăn echo-loop: guard set chặn lại Firestore write do chính sync tạo ra
- Phát hiện từ trùng lặp O(1) bằng headword-index (`headword|language → id`)
- Xử lý xung đột: giữ phiên bản mới hơn theo `updatedAt`
- Cô lập tài khoản: xóa Hive khi đăng nhập tài khoản khác (không xóa khi đăng xuất)
- API key và cấu hình AI **không bao giờ** được ghi lên Firestore

### AI đa nhà cung cấp (Multi-Provider AI)
Hỗ trợ 3 nhà cung cấp LLM, có thể chuyển đổi trong Cài đặt:

| Provider | Giao thức | Endpoint | Ghi chú |
|----------|-----------|----------|---------|
| **Gemini** | `google_generative_ai` SDK | N/A | Mặc định |
| **Groq** | OpenAI-compatible REST | `https://api.groq.com/openai/v1` | Free tier |
| **OpenRouter** | OpenAI-compatible REST | `https://openrouter.ai/api/v1` | Tổng hợp nhiều model |

- Mỗi provider nhớ riêng API key và model đã chọn
- Chuyển provider không mất cấu hình của provider cũ
- Model preset cho từng provider + nhập tên model tùy ý ("Khác...")
- Tất cả key lưu ở **SharedPreferences** — không đồng bộ lên đám mây

### Thông báo nhắc nhở
- Thông báo hàng ngày khi có từ đến hạn ôn
- Cài đặt giờ nhắc cố định

---

## Ngăn xếp công nghệ

| Lớp | Công nghệ |
|-----|-----------|
| Framework | Flutter 3.x (Dart ≥3.4) |
| State Management | [Riverpod](https://riverpod.dev/) + `riverpod_annotation` + `build_runner` |
| Routing | [go_router](https://pub.dev/packages/go_router) |
| Local Storage | [Hive](https://pub.dev/packages/hive) + `hive_flutter` (hoạt động cả web/mobile) |
| User Preferences | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Auth & Cloud | Firebase Auth + Cloud Firestore + Google Sign-In |
| AI — Gemini | [google_generative_ai](https://pub.dev/packages/google_generative_ai) |
| AI — Groq/OpenRouter | [http](https://pub.dev/packages/http) (OpenAI-compatible REST) |
| TTS | [flutter_tts](https://pub.dev/packages/flutter_tts) |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) + timezone |
| Testing | flutter_test + [mocktail](https://pub.dev/packages/mocktail) + [mockito](https://pub.dev/packages/mockito) |

---

## Kiến trúc

Dự án theo Clean Architecture kết hợp feature-first folder structure:

```
lib/
├── core/
│   ├── di/                  # Riverpod providers tổng hợp (app_providers.dart)
│   ├── router/              # go_router cấu hình (app_router.dart)
│   ├── services/
│   │   ├── ai_client_factory.dart   # Factory đa provider (Gemini SDK / OpenAI HTTP)
│   │   ├── sync_service.dart        # Hive ↔ Firestore bidirectional sync
│   │   ├── stats_service.dart       # Tính toán tiến độ học tập
│   │   └── notification_service.dart
│   ├── theme/               # AppTheme (light + dark)
│   ├── utils/               # InputDetector (word/phrase/sentence)
│   └── widgets/             # AppShell (adaptive navigation)
│
├── features/
│   ├── dictionary/
│   │   ├── data/sources/
│   │   │   ├── gemini_dictionary_source.dart   # AI lookup (dùng AiClientFactory)
│   │   │   └── free_dictionary_source.dart     # Free Dictionary API
│   │   ├── domain/
│   │   │   ├── entities/    # Language, AppContext, InputType, LookupResult
│   │   │   │               # AiProvider, ProviderConfig, UserSettingsState
│   │   │   ├── repositories/
│   │   │   └── use_cases/   # LookupUseCase
│   │   └── presentation/
│   │       ├── providers/   # LookupProvider, UserSettingsNotifier
│   │       ├── screens/     # LookupScreen
│   │       └── widgets/     # SearchBar, ContextSelector, WordResult, SentenceResult
│   │
│   ├── vocabulary/
│   │   ├── data/            # VocabRepositoryImpl (Hive)
│   │   ├── domain/
│   │   │   ├── entities/    # VocabRecord, Topic, CEFRLevel
│   │   │   └── use_cases/   # Save, Get, Update, Delete, GetTopics, AddTopic, DeleteTopic
│   │   └── presentation/
│   │       ├── providers/   # VocabBankProvider, TopicsProvider
│   │       └── screens/     # VocabBankScreen, VocabDetailScreen
│   │
│   ├── practice/
│   │   ├── data/sources/
│   │   │   └── exercise_generator_source.dart  # AI exercise gen (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # Exercise (4 loại), ExerciseResult, LearningStats
│   │   │   └── use_cases/   # GenerateExercise, ComputeSM2, GetLearningStats
│   │   └── presentation/
│   │       ├── providers/   # PracticeSessionProvider, NotificationNotifier
│   │       └── screens/     # PracticeHome, PracticeSession, SessionResult, Progress
│   │
│   ├── reading/
│   │   ├── data/sources/
│   │   │   └── reading_passage_source.dart     # AI passage gen (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # ReadingPassage, BilingualSentence
│   │   │   └── use_cases/   # GenerateReadingPassage
│   │   └── presentation/
│   │       ├── providers/   # ReadingPracticeNotifier
│   │       └── screens/     # ReadingHome, ReadingSession, ReadingResult
│   │
│   └── settings/
│       └── presentation/
│           ├── providers/   # AuthNotifier, SyncNotifier
│           └── screens/     # SettingsScreen
│
└── main.dart
```

### Luồng dữ liệu AI

```
UserSettingsNotifier (SharedPreferences)
  └─ activeProvider + activeConfig (apiKey, model)
       └─ AiClientFactory.buildClient(settings)
            ├─ AiProvider.gemini  → _GeminiClient (google_generative_ai SDK)
            ├─ AiProvider.groq    → _OpenAiClient (HTTP → api.groq.com)
            └─ AiProvider.openRouter → _OpenAiClient (HTTP → openrouter.ai)
                 └─ GenerativeModelClient interface
                      ├─ GeminiDictionarySource
                      ├─ ExerciseGeneratorSource
                      └─ ReadingPassageSource
```

### Luồng đồng bộ

```
Hive (local)  ←──────────────────────→  Firestore (cloud)
     │  watchBoxEvents()                      │  snapshots()
     │                                        │
     └──── SyncService ──────────────────────┘
              │
              ├─ Echo guard: _firestoreUpdatingVocab Set
              ├─ Dedup: headword|language index (O(1))
              └─ Conflict: giữ updatedAt mới hơn
```

---

## Cài đặt

### Yêu cầu

- Flutter SDK ≥ 3.4.0
- Dart SDK ≥ 3.4.0
- Firebase project (Auth + Firestore)
- Google Cloud OAuth 2.0 Web Client (cho web)

### 1. Clone và cài dependencies

```bash
git clone https://github.com/dmTung/lexi-core.git
cd lexi-core
flutter pub get
```

### 2. Cấu hình Firebase

```bash
# Cài FlutterFire CLI nếu chưa có
dart pub global activate flutterfire_cli

# Cấu hình — chọn Android, iOS, Web tùy nhu cầu
flutterfire configure
```

Lệnh này tạo `lib/firebase_options.dart` tự động.

**Firestore Security Rules** (dán vào Firebase Console → Firestore → Rules):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. Cấu hình Google Sign-In (Web)

1. Vào [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
2. Tạo **OAuth 2.0 Client ID** loại **Web application**
3. Thêm Authorized JavaScript Origins: `http://localhost:5000` (hoặc domain deploy của bạn)
4. Vào Firebase Console → Authentication → Sign-in method → Google → bật lên

### 4. Chạy ứng dụng

```bash
# Android / iOS
flutter run

# Web (port cố định để khớp OAuth origin)
flutter run -d chrome --web-port 5000
```

---

## Cấu hình AI

Vào **Cài đặt → AI** trong ứng dụng:

1. **Bật AI** toggle
2. Chọn **Provider**: Gemini / Groq / OpenRouter
3. Chọn **Model** từ danh sách preset hoặc nhập tên tùy ý
4. Nhập **API Key**

Ứng dụng nhớ model và key riêng cho từng provider — chuyển đổi qua lại không mất cấu hình.

### Lấy API Key

| Provider | Đăng ký tại | Free tier |
|----------|------------|-----------|
| Gemini | [aistudio.google.com](https://aistudio.google.com/) | Có (rate limited) |
| Groq | [console.groq.com](https://console.groq.com/) | Có |
| OpenRouter | [openrouter.ai](https://openrouter.ai/) | Có (giới hạn model) |

### Model mặc định

| Provider | Model mặc định | Các lựa chọn khác |
|----------|---------------|------------------|
| Gemini | `gemini-2.5-flash` | `gemini-2.5-pro`, `gemini-2.0-flash`, `gemini-1.5-flash` |
| Groq | `llama-3.3-70b-versatile` | `llama-3.1-8b-instant`, `mixtral-8x7b-32768`, `gemma2-9b-it` |
| OpenRouter | `meta-llama/llama-3.3-70b-instruct` | `google/gemini-2.5-flash`, `anthropic/claude-haiku-4-5`, `mistralai/mixtral-8x7b-instruct` |

---

## Ngôn ngữ được hỗ trợ

| Ngôn ngữ | Tra từ (Free API) | Tra từ (AI) | TTS |
|----------|------------------|------------|-----|
| English | ✅ | ✅ | ✅ |
| 中文 (Chinese) | — | ✅ | ✅ |
| 한국어 (Korean) | — | ✅ | ✅ |
| 日本語 (Japanese) | — | ✅ | ✅ |
| Tiếng Việt | — | ✅ | ✅ |

> Tiếng Anh dùng Free Dictionary API, không cần AI key. Các ngôn ngữ khác yêu cầu AI bật.

---

## Phát triển

### Codegen (Riverpod)

Sau khi sửa provider hoặc thêm `@riverpod` annotation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Chạy tests

```bash
# Toàn bộ
flutter test

# Một file cụ thể
flutter test test/features/dictionary/presentation/providers/user_settings_notifier_test.dart

# Với verbose
flutter test --reporter expanded
```

Hiện tại: **133 tests** — domain entities, use cases, sources, providers, UI widgets, services.

### Phân tích code

```bash
flutter analyze
```

### Build release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Web
flutter build web --release
```

---

## Bảo mật

- **API key AI không bao giờ được ghi lên Firestore** — lưu hoàn toàn trong SharedPreferences
- Chỉ các trường sau được đồng bộ lên Firestore: `targetLanguage`, `activeContext`, `aiEnabled`, `targetCefrLevel`
- Dữ liệu từ vựng (`vocab_records`, `topics`) đồng bộ có mã hóa Firestore
- Firebase Security Rules giới hạn đọc/ghi theo UID người dùng

---

## Cấu trúc Firestore

```
users/
  {uid}/
    vocab_records/
      {id}/
        headword: string
        inputType: string
        ipa: string
        meaning: string
        examples: string[]
        personalNotes: string
        topicIds: string[]
        targetLanguage: string
        cefrLevel: string
        activeContext: string
        createdAt: timestamp
        updatedAt: timestamp
        easinessFactor: number   # SM-2
        interval: number         # SM-2
        repetitions: number      # SM-2
        nextDueAt: timestamp     # SM-2
    topics/
      {id}/
        name: string
        createdAt: timestamp
    settings/
      user/
        targetLanguage: string
        activeContext: string
        aiEnabled: boolean
        targetCefrLevel: string | null
```

---

## Roadmap

- [ ] Hỗ trợ thêm ngôn ngữ (French, Spanish, German)
- [ ] Export/Import từ vựng (CSV, Anki)
- [ ] Luyện tập nghe (listening comprehension)
- [ ] Widget màn hình chính hiển thị từ ngẫu nhiên
- [ ] Tìm kiếm full-text trong ngân hàng từ
- [ ] Thống kê học tập nâng cao (heatmap, phân tích lỗi)

---

## License

Dự án cá nhân — không có license công khai.
