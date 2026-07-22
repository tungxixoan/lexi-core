# Thanh tua âm thanh cho Nghe chép & Nghe hiểu

**Ngày:** 2026-07-22
**Trạng thái:** Đã duyệt, chờ viết plan

## Bối cảnh

Cả hai tính năng "Nghe chép" (Dictation, Plan 9) và "Nghe hiểu" (Comprehension, Plan 10) hiện chỉ hỗ trợ phát/dừng và (với Nghe hiểu) chuyển lượt trước/sau/phát lại từ đầu — không có cách nào để tua tới một điểm cụ thể trong câu/lượt thoại đang nghe. Việc thêm một thanh tua (slider) đã được người dùng chủ động đề xuất từ trước và hoãn lại đến bây giờ mới triển khai.

**Ràng buộc kỹ thuật quan trọng:** cả hai tính năng dùng `TtsService` (bọc `flutter_tts`) — phát trực tiếp bằng engine giọng nói on-device, **không phải phát một file âm thanh có sẵn**. Vì vậy không thể "tua" theo đúng nghĩa kéo tới một mốc thời gian bất kỳ trong file audio (không có mốc thời gian nào để tua tới — TTS engine không hỗ trợ seek-by-time). Do đó cơ chế thực sự khả thi là **tua theo vị trí từ**: kéo tới đâu thì dừng phát hiện tại (nếu có) và phát lại **từ đúng từ đó cho đến hết câu/lượt thoại**, tận dụng nguyên `TtsService.speak()` hiện có — không cần audio player mới, không phát sinh chi phí AI/API.

## Mục tiêu

- Cho phép người dùng tua tới một vị trí từ cụ thể trong câu (Nghe chép) hoặc trong toàn bộ bài (Nghe hiểu, xuyên suốt nhiều lượt thoại) để nghe lại một đoạn thay vì luôn phải nghe lại từ đầu.
- Với Nghe chép: bổ sung cơ chế chống gian lận để việc tua không trở thành cách "nghe lại miễn phí/rẻ" thay thế nút Nghe lại hiện có (vốn trừ 5%/lần).
- Với Nghe hiểu: giữ đúng tinh thần thiết kế đã duyệt trước đó — tua hoàn toàn miễn phí, không ảnh hưởng điểm/SM-2 (đối lập có chủ đích với Nghe chép).
- Không cần audio player mới, không thêm chi phí API, không đổi kiến trúc TTS hiện tại.

## Cơ chế tua (dùng chung cho cả 2 tính năng)

