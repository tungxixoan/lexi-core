# Plan 5 — Task 07: SessionResultScreen Hook + PracticeHomeScreen "Ôn hôm nay" Button

**Context:** Task 07 of Plan 5. Tasks 01–06 must be complete. See `plan5-global-constraints.md` for project-wide rules.

**Files:**
- Modify: `lib/features/practice/presentation/screens/session_result_screen.dart`
- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`

**Interfaces:**
- Consumes:
  - `statsServiceProvider` (Task 04) — calls `recordPracticeSession(int wordCount)`
  - `notificationNotifierProvider` (Task 06) — calls `reschedule()`
  - `getVocabListUseCaseProvider` with `dueOnly: true` (Task 03)
- Produces:
  - After every session: streak + weekly log updated, notifications rescheduled
  - PracticeHomeScreen has "Ôn hôm nay" `OutlinedButton` that launches a due-only session

**Current SessionResultScreen:** `_updateSm2()` runs SM-2 updates in a for-loop with try/catch. After the for-loop, add stats recording + notification reschedule, also wrapped in try/catch.

**PracticeHomeScreen "Ôn hôm nay" button:**
- Loads `dueCount` in `initState` via `addPostFrameCallback`
- `OutlinedButton` is disabled (null `onPressed`) when `dueCount == 0`
- Label: "Hôm nay đã ôn xong ✓" when 0, "Ôn hôm nay (N từ)" when > 0
- Button appears above the `Spacer` + main `FilledButton`
- On tap: load due words, shuffle, push `/practice/session` with `SessionConfig`
- If no due words found at tap time: show a SnackBar "Không có từ nào cần ôn hôm nay."

---

- [ ] **Step 1: Update SessionResultScreen**

In `lib/features/practice/presentation/screens/session_result_screen.dart`, add import:

```dart
import '../providers/notification_notifier.dart';
```

Update `_updateSm2()` — add stats + notification calls after the for-loop:

```dart
  Future<void> _updateSm2() async {
    final computeUseCase = ref.read(computeSm2UseCaseProvider);
    final updateUseCase = ref.read(updateVocabUseCaseProvider);

    for (final result in widget.result.results) {
      try {
        final word = widget.result.words.firstWhere(
          (w) => w.id == result.vocabRecordId,
        );
        final updated = computeUseCase.compute(word, result.quality);
        await updateUseCase.execute(updated);
      } catch (_) {
        // best-effort: don't crash result screen on SM-2 update failure
      }
    }

    try {
      await ref
          .read(statsServiceProvider)
          .recordPracticeSession(widget.result.totalCount);
      await ref.read(notificationNotifierProvider.notifier).reschedule();
    } catch (_) {
      // best-effort: don't crash on stats/notification failure
    }
  }
```

- [ ] **Step 2: Run flutter analyze**

```
flutter analyze lib/features/practice/presentation/screens/session_result_screen.dart
```

Expected: no errors.

- [ ] **Step 3: Update PracticeHomeScreen**

In `lib/features/practice/presentation/screens/practice_home_screen.dart`:

**3a.** Add import for VocabRecord (if not already present):
```dart
import '../../../../features/vocabulary/domain/entities/vocab_record.dart';
```

**3b.** Add `_dueCount` field in `_PracticeHomeScreenState`:
```dart
  int _dueCount = 0;
```

**3c.** Update `initState` to also read due count. Find the existing `addPostFrameCallback` in `initState` and replace `initState` with a version that reads `dueCount` too:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      final stats = ref.read(statsServiceProvider).computeStats();
      setState(() {
        _maxCefrLevel = settings.targetCefrLevel;
        _dueCount = stats.dueCount;
      });
    });
  }
```

**3d.** Add `_startDueSession` method:
```dart
  Future<void> _startDueSession() async {
    final words = await ref
        .read(getVocabListUseCaseProvider)
        .execute(dueOnly: true);
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào cần ôn hôm nay.')),
        );
      }
      return;
    }
    final shuffled = List<VocabRecord>.from(words)..shuffle();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: shuffled));
    }
  }
```

**3e.** In `build()`, add the "Ôn hôm nay" button above the `Spacer()` + `FilledButton`. Find the `Spacer()` in the Column children and insert before it:

```dart
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _dueCount == 0 ? null : _startDueSession,
                icon: const Icon(Icons.today_outlined),
                label: Text(
                  _dueCount == 0
                      ? 'Hôm nay đã ôn xong ✓'
                      : 'Ôn hôm nay ($_dueCount từ)',
                ),
              ),
            ),
            const SizedBox(height: 8),
```

- [ ] **Step 4: Run flutter analyze**

```
flutter analyze lib/
```

Expected: no errors.

- [ ] **Step 5: Run full suite**

```
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```
git add lib/features/practice/presentation/screens/session_result_screen.dart \
        lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat(plan5): hook stats recording + notification reschedule after session; add Ôn hôm nay button"
```

**Report status:** DONE
