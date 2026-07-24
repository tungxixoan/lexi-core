# Điều chỉnh tốc độ đọc (0.75x/1x/1.25x) cho Nghe chép & Nghe hiểu

**Ngày:** 2026-07-25
**Trạng thái:** Đã duyệt, chờ viết plan

## Bối cảnh

Cả "Nghe chép" (Dictation) và "Nghe hiểu" (Comprehension) hiện chỉ đọc bằng TTS ở tốc độ mặc định của máy — không có cách nào để người dùng chọn đọc chậm hơn/nhanh hơn. Đây là tính năng đã được đề cập trong spec ban đầu của Nghe hiểu (`docs/superpowers/specs/2026-07-19-listening-practice-design.md`) nhưng chủ động hoãn lại ("Adjustable TTS speech rate" — ngoài phạm vi v1); yêu cầu này quay lại triển khai nó.

**Ràng buộc kỹ thuật:** `TtsService` (`lib/services/tts_service.dart`) bọc `flutter_tts`, hiện chỉ có tham số `pitch`, chưa có `rate`. `flutter_tts` có sẵn `setSpeechRate(double rate)` trên thang đo chuẩn hóa **0.0 (chậm nhất) — 1.0 (nhanh nhất)**, không phải hệ số nhân thông thường. App hiện chưa bao giờ gọi `setSpeechRate` ở bất kỳ đâu (dùng tốc độ mặc định của máy/engine).

## Mục tiêu

- Thêm hàng 3 nút chọn tốc độ (0.75x / 1x / 1.25x) cho cả Nghe chép và Nghe hiểu.
- Tốc độ chỉ tồn tại trong phạm vi phiên hiện tại (không lưu lại giữa các phiên) — mỗi phiên mới luôn bắt đầu ở 1x.
- Đổi tốc độ giữa lúc TTS đang đọc dở: dừng và đọc lại ngay từ đầu câu/lượt hiện tại với tốc độ mới (không thể chỉnh tốc độ mượt giữa chừng một câu — giới hạn của bản thân TTS engine, không phải giới hạn của flutter_tts hay code).
- Đổi tốc độ lúc đang rảnh (không có gì đang phát): chỉ lưu lựa chọn, không đọc gì, hoàn toàn miễn phí, có hiệu lực từ lần bấm Phát/Nghe lại tiếp theo.
- **Nghe chép:** không thêm công thức phạt điểm riêng cho việc chọn tốc độ chậm hơn. Nhưng vì đổi tốc độ giữa lúc đang phát về bản chất là một lần "nghe lại", nó phải tính vào `replayCount` hiện có y hệt bấm nút "Nghe lại" — nếu không, người dùng có thể bấm tốc độ liên tục (0.75x→1x→0.75x...) để nghe lại miễn phí không giới hạn, lách hết cơ chế trừ 5%/lần Nghe lại đang có.
- **Nghe hiểu:** tốc độ hoàn toàn miễn phí trong mọi trường hợp — đúng bất biến đã xác lập từ Plan 10 rằng Nghe hiểu không bao giờ ảnh hưởng điểm/SM-2.

## 1. `TtsService` — thêm tham số `rate`

**File:** `lib/services/tts_service.dart`

```dart
abstract class TtsService {
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate});
  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  // ...
  @override
  Future<void> speak(String text, Language language, {double pitch = 1.0, double? rate}) async {
    await _tts.setLanguage(language.ttsLocale);
    await _tts.setPitch(pitch);
    if (rate != null) await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }
  // ...
}
```

`rate` là **nullable**, không có giá trị mặc định luôn-set — chỉ gọi `setSpeechRate` khi được truyền tường minh. Các nơi gọi `speak()` khác trong app (`vocab_detail_screen.dart`, `word_result_widget.dart`, `sentence_result_widget.dart`) không truyền `rate`, nên hoàn toàn không bị ảnh hưởng, vẫn dùng tốc độ mặc định của engine như hiện tại.

