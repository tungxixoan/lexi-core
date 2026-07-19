# Plan 9 — Task 08: Update README

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 9 Tasks 01–07 complete (feature fully implemented and tested)

## Global Constraints
(see `plan9-global-constraints.md`)

## What This Task Delivers
Documents the new "Luyện nghe" tab and its "Nghe chép" (dictation) feature in `README.md`, following the exact structure/style already used for "Luyện đọc & gõ": a new bullet section under **Tính năng**, a new `listening/` block in the **Kiến trúc** folder tree, `DictationSource` added to the **Luồng dữ liệu AI** diagram, the **test count** line updated to the real final number, and the **Roadmap** line for listening updated to reflect that dictation is done while comprehension (Plan 10) is still pending.

This is a documentation-only task — no application code changes, no automated tests. Verification is by direct reading of the diffed sections (Step 7) and a build-doesn't-break sanity check (README changes can't break `flutter analyze`/`flutter test`, but Step 8 runs them anyway since they're cheap and this is the last task in the plan).

## Files
- Modify: `README.md`

## Steps

- [ ] **Step 1: Confirm the final test count**

```bash
flutter test 2>&1 | tail -5
```

Note the final summary line (e.g. `+165: All tests passed!`) — the number of tests is what Step 6 below writes into the README. This repo's test count was **133** before Plan 9; expect roughly **+30 to +40** new tests from Tasks 01–07 (settings toggle: 3, entity: 2, source: 2, use case: 1, scoring formula: 6, hub: 2, dictation home: 4, dictation session: 5, dictation result: 4, plus the app_shell tab tests from Task 04: 3) — use the **actual** printed number, not this estimate.

- [ ] **Step 2: Add the "Luyện nghe" feature section**

In `README.md`, insert a new section immediately after the existing "### Luyện đọc & gõ (Bilingual Reading Practice)" section (i.e. right before "### Tiến độ học tập (Progress Dashboard)"):

Find this exact block (the end of the Reading section and start of the Progress section):

```markdown
- Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt)

### Tiến độ học tập (Progress Dashboard)
```

Replace it with:

```markdown
- Màn hình kết quả: độ chính xác tổng, WPM, danh sách từ đã thực hành
- Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt)

### Luyện nghe (Listening Practice)
Tab "Luyện nghe" — hub với 2 tính năng con, dùng chung `TtsService` (flutter_tts) có sẵn, không cần package audio mới:

- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2)
  - Màn hình kết quả: điểm số, số lần nghe lại, thời gian, phần gõ được tô màu đối chiếu với câu đúng
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
  - Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt), hiển thị dựa theo bề rộng màn hình (không dùng `kIsWeb`)
- **Nghe hiểu (TOEIC-style comprehension)** — *sắp ra mắt* — nghe hội thoại 2 người hoặc bài nói 1 người, trả lời trắc nghiệm kiểu TOEIC Part 3–4 (ý chính/chi tiết/ý ngụ ý), không ảnh hưởng SM-2

### Tiến độ học tập (Progress Dashboard)
```

- [ ] **Step 3: Add the `listening/` block to the Kiến trúc folder tree**

Find this exact block inside the ` ```text ` fenced folder tree (the `reading/` block followed by the `settings/` block):

```markdown
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
```

Replace it with:

```markdown
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
│   ├── listening/
│   │   ├── data/sources/
│   │   │   └── dictation_source.dart           # AI sentence gen (dùng AiClientFactory)
│   │   ├── domain/
│   │   │   ├── entities/    # DictationItem
│   │   │   └── use_cases/   # GenerateDictationItem
│   │   └── presentation/
│   │       ├── providers/   # DictationPracticeNotifier
│   │       └── screens/     # ListeningHome (hub), DictationHome, DictationSession, DictationResult
│   │
│   └── settings/
```

- [ ] **Step 4: Add DictationSource to the Luồng dữ liệu AI diagram**

Find this exact block:

```markdown
                 └─ GenerativeModelClient interface
                      ├─ GeminiDictionarySource
                      ├─ ExerciseGeneratorSource
                      └─ ReadingPassageSource
```

Replace it with:

```markdown
                 └─ GenerativeModelClient interface
                      ├─ GeminiDictionarySource
                      ├─ ExerciseGeneratorSource
                      ├─ ReadingPassageSource
                      └─ DictationSource
```

- [ ] **Step 5: Update the Roadmap line**

Find this exact line:

```markdown
- [ ] Luyện tập nghe (listening comprehension)
```

Replace it with:

```markdown
- [x] Nghe chép (listening dictation)
- [ ] Nghe hiểu (TOEIC-style listening comprehension)
```

- [ ] **Step 6: Update the test count**

Find this exact line:

```markdown
Hiện tại: **133 tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

Replace `133` with the actual number from Step 1's `flutter test` output:

```markdown
Hiện tại: **<ACTUAL_COUNT> tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

- [ ] **Step 7: Verify all 5 edits landed correctly**

```bash
grep -n "Luyện nghe (Listening Practice)\|dictation_source.dart\|DictationSource$\|Nghe chép (listening dictation)\|Hiện tại: \*\*" README.md
```

Expected: one match for each pattern, confirming all edits are present and none were accidentally duplicated.

- [ ] **Step 8: Sanity-check the repo still analyzes/tests cleanly**

```bash
flutter analyze
flutter test
```

Expected: both succeed (README changes cannot affect these, but this is the last task in the plan — confirm nothing was left broken from earlier tasks).

- [ ] **Step 9: Commit**

```bash
git add README.md
git commit -m "docs: document Luyện nghe / Nghe chép (dictation) feature in README"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (final count used in README)
Concerns: (if any)
