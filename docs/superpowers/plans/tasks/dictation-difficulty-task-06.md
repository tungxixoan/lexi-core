# Nghe chép Difficulty Levels — Task 06: Update README

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 01–05 complete (feature fully implemented and tested)

## Global Constraints
(see `dictation-difficulty-global-constraints.md`)

## What This Task Delivers
Documents the 3 difficulty levels in `README.md`'s existing "Nghe chép (dictation)" bullet, and updates the test count. Documentation-only — no application code changes, no automated tests.

## Files
- Modify: `README.md`

## Steps

- [ ] **Step 1: Confirm the final test count**

```bash
flutter test 2>&1 | tail -5
```

This repo's test count was **182** before this feature; expect roughly **+40 to +55** new tests from Tasks 01–05 (dictation_difficulty: 1, blank_span: 1, select_dictation_blanks_use_case: ~7 including seed loops each counting as one test, provider blank-scoring: 6, provider difficulty/blanks: 4, home screen: 2, session screen: 3, result screen: 3) — use the **actual** printed number, not this estimate.

- [ ] **Step 2: Update the Nghe chép bullet**

Find this exact block:

```markdown
- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2)
  - Màn hình kết quả: điểm số, số lần nghe lại, thời gian, phần gõ được tô màu đối chiếu với câu đúng
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
  - Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt), hiển thị dựa theo bề rộng màn hình (không dùng `kIsWeb`)
```

Replace it with:

```markdown
- **Nghe chép (dictation)** — AI tạo một câu vừa-dài dùng ~2 từ từ Vocab Bank; nghe (không tự phát, phải bấm) rồi gõ lại chính xác
  - **3 mức độ** (chọn mỗi phiên luyện tập, mặc định Khó):
    - **Dễ** — điền 2 ô trống 1-từ rời rạc, phần còn lại của câu hiện sẵn (dạng điền khuyết)
    - **Trung bình** — điền 1 cụm từ liên tục (~35% số từ của câu), phần còn lại hiện sẵn
    - **Khó** — chép lại toàn bộ câu từ trí nhớ, không hiện gì (mù hoàn toàn)
  - Nghe lại không giới hạn số lần, nhưng mỗi lần nghe lại trừ 5% điểm — áp dụng cho cả 3 mức độ
  - Chấm điểm cập nhật **SM-2** cho các từ vựng xuất hiện trong câu — khác với Luyện đọc & gõ (không ảnh hưởng SM-2). Dễ/Trung bình chấm theo số ô điền đúng (không phân biệt hoa/thường); Khó chấm theo từng ký tự — cùng công thức trừ điểm và cùng ngưỡng quy đổi SM-2
  - Màn hình kết quả: điểm số, số lần nghe lại, thời gian; Khó hiện phần gõ tô màu đối chiếu ký tự, Dễ/Trung bình hiện lại đúng đoạn điền khuyết với từng ô tô xanh (đúng)/đỏ kèm đáp án đúng (sai)
  - Lọc theo Ngôn ngữ / Chủ đề (Topic tag) / Cấp độ, tối thiểu 2 từ khớp bộ lọc
  - Có thể ẩn/hiện trên mobile (mặc định ẩn, bật trong Cài đặt), hiển thị dựa theo bề rộng màn hình (không dùng `kIsWeb`)
```

- [ ] **Step 3: Update the test count**

Find this exact line:

```markdown
Hiện tại: **182 tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

Replace `182` with the actual number from Step 1's `flutter test` output:

```markdown
Hiện tại: **<ACTUAL_COUNT> tests** — domain entities, use cases, sources, providers, UI widgets, services.
```

- [ ] **Step 4: Verify the edits landed correctly**

```bash
grep -n "3 mức độ\|Trung bình.*35%\|Hiện tại: \*\*" README.md
```

Expected: matches for the new difficulty bullet list and the updated test count.

- [ ] **Step 5: Read the diff once, end to end**

```bash
git diff README.md
```

Confirm it reads coherently — no broken list nesting, no duplicated bullets.

- [ ] **Step 6: Sanity-check the repo still analyzes/tests cleanly**

```bash
flutter analyze
flutter test
```

Expected: both succeed.

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: document Nghe chép difficulty levels (Dễ/Trung bình/Khó)"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output (final count used in README)
Concerns: (if any)