**Quy đổi tốc độ:** base rate cho "1x" = `0.5` (mức phổ biến theo tài liệu flutter_tts). `_rateFor(multiplier) = (0.5 * multiplier).clamp(0.0, 1.0)` → 0.75x = 0.375, 1x = 0.5, 1.25x = 0.625. Hàm này là một private helper nhỏ, khai báo riêng (trùng lặp 1 dòng) trong mỗi provider dùng đến — không cần tạo module dùng chung mới.

## 2. Nghe chép (Dictation) — có ảnh hưởng `replayCount` khi đang phát

**File:** `lib/features/listening/presentation/providers/dictation_practice_provider.dart`

- `DictationSessionState` thêm 2 field mới:
  - `speedMultiplier` (double, mặc định `1.0`).
  - `isSpeaking` (bool, mặc định `false`) — **field hoàn toàn mới**, file này hiện chưa track trạng thái đang phát/không (khác với Nghe hiểu đã có sẵn `isSpeaking`/`playToken`).
  - Cả 2 thêm vào `copyWith`.
- `play()`: đặt `isSpeaking: true` trong cùng lần `copyWith` với logic `hasPlayedOnce`/`replayCount` hiện có (trước khi `await speak()`), đặt lại `isSpeaking: false` sau khi `speak()` hoàn tất. Truyền thêm `rate: _rateFor(current.speedMultiplier)` vào lệnh gọi `speak()`.
- `seekTo()`: bọc `isSpeaking` tương tự quanh đoạn `stop()`+`speak()` hiện có, cũng truyền `rate`.
- Thêm phương thức mới `setSpeed(double multiplier)`:
  ```dart
  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isComplete) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(
      speedMultiplier: multiplier,
      replayCount: current.replayCount + 1,
      isSpeaking: true,
    ));
    await ref.read(ttsServiceProvider).speak(
          current.item.target,
          current.item.targetLanguage,
          rate: _rateFor(multiplier),
        );
    final latest = state.valueOrNull;
    if (latest == null) return;
    state = AsyncData(latest.copyWith(isSpeaking: false));
  }
  ```
  Lưu ý: `isSpeaking == true` chỉ xảy ra sau khi `hasPlayedOnce` đã được đặt `true` (vì cả hai được set cùng lúc trong `play()`/`seekTo()`), nên nhánh "đang phát" của `setSpeed()` luôn được phép tăng thẳng `replayCount` mà không cần kiểm tra `hasPlayedOnce` riêng.
- `DictationSessionState`/`DictationSessionResult`'s `finalScore` **không đổi công thức** — `replayCount` đã có sẵn trong công thức (`- 0.05 * replayCount`), nên việc đổi tốc độ giữa lúc phát tự động bị trừ điểm y hệt Nghe lại, không cần cộng thêm số hạng mới.

## 3. Nghe hiểu (Comprehension) — luôn miễn phí

**File:** `lib/features/listening/presentation/providers/listening_comprehension_provider.dart`

- `ListeningSessionState` thêm `speedMultiplier` (double, mặc định `1.0`) + vào `copyWith`. (`isSpeaking`/`playToken` đã có sẵn, không cần thêm.)
- `playCurrentTurn()`/`seekToWord()`: truyền thêm `rate: _rateFor(current.speedMultiplier)` (đọc từ `current`/`latest` tùy vị trí, nhất quán với cách các tham số khác đang được đọc trong 2 hàm này) vào lệnh gọi `speak()`.
- Thêm phương thức mới `setSpeed(double multiplier)`:
  ```dart
  Future<void> setSpeed(double multiplier) async {
    final current = state.valueOrNull;
    if (current == null || current.isSubmitted) return;
    if (!current.isSpeaking) {
      state = AsyncData(current.copyWith(speedMultiplier: multiplier));
      return;
    }
    await ref.read(ttsServiceProvider).stop();
    state = AsyncData(current.copyWith(speedMultiplier: multiplier));
    await playCurrentTurn();
  }
  ```
  Gọi lại `playCurrentTurn()` (đã có sẵn cơ chế `playToken` tự tăng + auto-continue từ tính năng vừa làm trước đó) khiến lượt hiện tại được đọc lại từ đầu với tốc độ mới, và **vẫn tự động tiếp tục sang lượt sau** khi đọc xong — không cần thêm logic auto-continue riêng cho trường hợp này. Không đụng đến `ComprehensionSessionResult`/SM-2 — giữ đúng bất biến "Nghe hiểu miễn phí hoàn toàn".

