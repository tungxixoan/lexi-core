# Plan 10 — Task 08: Update README

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Tasks 01–07 complete (feature fully implemented and tested)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Documents "Nghe hiểu" (TOEIC-style comprehension) in `README.md`: updates the existing "Luyện nghe" feature bullet (removes "sắp ra mắt", adds real detail), extends the `listening/` block in the **Kiến trúc** folder tree, adds `ListeningPassageSource` to the **Luồng dữ liệu AI** diagram, updates the **test count** to the real final number, and flips the **Roadmap** line for comprehension from pending to done.

This is a documentation-only task — no application code changes, no automated tests. Verification is by direct reading of the diffed sections (Step 8) plus a sanity check that nothing was left broken (Step 9).

## Files
- Modify: `README.md`

## Steps

- [ ] **Step 1: Confirm the final test count**

```bash
flutter test 2>&1 | tail -5
```

Note the final summary line — this repo's test count was **182** before Plan 10; expect roughly **+35 to +45** new tests from Tasks 01–07 (entities: 5, TtsService pitch: 4, source: 2, use case: 1, notifier: 10, hub-card-enable: 1, comprehension home: 3, comprehension session: 6, comprehension result: 4) — use the **actual** printed number, not this estimate.

- [ ] **Step 2: Update the "Luyện nghe" feature section**

In `README.md`, find this exact block:

```markdown
- **Nghe hiểu (TOEIC-style comprehension)** — *sắp ra mắt* — nghe hội thoại 2 người hoặc bài nói 1 người, trả lời trắc nghiệm kiểu TOEIC Part 3–4 (ý chính/chi tiết/ý ngụ ý), không ảnh hưởng SM-2
```

Replace it with:

```markdown
- **Nghe hiểu (TOEIC-style comprehension)** — AI tạo ngẫu nhiên một hội thoại 2 người (nhãn "A"/"B", đổi cao độ giọng để phân biệt) hoặc một bài nói 1 người, cộng đúng 3 câu hỏi trắc nghiệm 4 đáp án (ý chính/chi tiết/ý ngụ ý — không điền từ), bằng ngôn ngữ mục tiêu giống TOEIC thật
  - Điều khiển nghe theo từng lượt: ⏮ lượt trước / ▶️⏸ phát-dừng / ⏭ lượt sau / 🔁 phát lại từ đầu — không có thanh tua liên tục
  - Nghe lại/tua thoải mái, **không trừ điểm** (khác Nghe chép) — mục tiêu là luyện hiểu, không phải áp lực thi 1 lần
  - Trả lời cả 3 câu rồi mới nộp bài; kết quả hiện điểm X/3, phân tích từng câu, và toàn bộ bản ghi hội thoại/bài nói
  - Lọc theo Ngôn ngữ / Chủ đề (**AppContext** — Business/Travel/...) / Cấp độ — không cần Vocab Bank, không có ngưỡng số từ tối thiểu
  - **Không ảnh hưởng SM-2** — không có từ vựng cụ thể nào để gắn điểm vào
```

- [ ] **Step 3: Extend the `listening/` block in the Kiến trúc folder tree**

Find this exact block:

```markdown
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

Replace it with:

```markdown
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
│   └── settings/
```

- [ ] **Step 4: Add ListeningPassageSource to the Luồng dữ liệu AI diagram**

Find this exact block:

```markdown
                 └─ GenerativeModelClient interface
                      ├─ GeminiDictionarySource
                      ├─ ExerciseGeneratorSource
                      ├─ ReadingPassageSource
                      └─ DictationSource
```

Replace it with:

```markdown
                 └─ GenerativeModelClient interface
                      ├─ GeminiDictionarySource
                      ├─ ExerciseGeneratorSource
                      ├─ ReadingPassageSource
                      ├─ DictationSource
                      └─ ListeningPassageSource
```

- [ ] **Step 5: Flip the Roadmap line**

Find this exact line:

```markdown
- [ ] Nghe hiểu (TOEIC-style listening comprehension)
```

Replace it with:

```markdown
- [x] Nghe hiểu (TOEIC-style listening comprehension)
```

- [ ] **Step 6: Update the test count**

Find this exact line:

```markdown
Hiện tại: **182 tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

Replace `182` with the actual number from Step 1's `flutter test` output:

```markdown
Hiện tại: **<ACTUAL_COUNT> tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

- [ ] **Step 7: Verify all 5 edits landed correctly**

```bash
grep -n "ListeningPassageSource\|comprehension), đổi cao độ\|listening_passage_source.dart\|\[x\] Nghe hiểu\|Hiện tại: \*\*" README.md
```

Expected: one match for each pattern (the feature-section pattern may differ slightly — adjust the grep to whatever exact phrase you used in Step 2 if it doesn't match verbatim), confirming all edits are present and none were accidentally duplicated.

- [ ] **Step 8: Read the diffed sections once, end to end**

```bash
git diff README.md
```

Confirm the diff reads coherently (no leftover "sắp ra mắt" language, no broken markdown list nesting, no duplicated bullet).

- [ ] **Step 9: Sanity-check the repo still analyzes/tests cleanly**

```bash
flutter analyze
flutter test
```

Expected: both succeed (README changes cannot affect these, but this is the last task in the plan — confirm nothing was left broken from earlier tasks).

- [ ] **Step 10: Commit**

```bash
git add README.md
git commit -m "docs: document Nghe hiểu (TOEIC-style comprehension) feature in README"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (final count used in README)
Concerns: (if any)
