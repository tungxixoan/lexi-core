# Task 12: Context Selector Widget

**Project:** LexiCore — Flutter language learning app
**Working directory:** `d:/Flutter/lexi-core`
**Depends on:** Tasks 2, 10, 11

## Interfaces From Prior Tasks
- `userSettingsNotifierProvider` → `UserSettingsState`
- `UserSettingsNotifier.setActiveContext(AppContext)` — call via `ref.read(userSettingsNotifierProvider.notifier).setActiveContext(ctx)`
- `AppContext.values` — all 8 contexts
- `AppContext.emoji` and `AppContext.label` getters

## What This Task Delivers
A horizontally scrollable row of `FilterChip` widgets — one per `AppContext`. Active context chip is highlighted. Tapping changes the active context.

## Files
- Create: `lib/features/dictionary/presentation/widgets/context_selector_widget.dart`
- Create: `test/features/dictionary/presentation/widgets/context_selector_widget_test.dart`

## Steps

- [ ] **Step 1: Implement context_selector_widget.dart**

```dart
// lib/features/dictionary/presentation/widgets/context_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/app_context.dart';
import '../providers/user_settings_provider.dart';

class ContextSelectorWidget extends ConsumerWidget {
  const ContextSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      userSettingsNotifierProvider.select((s) => s.activeContext),
    );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: AppContext.values.map((ctx) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${ctx.emoji} ${ctx.label}'),
              selected: ctx == active,
              onSelected: (_) => ref
                  .read(userSettingsNotifierProvider.notifier)
                  .setActiveContext(ctx),
            ),
          );
        }).toList(),
      ),
    );
  }
}
```

- [ ] **Step 2: Write widget tests**

```dart
// test/features/dictionary/presentation/widgets/context_selector_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_core/features/dictionary/domain/entities/app_context.dart';
import 'package:lexi_core/features/dictionary/presentation/widgets/context_selector_widget.dart';

void main() {
  testWidgets('renders a chip for every AppContext', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ContextSelectorWidget()),
        ),
      ),
    );

    for (final ctx in AppContext.values) {
      expect(find.text('${ctx.emoji} ${ctx.label}'), findsOneWidget);
    }
  });

  testWidgets('tapping a chip marks it selected', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ContextSelectorWidget()),
        ),
      ),
    );

    await tester.tap(
      find.text('${AppContext.business.emoji} ${AppContext.business.label}'),
    );
    await tester.pump();

    final chip = tester.widget<FilterChip>(
      find.widgetWithText(
        FilterChip,
        '${AppContext.business.emoji} ${AppContext.business.label}',
      ),
    );
    expect(chip.selected, isTrue);
  });
}
```

- [ ] **Step 3: Run widget tests**

```bash
flutter test test/features/dictionary/presentation/widgets/context_selector_widget_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/dictionary/presentation/widgets/context_selector_widget.dart \
        test/features/dictionary/presentation/widgets/context_selector_widget_test.dart
git commit -m "feat: add ContextSelectorWidget — scrollable context chip row"
```

## Report Contract
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
Commits: (list SHAs)
Tests: X/X passed — `flutter test test/features/dictionary/presentation/widgets/context_selector_widget_test.dart`
Concerns: (if any)
