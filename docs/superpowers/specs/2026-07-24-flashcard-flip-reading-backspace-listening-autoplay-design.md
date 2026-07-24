# Lật thẻ hai chiều, trừ điểm backspace khi đọc, tự động đọc tiếp lượt khi nghe hiểu

**Ngày:** 2026-07-24
**Trạng thái:** Đã duyệt, chờ viết plan

## Bối cảnh

Ba vấn đề độc lập được phát hiện/yêu cầu khi rà soát lại các tính năng luyện tập:

1. Trong flashcard của `practice/session`, khi thẻ đã lật sang mặt sau (hiện nghĩa) nhưng người dùng chưa bấm "Đã hiểu"/"Chưa hiểu", hiện không có cách nào lật lại mặt trước để xem lại từ vựng — `_flip()` trong `flashcard_widget.dart` chỉ cho lật một chiều (`if (_revealed) return;`), không có `.reverse()` hay tap handler nào ở mặt sau.
2. Trong luyện đọc (`reading`), màn kết quả chỉ hiển thị 3 chỉ số tách rời (độ chính xác, tốc độ, thời gian) mà không có điểm tổng, và hoàn toàn không theo dõi số lần backspace — người dùng có thể xóa/gõ lại liên tục để "mài" cho khớp câu đích mà không bị trừ điểm gì ngoài việc tốn thêm thời gian (vốn cũng không bị tính vào công thức nào).
3. Trong Nghe hiểu (`listening/comprehension`), `playCurrentTurn()` chỉ đọc đúng một lượt thoại rồi dừng — muốn nghe lượt kế tiếp phải tự bấm nút Phát lại, dù đoạn hội thoại có nhiều lượt liên tiếp.

## Mục tiêu

- Cho phép lật flashcard qua lại tự do giữa 2 mặt trước khi chấm điểm, không ảnh hưởng đến `ExerciseResult`/logic chấm điểm hiện có.
- Thêm điểm tổng (`finalScore`) cho luyện đọc, có trừ điểm theo số lần backspace, theo đúng tinh thần công thức `finalScore` đã có ở dictation (`dictation_practice_provider.dart`) nhưng với mức phạt nhẹ hơn nhiều vì backspace khi gõ là hành vi bình thường.
- Nghe hiểu tự động đọc tiếp lượt kế sau khi lượt hiện tại đọc xong tự nhiên (không bị người dùng chủ động dừng/điều hướng), cho đến lượt cuối cùng thì dừng.

## 1. Lật thẻ hai chiều trong flashcard (practice/session)

**File:** `lib/features/practice/presentation/widgets/flashcard_widget.dart`

- Bỏ flag `_revealed` (chỉ cho lật 1 chiều). Đổi `_flip()` thành `_toggleFlip()`, dựa vào `_flipCtrl.value` để quyết định hướng:
  ```dart
  void _toggleFlip() {
    if (_flipCtrl.isAnimating) return;
    if (_flipCtrl.value == 0) {
      _flipCtrl.forward();
    } else {
      _flipCtrl.reverse();
    }
  }
  ```
  Chặn `isAnimating` để tránh bấm dồn dập giữa lúc animation đang chạy dở (350ms).
- `showingBack` trong `build()` vẫn tính từ `_flipAnim.value` như cũ, không cần thêm state riêng.
- Vùng tap để lật:
  - Mặt trước: giữ nguyên `GestureDetector(onTap: _toggleFlip)` bọc cả `transformed`.
  - Mặt sau: **không** bọc `GestureDetector` quanh toàn thẻ (tránh đúng vấn đề mà comment cũ trong code đã nêu — tap-arena đụng độ với 2 nút bên trong). Thay vào đó, `_BackContent` nhận thêm callback `onTapToFlip`, và tự bọc `GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTapToFlip)` chỉ quanh phần nghĩa + ví dụ (không bao gồm `Row` chứa 2 nút `OutlinedButton`/`FilledButton`).
  - Thêm dòng gợi ý nhỏ dưới phần nghĩa, ví dụ `"Chạm để xem lại từ vựng"` (cùng style hint `"Chạm vào thẻ để xem đáp án"` ở mặt trước), để người dùng biết có thể lật lại.
- Không đổi `_submit`/`ExerciseResult` — lật qua lật lại bao nhiêu lần cũng không ảnh hưởng chấm điểm, chỉ 2 nút mới gọi `onSubmit`.

## 2. Backspace trừ điểm trong luyện đọc (reading)

**File:** `lib/features/reading/presentation/providers/reading_practice_provider.dart`

