# Plan 4 — Task 04: PracticeHomeScreen CEFR filter UI

**Plan file:** `docs/superpowers/plans/2026-07-02-plan4-firebase-settings-practice-filter.md`
**Global constraints:** `docs/superpowers/plans/tasks/plan4-global-constraints.md`
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Task 02 (userSettingsNotifierProvider has targetCefrLevel), Task 03 (getVocabListUseCaseProvider.execute accepts maxCefrLevel)

## What this task builds

Adds a CEFR level segmented button filter to `PracticeHomeScreen`. The selected level is initialized from `UserSettingsState.targetCefrLevel` (the user's default from Settings). Filtering is applied when calling `getVocabListUseCaseProvider.execute()`. If filtered list is empty, shows a SnackBar.

No new tests — UI-only change.

## Files

- Modify: `lib/features/practice/presentation/screens/practice_home_screen.dart`

## Interfaces consumed

```dart
// userSettingsNotifierProvider — from user_settings_provider.dart
// UserSettingsState.targetCefrLevel: CEFRLevel?  (from Task 02)

// getVocabListUseCaseProvider — from app_providers.dart
// GetVocabListUseCase.execute({String? topicId, CEFRLevel? maxCefrLevel, ...})  (from Task 03)

// CEFRLevel — lib/features/vocabulary/domain/entities/cefr_level.dart
// CEFRLevel.values  — [a1, a2, b1, b2, c1, c2]
// CEFRLevel.label   — 'A1', 'A2', etc.

// topicsNotifierProvider — from vocab bank (existing)
// SessionConfig — lib/features/practice/domain/entities/exercise_result.dart (existing)
```

---

- [ ] **Step 1: Read the current PracticeHomeScreen**

```
lib/features/practice/presentation/screens/practice_home_screen.dart
```

Note the existing structure: topic filter chips, word limit SegmentedButton, `_start()` method. This task adds a CEFR filter row between the topic chips and the word-limit button.

- [ ] **Step 2: Update PracticeHomeScreen**

Replace the full content of `lib/features/practice/presentation/screens/practice_home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../../../vocabulary/presentation/providers/topics_provider.dart';
import '../../domain/entities/exercise_result.dart';

class PracticeHomeScreen extends ConsumerStatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  ConsumerState<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends ConsumerState<PracticeHomeScreen> {
  String? _selectedTopicId;
  int? _wordLimit = 10;
  CEFRLevel? _maxCefrLevel; // null = show all levels

  static const _limits = [5, 10, 20, null];
  static const _limitLabels = ['5', '10', '20', 'Tất cả'];

  @override
  void initState() {
    super.initState();
    // Initialize CEFR filter from the user's default setting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = ref.read(userSettingsNotifierProvider);
      setState(() => _maxCefrLevel = settings.targetCefrLevel);
    });
  }

  Future<void> _start() async {
    final words = await ref.read(getVocabListUseCaseProvider).execute(
          topicId: _selectedTopicId,
          maxCefrLevel: _maxCefrLevel,
        );
    if (words.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có từ nào ở cấp độ này.')),
        );
      }
      return;
    }
    final shuffled = List<dynamic>.from(words)..shuffle();
    final limited =
        _wordLimit == null ? shuffled : shuffled.take(_wordLimit!).toList();
    if (mounted) {
      context.go('/practice/session', extra: SessionConfig(words: List.from(limited)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsNotifierProvider);
    final theme = Theme.of(context);

    // CEFR segments: A1 A2 B1 B2 C1 C2 | Tất cả (null)
    final cefrSegments = <ButtonSegment<CEFRLevel?>>[
      ...CEFRLevel.values.map(
        (l) => ButtonSegment<CEFRLevel?>(value: l, label: Text(l.label)),
      ),
      const ButtonSegment<CEFRLevel?>(value: null, label: Text('Tất cả')),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Luyện tập')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Topic filter ────────────────────────────────
            Text('Chủ đề', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            topicsAsync.when(
              data: (topics) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Tất cả'),
                    selected: _selectedTopicId == null,
                    onSelected: (_) =>
                        setState(() => _selectedTopicId = null),
                  ),
                  ...topics.map(
                    (t) => FilterChip(
                      label: Text('${t.emoji} ${t.name}'),
                      selected: _selectedTopicId == t.id,
                      onSelected: (_) =>
                          setState(() => _selectedTopicId = t.id),
                    ),
                  ),
                ],
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),

            const SizedBox(height: 24),

            // ── CEFR level filter ───────────────────────────
            Text('Cấp độ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<CEFRLevel?>(
                segments: cefrSegments,
                selected: {_maxCefrLevel},
                onSelectionChanged: (s) =>
                    setState(() => _maxCefrLevel = s.first),
              ),
            ),

            const SizedBox(height: 24),

            // ── Word limit ──────────────────────────────────
            Text('Số từ mỗi session', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int?>(
              segments: List.generate(
                _limits.length,
                (i) => ButtonSegment<int?>(
                  value: _limits[i],
                  label: Text(_limitLabels[i]),
                ),
              ),
              selected: {_wordLimit},
              onSelectionChanged: (s) => setState(() => _wordLimit = s.first),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu luyện tập'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: The `_start()` method uses `List<dynamic>.from(words)` to avoid typing issues with `take()`. Check the existing imports (`app_providers.dart`, `topics_provider.dart`) match the actual import paths in the project — adjust if needed.

- [ ] **Step 3: Analyze**

```
flutter analyze lib/features/practice/presentation/screens/practice_home_screen.dart
```

Expected: no issues.

- [ ] **Step 4: Run full test suite**

```
flutter test
```

Expected: all passing (no tests for this file — it's UI-only).

- [ ] **Step 5: Commit**

```
git add lib/features/practice/presentation/screens/practice_home_screen.dart
git commit -m "feat(plan4): add CEFR level filter to PracticeHomeScreen"
```

## Self-review checklist

- [ ] `_maxCefrLevel` is initialized from `userSettingsNotifierProvider` in `addPostFrameCallback`
- [ ] CEFR segments include all 6 `CEFRLevel.values` + a "Tất cả" `null` segment
- [ ] `getVocabListUseCaseProvider.execute(maxCefrLevel: _maxCefrLevel)` is called in `_start()`
- [ ] Empty list shows SnackBar `'Không có từ nào ở cấp độ này.'` and returns early
- [ ] Shuffle uses `List.from(words)` — does not mutate the returned list
- [ ] `flutter analyze` clean