- **Không có audio file** → không có "vị trí thời gian" để tua. Slider ánh xạ theo **vị trí từ** trong văn bản (chia câu/lượt thoại thành danh sách từ bằng `RegExp(r'\s+')`, giống cách các nơi khác trong codebase đã làm — vd `dictation_practice_provider.dart`, `dictation_result_screen.dart`).
- **Không có live progress**: slider đứng yên trong lúc TTS đang đọc — không tự động trượt theo từ đang đọc (tránh phụ thuộc vào `flutter_tts`'s progress/word-boundary callback, vốn không ổn định đồng nhất giữa web và mobile).
- **Tương tác**: kéo (chưa thả tay) chỉ cập nhật một nhãn xem trước cục bộ (widget state, chưa chạm vào provider) dạng "Từ X/Y" (Nghe chép) hoặc "Lượt A/B · Từ X/Y" (Nghe hiểu). **Thả tay** mới thực sự: dừng phát hiện tại (nếu có), phát từ vị trí từ đó cho tới hết câu/lượt, và cập nhật vị trí slider "nghỉ" tại đúng điểm vừa thả (không tự bật về 0 sau khi phát xong).
- Chia mức slider: `divisions = tổng số từ - 1` (Nghe chép: số từ trong câu; Nghe hiểu: tổng số từ toàn bài, gộp mọi lượt).
- Vị trí đặt trong UI: slider nằm **phía trên** các nút điều khiển phát (nút Phát/Nghe lại của Nghe chép; hàng nút ⏮/▶⏸/⏭/🔁 của Nghe hiểu).

## Nghe chép (Dictation) — có ảnh hưởng điểm số

### Quy tắc trừ điểm khi tua

TTS luôn phát từ vị trí bắt đầu cho đến hết câu (không dừng giữa chừng), nên "kéo về gần đầu câu" nghĩa là nghe lại gần như toàn bộ câu, còn "kéo về gần cuối câu" chỉ nghe lại vài từ cuối. Mức phạt vì vậy dựa trên **số từ sẽ được nghe lại kể từ điểm tua đến hết câu**, không cần theo dõi "vị trí đã nghe trước đó":

- `wordsReheard` = tổng số từ − vị trí từ đích (số từ từ điểm tua cho đến hết câu).
- `reheardRatio` = `wordsReheard / tổng số từ` (0 đến 1).
- Nếu `reheardRatio` ≤ 20%: trừ **1%** — kéo gần cuối câu, nghe lại vài từ, coi là bình thường.
- Nếu `reheardRatio` > 20%: trừ tăng tuyến tính từ **1% → 5%** khi `reheardRatio` tăng từ 20% → 100% — càng kéo về gần đầu câu (nghe lại càng nhiều) càng phạt nặng, chặn việc dùng tua để "nghe lại gần hết câu" với giá rẻ hơn nút Nghe lại.
  - Công thức: `penalty = 1 + 4 × (reheardRatio − 0.2) / 0.8`, kẹp trong khoảng [1, 5].
- Mỗi lần **thả tay** tính là 1 lần tua (không tính số lần kéo qua kéo lại trước khi thả).
- Lần nghe **đầu tiên** của cả phiên luôn miễn phí, bất kể là bấm nút Phát hay kéo slider trước — giữ đúng ý nghĩa cờ `hasPlayedOnce` hiện có.
- Nút "Nghe lại" (phát lại từ đầu câu) **giữ nguyên như cũ**: mỗi lần bấm trừ cố định 5%, tính vào `replayCount` hiện có — không đổi, không gộp chung với cơ chế tua.

### Thay đổi dữ liệu/điểm số

- `DictationSessionState`/`DictationSessionResult` (`dictation_practice_provider.dart`) thêm trường mới `seekPenaltyTotal` (double, tổng % đã bị trừ do tua trong phiên, cộng dồn mỗi lần thả tay).
- Công thức điểm mới:
  `finalScore = (rawAccuracy − 0.05 × replayCount − seekPenaltyTotal).clamp(0.0, 1.0)`
  (giữ nguyên `rawAccuracy` theo `difficulty` như hiện có — không đổi phần chấm điểm ký tự/ô trống).
- `DictationPracticeNotifier` thêm phương thức mới, ví dụ `seekTo(int wordIndex)`: tính `wordsReheard`/`reheardRatio`/`penalty` theo công thức trên, cộng vào `seekPenaltyTotal` (bỏ qua nếu đây là lần nghe đầu tiên — set `hasPlayedOnce = true` thay vì cộng phạt), dừng TTS nếu đang phát, gọi `TtsService.speak()` với chuỗi con từ `wordIndex` trở đi.

### Thay đổi UI

- `DictationSessionScreen`: thêm `Slider` phía trên nút Phát/Nghe lại, hiển thị nhãn "Từ X/Y" khi đang kéo.
- `DictationResultScreen`: thêm dòng hiển thị "Số lần tua: N (−X%)" bên cạnh dòng "Nghe lại: N" hiện có, để minh bạch điểm bị trừ từ đâu (N = số lần tua đã thực hiện trong phiên, X% = `seekPenaltyTotal` tính theo %).

## Nghe hiểu (Comprehension) — không ảnh hưởng điểm số

- Slider duy nhất trải dài **xuyên suốt toàn bộ bài** (nối tất cả lượt thoại lại theo thứ tự), không tách slider riêng cho từng lượt.
- Cần một hàm ánh xạ vị trí từ toàn cục (global word index) sang (chỉ số lượt, vị trí từ trong lượt đó) — dựa trên tổng số từ tích lũy qua các lượt trước đó.
- Khi thả tay: xác định lượt đích, cập nhật `currentTurnIndex` nếu khác lượt hiện tại, phát từ vị trí từ trong lượt đó cho đến hết lượt, với đúng `pitch` theo `speaker` của lượt đó (giữ nguyên logic `_pitchFor` hiện có: B=1.3, còn lại=1.0).
- `ListeningComprehensionNotifier` thêm phương thức mới, ví dụ `seekToWord(int globalWordIndex)`.
- **Giữ nguyên hoàn toàn** các nút ⏮/▶⏸/⏭/🔁 hiện có — slider chỉ là cách tua bổ sung, không thay thế điều hướng theo lượt.
- **Miễn phí hoàn toàn** — không có trường điểm/phạt nào liên quan đến tua ở tính năng này, không đổi `ComprehensionSessionResult`, không chạm SM-2 (giữ đúng bất biến "Nghe hiểu không ảnh hưởng SM-2" đã xác lập từ Plan 10).

## Kiểm thử

- Unit test cho công thức `reheardRatio`/`penalty` của Nghe chép (biên: ratio=0%, =20% (đúng ngưỡng), =50%, =100%; kiểm tra kẹp trong [1,5]).
- Unit test `DictationSessionResult.finalScore` với `seekPenaltyTotal` khác 0, đảm bảo không phá vỡ các test hiện có về `replayCount`.
- Widget test cho slider ở cả hai màn hình phiên luyện tập: kéo + thả kích hoạt đúng phương thức notifier với vị trí từ đúng; nhãn preview hiển thị đúng khi đang kéo; vị trí slider giữ nguyên sau khi thả (không tự reset).
- Test ánh xạ global-word-index → (lượt, vị trí từ trong lượt) của Nghe hiểu với các trường hợp: vị trí ở lượt đầu, lượt giữa, lượt cuối, đúng ranh giới giữa 2 lượt.
- Test `DictationResultScreen` hiển thị đúng dòng "Số lần tua" khi có ít nhất 1 lần tua, và không hiển thị/hiển thị 0 khi không tua lần nào.

## Ngoài phạm vi

- Không thêm live progress bar (thanh tự chạy theo tiến độ đọc).
- Không chuyển sang audio file thật / audio player mới.
- Không đổi cơ chế chấm điểm ký tự (`charAccuracy`)/ô trống (`blockAccuracy`) hiện có — chỉ cộng thêm số hạng trừ điểm do tua.