## 4. UI

Mỗi màn hình có một widget private `_SpeedSelector` riêng (không dùng chung 1 file — theo đúng tiền lệ đã có của `_SeekSlider` bị trùng lặp có chủ đích giữa 2 màn hình này), dùng `SegmentedButton<double>` (đúng chuẩn Material 3 mà `AppTheme` đang bật `useMaterial3: true`):

```dart
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onChanged});
  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<double>(
      segments: const [
        ButtonSegment(value: 0.75, label: Text('0.75x')),
        ButtonSegment(value: 1.0, label: Text('1x')),
        ButtonSegment(value: 1.25, label: Text('1.25x')),
      ],
      selected: {speed},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}
```

- **`dictation_session_screen.dart`**: đặt `_SpeedSelector` ngay dưới nút Phát/Nghe lại hiện có, trước `SizedBox(height: 32)` dẫn vào phần nhập liệu.
- **`comprehension_session_screen.dart`**: đặt ngay dưới hàng nút ⏮/▶⏸/⏭/🔁 hiện có, vẫn nằm trong cùng `Card`.

## Kiểm thử

- **`TtsService`**: unit test cho `FlutterTtsService.speak()` — `rate` không truyền → `setSpeechRate` không được gọi; `rate` có truyền → `setSpeechRate` được gọi đúng giá trị, `setPitch` vẫn được gọi như cũ.
- **Dictation `setSpeed`**: `setSpeed()` lúc đang rảnh (trước khi bấm Phát lần nào, hoặc sau khi TTS đã đọc xong) — chỉ đổi `speedMultiplier`, không gọi `speak()`/`stop()`, không đổi `replayCount`/`hasPlayedOnce`. `setSpeed()` lúc đang phát (dùng `Completer` giữ `speak()` "đang chạy", cùng kỹ thuật đã dùng để test interruption ở Nghe hiểu) — gọi `stop()`, tăng đúng 1 `replayCount`, gọi lại `speak()` với `rate` mới đúng giá trị quy đổi.
- **Listening `setSpeed`**: tương tự — lúc rảnh chỉ đổi `speedMultiplier` không phát gì; lúc đang phát thì dừng + phát lại lượt hiện tại với `rate` mới, và (unit test riêng) xác nhận auto-continue vẫn hoạt động sau đó (lượt kế tiếp được phát tự động, đúng tính năng vừa hoàn thành ở plan trước).
- **UI**: widget test cho mỗi `_SpeedSelector` — bấm mỗi nút gọi đúng `notifier.setSpeed()` với giá trị tương ứng (0.75/1.0/1.25); nút đang chọn hiển thị đúng trạng thái `selected`.

## Ngoài phạm vi

- Không lưu tốc độ vào Settings/local storage — luôn reset về 1x mỗi phiên mới.
- Không cộng thêm công thức phạt điểm riêng cho việc chọn tốc độ — Nghe chép tận dụng nguyên `replayCount` đã có, Nghe hiểu miễn phí tuyệt đối như từ trước.
- Không hiển thị tốc độ đã dùng ở màn kết quả (`DictationResultScreen`/`ComprehensionResultScreen`) — không có yêu cầu này.
- Không chỉnh tốc độ mượt giữa chừng một câu đang đọc — giới hạn nền tảng của TTS engine, chỉ có thể dừng+đọc lại từ đầu.
