# Plan 7 — Task 04: ReadingHomeScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 7 Task 03 (provider, DI, routes wired; stub `reading_home_screen.dart` exists)

## Global Constraints
(see `plan7-global-constraints.md`)

## What This Task Delivers
Replace the stub `ReadingHomeScreen` with a full implementation: brief feature description, language+context display, "Tạo bài luyện" button, loading state, and two error states (AI disabled; fewer than 5 vocab words).

## Files
- Modify: `lib/features/reading/presentation/screens/reading_home_screen.dart`

## Interfaces
- Consumes:
  - `readingPracticeNotifierProvider` — for trigger + state watching
  - `vocabBankProvider` — to count available words
  - `userSettingsNotifierProvider` — for `aiEnabled`, `targetLanguage`, `targetCefrLevel`, `activeContext`
- Produces: fully functional `ReadingHomeScreen`

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/reading/presentation/screens/reading_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/core/di/app_providers.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/reading/presentation/screens/reading_home_screen.dart';
import 'package:lexi_core/features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildHome({
  required UserSettingsState settings,
  required List<dynamic> vocabItems,
}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ReadingHomeScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
      vocabBankProvider.overrideWith((_) => vocabItems.cast()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
      vocabItems: List.filled(10, null),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows low vocab message when fewer than 5 words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.filled(3, null),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('5 từ'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI enabled and >= 5 vocab words', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
      vocabItems: List.filled(5, null),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/reading/presentation/screens/reading_home_screen_test.dart
```

Expected: FAIL — current stub doesn't implement these states.

- [ ] **Step 3: Replace reading_home_screen.dart**

Replace `lib/features/reading/presentation/screens/reading_home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/dictionary/presentation/providers/user_settings_provider.dart';
import '../../../../features/vocabulary/domain/entities/cefr_level.dart';
import '../../../../features/vocabulary/presentation/providers/vocab_bank_provider.dart';
import '../providers/reading_practice_provider.dart';

class ReadingHomeScreen extends ConsumerWidget {
  const ReadingHomeScreen({super.key});

  static const _minVocabWords = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final vocabItems = ref.watch(vocabBankProvider);
    final sessionAsync = ref.watch(readingPracticeNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện đọc & gõ'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI tạo một đoạn văn song ngữ từ Vocab Bank của bạn. '
              'Đọc đoạn văn bằng ngôn ngữ mục tiêu, sau đó gõ lại từng câu.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Ngôn ngữ', value: settings.targetLanguage.label),
            _InfoRow(
              label: 'Cấp độ',
              value: settings.targetCefrLevel?.label ?? 'Tất cả',
            ),
            _InfoRow(
              label: 'Ngữ cảnh',
              value: settings.activeContext.label,
            ),
            const SizedBox(height: 32),
            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
              )
            else if (vocabItems.length < _minVocabWords)
              _ErrorCard(
                message:
                    'Hãy lưu ít nhất 5 từ vào Vocab Bank để dùng tính năng này. '
                    'Hiện có ${vocabItems.length} từ.',
              )
            else
              sessionAsync.when(
                data: (_) => FilledButton.icon(
                  onPressed: () => _generate(context, ref),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Tạo bài luyện'),
                ),
                loading: () => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang tạo bài...'),
                  ],
                ),
                error: (e, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lỗi tạo bài: $e',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _generate(context, ref),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(userSettingsNotifierProvider);
    final vocabItems = ref.read(vocabBankProvider);

    final sorted = [...vocabItems]..sort((a, b) {
        final aDue = a.nextReviewAt == null ||
            a.nextReviewAt!.isBefore(DateTime.now());
        final bDue = b.nextReviewAt == null ||
            b.nextReviewAt!.isBefore(DateTime.now());
        if (aDue && !bDue) return -1;
        if (!aDue && bDue) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final words = sorted.take(10).toList();

    await ref.read(readingPracticeNotifierProvider.notifier).generate(
          words: words,
          level: settings.targetCefrLevel ?? CEFRLevel.b1,
          context: settings.activeContext,
          targetLanguage: settings.targetLanguage,
        );

    if (context.mounted) {
      final session = ref.read(readingPracticeNotifierProvider).valueOrNull;
      if (session != null && !session.isComplete) {
        context.go('/reading/session');
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/reading/presentation/screens/reading_home_screen_test.dart
```

Expected: all 3 tests pass.

Note: the test overrides `vocabBankProvider` with a list of `null` items to fake the count. If `vocabBankProvider` returns `List<VocabRecord>`, update the override to return `List<VocabRecord>` instead. Adjust the test's `vocabItems` override to provide empty `VocabRecord` instances using the `VocabRecord(...)` constructor from Task 02 tests.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/reading/presentation/screens/reading_home_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/reading/presentation/screens/reading_home_screen.dart \
        test/features/reading/presentation/screens/reading_home_screen_test.dart
git commit -m "feat(plan7): implement ReadingHomeScreen with error states + generate flow"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
