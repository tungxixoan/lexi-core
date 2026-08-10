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

### Luyện đọc (Reading Practice)
Hub với 4 tính năng con (truy cập qua tab "Luyện tập" → card "Luyện đọc"):

- **Đọc & gõ (Bilingual Reading Practice)**
  - AI tạo đoạn văn 4–6 câu sử dụng từ vựng trong ngân hàng của bạn
  - Giao diện song ngữ: câu tiếng mục tiêu + dịch tiếng Việt
  - Luyện gõ từng câu — tính WPM (từ/phút) và độ chính xác
  - Tô màu từ vựng đã học xuất hiện trong đoạn văn
  - Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- **Part 5 — Điền câu (TOEIC Incomplete Sentences)**
  - AI tạo 15 câu điền từ/ngữ pháp trắc nghiệm 4 đáp án, độc lập với Vocab Bank
  - Hiệu chỉnh độ khó theo **Economy TOEIC Vol 2–5** (chọn nhiều mức cùng lúc, không chọn = tất cả)
  - Trả lời hết 15 câu rồi mới nộp bài; kết quả hiện điểm X/15, giải thích đúng/sai từng câu, gợi ý từ mới
  - Không ảnh hưởng SM-2 — không có từ vựng cụ thể nào để gắn điểm vào
- **Part 6 — Điền đoạn văn (TOEIC Text Completion)**
  - AI tạo 3 đoạn văn ngắn (email/thông báo/thư...), mỗi đoạn 4 chỗ trống trắc nghiệm — luôn có ít nhất 1 chỗ trống dạng "chọn câu phù hợp nhất" mỗi đoạn
  - Cùng cơ chế Economy TOEIC Vol 2–5, trả lời hết 12 câu rồi nộp bài, kết quả X/12 kèm giải thích từng câu và gợi ý từ mới
  - Không ảnh hưởng SM-2
- **Part 7 — Đọc hiểu (TOEIC Reading Comprehension)**
  - AI tạo 2 đoạn văn đơn (3–4 câu hỏi/đoạn) + 1 bộ đoạn văn đôi (2 văn bản liên quan, 5 câu hỏi, ít nhất 1 câu cần đối chiếu cả 2 văn bản) — tổng ~11–13 câu/phiên
  - Cùng cơ chế Economy TOEIC Vol 2–5, trả lời hết rồi nộp bài, kết quả X/N (N tính động theo số câu thực tế) kèm giải thích từng câu và gợi ý từ mới
  - Không ảnh hưởng SM-2

### Luyện nghe (Listening Practice)
Hub với 2 tính năng con (truy cập qua tab "Luyện tập" → card "Luyện nghe"), dùng chung `TtsService` (flutter_tts) có sẵn, không cần package audio mới:

- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - **3 mức độ** (chọn mỗi phiên luyện tập, mặc định Khó):
    - **Dễ** — điền 2 ô trống 1-từ rời rạc, phần còn lại của câu hiện sẵn (dạng điền khuyết)
    - **Trung bình** — điền 1 cụm từ liên tục (~35% số từ của câu), phần còn lại hiện sẵn
    - **Khó** — chép lại toàn bộ câu từ trí nhớ, không hiện gì (mù hoàn toàn)
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm — áp dụng cho cả 3 mức độ
  - **Thanh trượt tua theo từ** (không có audio file để tua theo thời gian — TTS luôn đọc từ điểm tua tới hết câu): kéo thả trừ 1-5% tùy tỷ lệ câu sẽ được nghe lại (kéo về gần đầu câu bị trừ nhiều hơn kéo về gần cuối câu, chống việc dùng tua thay thế Nghe lại với giá rẻ); lần nghe đầu tiên của phiên luôn miễn phí dù qua nút Phát hay slider
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2). Dễ/Trung bình chấm theo số ô điền đúng (không phân biệt hoa/thường); Khó chấm theo từng ký tự — cùng công thức trừ điểm và cùng ngưỡng quy đổi SM-2
  - Màn hình kết quả: điểm số, số lần nghe lại, **số lần tua** (kèm % bị trừ), thời gian; Khó hiện phần gõ tô màu đối chiếu ký tự, Dễ/Trung bình hiện lại đúng đoạn điền khuyết với từng ô tô xanh (đúng)/đỏ kèm đáp án đúng (sai)
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
- **Nghe hiểu (TOEIC-style comprehension)** — AI tạo ngẫu nhiên một hội thoại 2 người (nhãn "A"/"B", đổi cao độ giọng để phân biệt) hoặc một bài nói 1 người, cộng đúng 3 câu hỏi trắc nghiệm 4 đáp án (ý chính/chi tiết/ý ngụ ý — không điền từ), bằng ngôn ngữ mục tiêu giống TOEIC thật
  - Điều khiển nghe theo từng lượt: ⏮ lượt trước / ▶️⏸ phát-dừng / ⏭ lượt sau / 🔁 phát lại từ đầu
  - **Thanh trượt tua theo từ, xuyên suốt toàn bộ bài** (nhiều lượt thoại nối lại) — kéo qua ranh giới lượt tự chuyển lượt + đổi cao độ giọng tương ứng; bổ sung cho các nút điều khiển trên, không thay thế
  - Nghe lại/tua thoải mái, **không trừ điểm** (khác Nghe chép) — mục tiêu là luyện hiểu, không phải áp lực thi 1 lần
  - Trả lời cả 3 câu rồi mới nộp bài; kết quả hiện điểm X/3, phân tích từng câu, và toàn bộ bản ghi hội thoại/bài nói
  - Lọc theo Ngôn ngữ / Chủ đề (**AppContext** — Business/Travel/...) / Cấp độ — không cần Vocab Bank, không có ngưỡng số từ tối thiểu
  - **Không ảnh hưởng SM-2** — không có từ vựng cụ thể nào để gắn điểm vào

### Quét từ vựng (Word Radar)
Truy cập qua tab "Luyện tập" → card "Quét từ vựng":

- Dán bất kỳ văn bản nào (bài báo, tin nhắn...) vào ô nhập (tối đa 3000 ký tự), bấm "Quét"
- **Highlight từ đã học** — quét cục bộ (không cần AI), so khớp chuỗi con không phân biệt hoa/thường với Vocab Bank; hiện ngay lập tức, hoạt động cả khi tắt AI
- Bấm vào từ đã highlight để mở thẳng trang chi tiết từ đó trong Vocab Bank
- **Gợi ý từ mới** (cần bật AI) — 1 lần gọi AI duy nhất, loại trừ các từ đã có trong Vocab Bank, trả về đầy đủ IPA/nghĩa/định nghĩa/từ đồng nghĩa/ví dụ/chủ đề gợi ý/cấp độ CEFR cho mỗi từ
- Bấm "Lưu" trên gợi ý để mở sheet lưu từ y hệt luồng tra từ ở tab Dictionary (chỉnh sửa nghĩa, chọn chủ đề, ghi chú trước khi lưu)
- **Bản dịch tiếng Việt** của toàn bộ đoạn văn (cùng 1 lần gọi AI ở trên) — cũng highlight nghĩa tiếng Việt của các từ đã học trong bản dịch (chỉ hiển thị, không bấm được)
- Không ảnh hưởng SM-2 cho tới khi người dùng chủ động lưu một từ gợi ý

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
│   │       └── screens/     # PracticeHub (tab), PracticeHome (SM-2), PracticeSession, SessionResult, Progress
│   │
│   ├── reading/
│   │   ├── data/sources/
│   │   │   ├── reading_passage_source.dart     # AI passage gen (dùng AiClientFactory)
│   │   │   ├── part5_source.dart                # AI Part 5 gen (TOEIC Incomplete Sentences)
│   │   │   ├── part6_source.dart                # AI Part 6 gen (TOEIC Text Completion)
│   │   │   └── part7_source.dart                # AI Part 7 gen + shape validation (TOEIC Reading Comprehension)
│   │   ├── domain/
│   │   │   ├── entities/    # ReadingPassage, BilingualSentence, EconomyVolume,
│   │   │   │               # Part5Question/Part5Set, Part6Question/Part6Passage/Part6Set,
│   │   │   │               # Part7Question/Part7PassageGroup/Part7Set
│   │   │   └── use_cases/   # GenerateReadingPassage, GeneratePart5Set, GeneratePart6Set, GeneratePart7Set
│   │   └── presentation/
│   │       ├── providers/   # ReadingPracticeNotifier, Part5PracticeNotifier, Part6PracticeNotifier,
│   │       │               # Part7PracticeNotifier
│   │       └── screens/     # ReadingHub (hub), ReadingHome/Session/Result (bilingual),
│   │                        # Part5Home/Session/Result, Part6Home/Session/Result
│   │
│   ├── listening/
│   │   ├── data/sources/
│   │   │   ├── dictation_source.dart           # AI sentence gen (dùng AiClientFactory)
│   │   │   └── listening_passage_source.dart   # AI conversation/talk gen (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # DictationItem, ListeningPassage, ListeningTurn, ListeningQuestion
│   │   │   └── use_cases/   # GenerateDictationItem, GenerateListeningPassage
│   │   └── presentation/
│   │       ├── providers/   # DictationPracticeNotifier, ListeningComprehensionNotifier
│   │       └── screens/     # ListeningHome (hub), DictationHome/Session/Result,
│   │                        # ComprehensionHome/Session/Result
│   │
│   ├── word_radar/
│   │   ├── data/sources/
│   │   │   └── word_radar_source.dart          # AI suggestions + translation (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # WordRadarAiResult
│   │   │   └── use_cases/   # FindKnownHeadwords (local), GenerateWordSuggestions
│   │   └── presentation/
│   │       ├── providers/   # WordRadarNotifier
│   │       └── screens/     # WordRadarScreen
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
                      ├─ ReadingPassageSource
                      ├─ Part5Source
                      ├─ Part6Source
                      ├─ Part7Source
                      ├─ DictationSource
                      ├─ ListeningPassageSource
                      └─ WordRadarSource
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

