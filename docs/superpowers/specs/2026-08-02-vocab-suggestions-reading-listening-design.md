# Gợi ý từ mới sau khi luyện Đọc / Nghe hiểu (kiểu Word Radar)

**Ngày:** 2026-08-02
**Trạng thái:** Đã duyệt thiết kế, chờ viết plan

## Bối cảnh

Word Radar cho phép người dùng dán một đoạn văn bất kỳ, AI trả về danh sách từ mới đáng học (loại trừ các từ đã có trong Vocab Bank), người dùng bấm để lưu từng từ hoặc "Lưu tất cả". Luyện đọc (Reading) và Nghe hiểu (Comprehension) hiện tại kết thúc phiên luyện mà không có bước này — đoạn văn/hội thoại do AI sinh ra chỉ dùng để luyện gõ/nghe rồi bỏ đi, dù nó có thể chứa từ vựng hay mà người dùng chưa lưu.

Yêu cầu: sau khi luyện xong (ở màn kết quả), Reading và Comprehension cũng hiển thị một khối "Gợi ý từ mới" y hệt cơ chế Word Radar — AI trả danh sách từ mới, loại các từ đã có trong bank, người dùng tự quyết định lưu hay không.

Nghe hiểu **không** cần ưu tiên từ SM-2 khi *sinh* hội thoại (khác với Reading/Dictation) — hội thoại vẫn được tạo tự do theo level/context như hiện tại. Việc gợi ý từ mới ở cuối là tính năng độc lập, không liên quan đến việc chọn từ đầu vào.

## Mục tiêu

- Thêm khối "Gợi ý từ mới" vào `ReadingResultScreen` và `ComprehensionResultScreen`, tái dùng đúng cơ chế AI + dedup + save mà Word Radar đang dùng.
- Không đổi cách Reading/Dictation/Comprehension sinh nội dung luyện tập (ngoài phạm vi).
- Giảm trùng lặp code: gộp logic "tìm từ đã biết trong text → gọi AI gợi ý loại trừ chúng" thành 1 use case dùng chung; tách phần UI card gợi ý (lưu/bỏ qua/lưu tất cả) thành widget dùng chung cho cả 3 màn hình (Word Radar, Reading result, Comprehension result).

## Kiến trúc

### 1. Use case mới — `GetVocabSuggestionsForTextUseCase`

**File mới:** `lib/features/word_radar/domain/use_cases/get_vocab_suggestions_for_text_use_case.dart`

Gộp 2 bước hiện đang lặp lại trong `WordRadarNotifier.scan()`/`retrySuggestions()`:

```dart
class GetVocabSuggestionsForTextUseCase {
  const GetVocabSuggestionsForTextUseCase(this._findKnown, this._generate);
  final FindKnownHeadwordsUseCase _findKnown;
  final GenerateWordSuggestionsUseCase _generate;

  Future<WordRadarAiResult> execute({
    required String text,
    required Language targetLanguage,
    required CEFRLevel? targetCefrLevel,
  }) async {
    final known = await _findKnown.execute(text: text, language: targetLanguage);
    return _generate.execute(
      text: text,
      targetLanguage: targetLanguage,
      targetCefrLevel: targetCefrLevel,
      knownHeadwords: known.map((r) => r.headword).toList(),
    );
  }
}
```

Đăng ký provider `getVocabSuggestionsForTextUseCaseProvider` trong `app_providers.dart`, dựng từ `findKnownHeadwordsUseCaseProvider` + `generateWordSuggestionsUseCaseProvider` đã có sẵn.

`WordRadarNotifier` **không đổi** — nó vẫn cần `knownRecords` riêng (để highlight từ đã biết trong text gốc), nên giữ nguyên 2 lệnh gọi tách biệt như hiện tại thay vì ép dùng use case gộp này (tránh refactor không cần thiết vào code đang chạy tốt và có test).

### 2. Widget dùng chung — `VocabSuggestionsSection`

**File mới:** `lib/features/word_radar/presentation/widgets/vocab_suggestions_section.dart`

Tách phần thân của `_WordRadarScreenState._buildAiResult()` (đoạn từ "Gợi ý từ mới" Row trở xuống — nút Lưu tất cả, danh sách Card, nút bỏ qua/đã lưu) thành 1 `ConsumerStatefulWidget` độc lập, tự quản lý state `_savedHeadwords`/`_dismissedHeadwords` và các hàm `_openSaveSheet`/`_saveAll` (chuyển nguyên logic hiện có, không đổi hành vi):

