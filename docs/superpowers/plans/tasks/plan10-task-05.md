# Plan 10 — Task 05: ComprehensionHomeScreen

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Plan 10 Task 04 (provider, DI, routes wired; stub `comprehension_home_screen.dart` exists)

## Global Constraints
(see `plan10-global-constraints.md`)

## What This Task Delivers
Replace the stub `ComprehensionHomeScreen` with a full implementation: Ngôn ngữ / Chủ đề (**AppContext** picker — Business/Travel/etc., not Topic tag) / Cấp độ filter pickers, a single error state (AI disabled — **no minimum-word gate**, unlike Dictation, since this feature doesn't touch the Vocab Bank), and a "Tạo bài luyện" button that generates a passage and navigates to the session.

## Files
- Modify: `lib/features/listening/presentation/screens/comprehension_home_screen.dart`
- Create: `test/features/listening/presentation/screens/comprehension_home_screen_test.dart`

## Interfaces
- Consumes:
  - `listeningComprehensionNotifierProvider` — to trigger generation + watch loading/error state
  - `userSettingsNotifierProvider` — for `aiEnabled`, `targetLanguage`, `targetCefrLevel`, `activeContext`
  - `FilterTile`, `showSingleSelectSheet` (existing, `lib/core/widgets/`)
- Produces: fully functional `ComprehensionHomeScreen`

## Steps

- [ ] **Step 1: Write a widget test**

Create `test/features/listening/presentation/screens/comprehension_home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_core/features/dictionary/domain/entities/user_settings_state.dart';
import 'package:lexi_core/features/dictionary/presentation/providers/user_settings_provider.dart';
import 'package:lexi_core/features/listening/presentation/screens/comprehension_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSettingsNotifier extends UserSettingsNotifier {
  _FakeSettingsNotifier(this._state);
  final UserSettingsState _state;
  @override
  UserSettingsState build() => _state;
}

Widget _buildHome({required UserSettingsState settings}) {
  SharedPreferences.setMockInitialValues({});
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const ComprehensionHomeScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      userSettingsNotifierProvider.overrideWith(() => _FakeSettingsNotifier(settings)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows AI disabled message when aiEnabled is false', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: false),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tính năng này yêu cầu AI'), findsOneWidget);
    expect(find.text('Tạo bài luyện'), findsNothing);
  });

  testWidgets('shows generate button when AI is enabled (no vocab gate)', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Tạo bài luyện'), findsOneWidget);
  });

  testWidgets('shows language, context and level pickers', (tester) async {
    await tester.pumpWidget(_buildHome(
      settings: UserSettingsState.defaults.copyWith(aiEnabled: true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Chủ đề'), findsOneWidget);
    expect(find.text('Cấp độ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
flutter test test/features/listening/presentation/screens/comprehension_home_screen_test.dart
```

Expected: FAIL — current stub doesn't implement these states.

- [ ] **Step 3: Replace comprehension_home_screen.dart**

Replace `lib/features/listening/presentation/screens/comprehension_home_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/filter_tile.dart';
import '../../../../core/widgets/selection_sheets.dart';
import '../../../dictionary/domain/entities/app_context.dart';
import '../../../dictionary/domain/entities/language.dart';
import '../../../dictionary/presentation/providers/user_settings_provider.dart';
import '../../../vocabulary/domain/entities/cefr_level.dart';
import '../providers/listening_comprehension_provider.dart';

class ComprehensionHomeScreen extends ConsumerStatefulWidget {
  const ComprehensionHomeScreen({super.key});

  @override
  ConsumerState<ComprehensionHomeScreen> createState() =>
      _ComprehensionHomeScreenState();
}

class _ComprehensionHomeScreenState
    extends ConsumerState<ComprehensionHomeScreen> {
  late Language _language;
  late AppContext _context;
  CEFRLevel? _level;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(userSettingsNotifierProvider);
    _language = settings.targetLanguage;
    _context = settings.activeContext;
    _level = settings.targetCefrLevel;
  }

  Future<void> _pickLanguage() async {
    final result = await showSingleSelectSheet<Language>(
      context: context,
      title: 'Ngôn ngữ',
      options: Language.values
          .map((l) => SelectOption(value: l, label: l.label))
          .toList(),
      selected: _language,
    );
    if (result != null) setState(() => _language = result.value);
  }

  Future<void> _pickContext() async {
    final result = await showSingleSelectSheet<AppContext>(
      context: context,
      title: 'Chủ đề',
      options: AppContext.values
          .map((c) => SelectOption(value: c, label: c.label, emoji: c.emoji))
          .toList(),
      selected: _context,
    );
    if (result != null) setState(() => _context = result.value);
  }

  Future<void> _pickLevel() async {
    final result = await showSingleSelectSheet<CEFRLevel?>(
      context: context,
      title: 'Cấp độ',
      options: [
        ...CEFRLevel.values.map((l) => SelectOption(value: l, label: l.label)),
        const SelectOption<CEFRLevel?>(value: null, label: 'Tất cả'),
      ],
      selected: _level,
    );
    if (result != null) setState(() => _level = result.value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsNotifierProvider);
    final sessionAsync = ref.watch(listeningComprehensionNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nghe hiểu'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'AI tạo một đoạn hội thoại hoặc bài nói ngắn. Nghe và trả lời '
                '3 câu hỏi trắc nghiệm về nội dung — giống phần nghe TOEIC.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),

            FilterTile(
              icon: Icons.language_outlined,
              label: 'Ngôn ngữ',
              value: _language.label,
              onTap: _pickLanguage,
            ),
            FilterTile(
              icon: Icons.sell_outlined,
              label: 'Chủ đề',
              value: '${_context.emoji} ${_context.label}',
              onTap: _pickContext,
            ),
            FilterTile(
              icon: Icons.school_outlined,
              label: 'Cấp độ',
              value: _level?.label ?? 'Tất cả',
              onTap: _pickLevel,
            ),
            const SizedBox(height: 16),

            if (!settings.aiEnabled)
              _ErrorCard(
                message:
                    'Tính năng này yêu cầu AI. Bật AI trong Cài đặt để dùng.',
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
    await ref.read(listeningComprehensionNotifierProvider.notifier).generate(
          level: _level ?? CEFRLevel.b1,
          context: _context,
          targetLanguage: _language,
        );

    if (context.mounted) {
      final session =
          ref.read(listeningComprehensionNotifierProvider).valueOrNull;
      if (session != null) {
        context.go('/listening/comprehension/session');
      }
    }
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
flutter test test/features/listening/presentation/screens/comprehension_home_screen_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Analyze**

```bash
flutter analyze lib/features/listening/presentation/screens/comprehension_home_screen.dart
```

Expected: no issues.

- [ ] **Step 7: Commit**

```bash
git add lib/features/listening/presentation/screens/comprehension_home_screen.dart \
        test/features/listening/presentation/screens/comprehension_home_screen_test.dart
git commit -m "feat(plan10): implement ComprehensionHomeScreen with AppContext filter"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: flutter test output
Concerns: (if any)