Hiện tại: **474 tests** — domain entities, use cases, sources, providers, UI widgets, services.

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

### Deploy Web (Firebase Hosting)

Web app được host trên Firebase Hosting (project `lexi-core`), cấu hình tại [firebase.json](firebase.json).

```bash
# 1. (tuỳ chọn) test nhanh trên trình duyệt trước khi build
flutter run -d chrome

# 2. Build bản release + deploy
flutter build web --release
firebase deploy --only hosting
```

Live tại: [lexi-core.web.app](https://lexi-core.web.app)

**Preview trước khi lên live** (khuyến nghị cho thay đổi lớn) — deploy lên URL tạm, không ảnh hưởng bản chính thức:

```bash
flutter build web --release
firebase hosting:channel:deploy preview
```

**Rollback**: Firebase Console → Hosting → Release history → chọn version cũ → Rollback (không cần build lại).

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

- [x] Nghe chép (listening dictation)
- [x] Nghe hiểu (TOEIC-style listening comprehension)
- [x] **Word Radar** — dán văn bản bất kỳ, tự động highlight từ đã học (Vocab Bank), gợi ý từ mới đáng học, và dịch nghĩa cả đoạn văn

**Ưu tiên tiếp theo:**

- [ ] **Serial Story** — AI viết truyện nhiều kỳ dùng từ vựng sắp đến hạn ôn, ra chương mới mỗi ngày

**Ý tưởng khác đã brainstorm (chưa xếp lịch):**

- [ ] AI Roleplay Conversation — luyện hội thoại tình huống với AI đóng vai đối phương, chấm điểm cuối buổi
- [ ] Shadowing Practice — nói đè lên TTS, AI so sánh nhịp điệu/độ trễ
- [ ] Error Pattern Coach — AI phân tích lịch sử làm bài để tự sinh bài tập nhắm đúng lỗi hay lặp lại

**Việc nhỏ hơn:**

- [ ] Hỗ trợ thêm ngôn ngữ (French, Spanish, German)
- [ ] Export/Import từ vựng (CSV, Anki)
- [ ] Widget màn hình chính hiển thị từ ngẫu nhiên
- [ ] Tìm kiếm full-text trong ngân hàng từ
- [ ] Thống kê học tập nâng cao (heatmap, phân tích lỗi)

---

## License

Dự án cá nhân — không có license công khai.