- `SentenceResult` thêm field `backspaceCount` (int, mặc định đếm trong phạm vi 1 câu).
- `ReadingSessionState`/`ReadingPracticeNotifier` thêm bộ đếm tạm cho câu đang gõ (ví dụ field `currentBackspaceCount` trong state, reset về 0 mỗi khi `_advance` sang câu mới).
- `updateTypedText(String text)`: so sánh `text.length` với `current.typedText.length` trước khi cập nhật state — nếu `text.length < current.typedText.length` (người dùng vừa xóa ký tự), tăng `currentBackspaceCount` thêm 1. Đây là đếm theo **sự kiện xóa** (mỗi lần độ dài giảm tính là 1 lần), không đếm theo số ký tự bị xóa.
- `_advance()`: khi tạo `SentenceResult`, gán `backspaceCount: current.currentBackspaceCount`.
- `ReadingSessionResult` thêm:
  - `totalBackspaceCount` — tổng `backspaceCount` của mọi câu đã hoàn thành.
  - `finalScore` — công thức:
    ```dart
    double get finalScore =>
        (overallAccuracy - 0.01 * totalBackspaceCount).clamp(0.0, 1.0);
    ```
    Mức phạt 1%/lần xóa (nhẹ hơn nhiều so với 5%/lần replay của dictation) vì backspace khi gõ để sửa lỗi chính tả là hành vi bình thường, không nên phạt nặng như nghe lại cả câu.
- `ReadingResultScreen`: thêm `_StatCard` thứ 4 "Điểm" hiển thị `finalScore` dạng phần trăm, đặt cạnh 3 thẻ hiện có (độ chính xác/tốc độ/thời gian) — không đổi 3 thẻ cũ.

## 3. Tự động đọc tiếp lượt trong Nghe hiểu (listening/comprehension)

**File:** `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`

- Trong `playCurrentTurn()`, sau đoạn:
  ```dart
  final latest = state.valueOrNull;
  if (latest == null || latest.playToken != token) return; // superseded meanwhile
  state = AsyncData(latest.copyWith(isSpeaking: false));
  ```
  bổ sung: nếu `latest.currentTurnIndex < latest.passage.turns.length - 1` (chưa phải lượt cuối), thay vì chỉ set `isSpeaking: false`, cập nhật `currentTurnIndex + 1` rồi gọi lại `playCurrentTurn()` để đọc tiếp lượt kế; nếu đã là lượt cuối, giữ nguyên hành vi cũ (set `isSpeaking: false`, dừng).
- Điều kiện `latest.playToken == token` (không bị supersede) đã có sẵn chính là điều kiện "đọc xong tự nhiên, không bị người dùng chủ động dừng/điều hướng/tua giữa chừng" — nên khi người dùng bấm Stop, Next, Previous, Replay hoặc kéo thanh tua giữa lúc đang đọc, `playToken` đổi và chuỗi tự động đọc tiếp sẽ dừng lại đúng như thiết kế, không cần thêm cờ mới.
- Không đổi các nút ⏮/⏭/🔁/thanh tua hiện có — auto-continue chỉ áp dụng cho luồng phát qua nút Play/`playCurrentTurn()`.
- `seekToWord()` giữ nguyên như cũ (chỉ phát hết lượt hiện tại rồi dừng, không tự chuyển lượt) — nằm ngoài phạm vi thay đổi này.

## Kiểm thử

- **Flashcard:** widget test — tap mặt trước để lật ra sau; tap vùng nghĩa (không phải nút) để lật lại mặt trước; tap lại lần nữa để lật ra sau; xác nhận 2 nút Đã hiểu/Chưa hiểu vẫn gọi đúng `onResult` với `quality`/`isCorrect` tương ứng bất kể đã lật qua lại bao nhiêu lần trước đó; xác nhận tap liên tục trong lúc đang animate không làm rối trạng thái.
- **Reading backspace:** unit test cho `updateTypedText` — gõ thêm ký tự không tăng `backspaceCount`; xóa ký tự tăng đúng 1; xóa nhiều lần liên tiếp tăng đúng số lần; `backspaceCount` reset về 0 khi sang câu mới. Unit test `finalScore` với `totalBackspaceCount` = 0 (bằng `overallAccuracy`), khác 0 (trừ đúng 1%/lần), và trường hợp trừ tới mức âm phải bị `clamp` về 0.
- **Listening auto-continue:** test notifier — sau khi `playCurrentTurn()` hoàn tất tự nhiên ở lượt chưa phải cuối, `currentTurnIndex` tự tăng và TTS được gọi lại cho lượt kế; ở lượt cuối thì dừng, `isSpeaking` = false, `currentTurnIndex` không đổi; giả lập người dùng gọi `stopPlayback()`/`nextTurn()`/`previousTurn()` giữa lúc đang đọc thì chuỗi tự động không tiếp tục (không có lệnh `speak` phát sinh thêm sau khi bị supersede).

## Ngoài phạm vi

- Không thêm cơ chế trừ điểm/theo dõi số lần lật thẻ ở flashcard — lật bao nhiêu lần cũng miễn phí, chỉ chấm khi bấm 2 nút.
- Không đổi cơ chế tua (`seekToWord`) hay công thức `wpm`/thời gian hiện có của reading — chỉ cộng thêm số hạng trừ điểm do backspace vào `finalScore` mới.
- Không thêm toggle "đọc liên tục" cho Nghe hiểu — auto-continue là hành vi mặc định mới, không có công tắc bật/tắt.
- Không áp dụng auto-continue cho `seekToWord()` — tua chỉ đọc hết lượt hiện tại rồi dừng như cũ.