```dart
class VocabSuggestionsSection extends ConsumerStatefulWidget {
  const VocabSuggestionsSection({super.key, required this.suggestions});
  final List<WordPhraseResult> suggestions;
}
```

`WordRadarScreen._buildAiResult()` sau khi tách chỉ còn render phần "Bản dịch" + `_HighlightedText`, rồi gọi `VocabSuggestionsSection(suggestions: result.suggestions)` — hành vi UI giữ nguyên 100%, chỉ khác vị trí code.

### 3. `ReadingResultScreen`

Thêm state cục bộ trong `_ReadingResultScreenState`:

```dart
AsyncValue<WordRadarAiResult>? _suggestions; // null = đang tải lần đầu
```

Trong `initState`, song song với `_recordPracticeSession()`, gọi thêm `_loadSuggestions()`:

```dart
Future<void> _loadSuggestions() async {
  setState(() => _suggestions = const AsyncLoading());
  final settings = ref.read(userSettingsNotifierProvider);
  final aiResult = await AsyncValue.guard(
    () => ref.read(getVocabSuggestionsForTextUseCaseProvider).execute(
          text: result.passage.fullText,
          targetLanguage: result.passage.targetLanguage,
          targetCefrLevel: result.passage.level,
        ),
  );
  if (mounted) setState(() => _suggestions = aiResult);
}
```

UI: thêm section "Gợi ý từ mới" bên dưới danh sách "Từ vựng đã luyện" hiện có, dùng `_suggestions!.when(...)`:
- `loading`: `CircularProgressIndicator`.
- `error`: thông báo lỗi + nút "Thử lại" gọi lại `_loadSuggestions()`.
- `data: (r)`: render `VocabSuggestionsSection(suggestions: r.suggestions)`.

### 4. `ComprehensionResultScreen`

Chuyển từ `ConsumerWidget` (đã có kế hoạch chuyển sang `ConsumerStatefulWidget` ở bước streak trước đó — giờ tận dụng luôn state đó) sang thêm cùng cơ chế:

```dart
String get _transcriptText =>
    result.passage.turns.map((t) => t.text).join(' ');
```

Gọi `_loadSuggestions()` y hệt Reading, chỉ khác `text: _transcriptText` thay vì `passage.fullText`. Section "Gợi ý từ mới" hiển thị bên dưới phần "Bản ghi âm" hiện có.

## Kiểm thử

- **`GetVocabSuggestionsForTextUseCase`**: unit test — gọi `_findKnown` trước, truyền đúng `knownHeadwords` (map từ kết quả `_findKnown`) vào `_generate`; trả đúng `WordRadarAiResult` từ `_generate`.
- **`VocabSuggestionsSection`**: test hiện có trong `word_radar_screen_test.dart` (tap-to-save, dismiss, save-all) giữ nguyên chỗ cũ — chúng test hành vi qua `WordRadarScreen`, vẫn đúng vì widget con chỉ đổi vị trí code, không đổi cây widget nhìn từ bên ngoài. Thêm 1 file test mới `vocab_suggestions_section_test.dart` test riêng widget này (không qua `WordRadarScreen`) để 2 màn Reading/Comprehension result cũng được bảo vệ bởi cùng bộ test khi chúng dùng lại widget.
- **`ReadingResultScreen`**: widget test — mock `getVocabSuggestionsForTextUseCaseProvider`, xác nhận gọi với `text = passage.fullText`; xác nhận section "Gợi ý từ mới" hiện loading rồi data; xác nhận không crash khi use case throw.
- **`ComprehensionResultScreen`**: tương tự, xác nhận `text` truyền vào là transcript nối từ `turns`.
- **`WordRadarScreen`**: các test hiện có (tap-to-save, dismiss, save-all) phải tiếp tục pass sau khi tách `VocabSuggestionsSection` — hành vi không đổi, chỉ đổi vị trí code.

## Ngoài phạm vi

- Không đổi cách chọn từ vựng đầu vào cho Reading/Dictation (đã ưu tiên SM-2 due sẵn, không đổi).
- Không thêm ưu tiên SM-2 cho Comprehension — hội thoại vẫn sinh tự do theo level/context như hiện tại.
- Không thêm nút "Thử lại toàn bộ" cấp phiên (regenerate) nào mới ngoài nút Thử lại của riêng section gợi ý khi nó lỗi.
- Không đổi `recordPracticeSession`/`_updateSm2` đã thêm ở các bước trước.
